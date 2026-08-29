import asyncio
import logging
import os
import tempfile
from pathlib import Path
from fastapi import HTTPException, UploadFile, status
from app.core.config import settings
from app.models.translator import (
    SynthesizeResponse,
    TextTranslateResponse,
    VoiceTranslateResponse,
)
from app.services.gemini_service import gemini_service
from app.services.groq_service import groq_service
from app.services.tts_service import tts_service

logger = logging.getLogger(__name__)


class TranslationPipelineService:
    """Orchestrator for Translation, Transcription, and Speech Synthesis."""

    async def translate_text(
        self,
        text: str,
        source_language: str = "auto",
        target_language: str = "ur",
    ) -> TextTranslateResponse:
        """Pipeline 1: Text -> Gemini Translation -> Edge-TTS Audio."""
        clean_text = text.strip()
        if not clean_text:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Text cannot be empty or whitespace only.",
            )

        # 1. Translate via Gemini
        try:
            gemini_result = await gemini_service.translate_text(
                text=clean_text,
                source_language=source_language,
                target_language=target_language,
            )
        except Exception as e:
            logger.error(f"Gemini translation failed in pipeline: {e}")
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Translation AI service error: {str(e)}",
            )

        # 2. Synthesize audio via Edge-TTS (Safe fallback so text translation never fails)
        audio_base64 = ""
        try:
            audio_base64 = await tts_service.synthesize_to_base64(
                text=gemini_result.translated_text,
                language=target_language,
            )
        except Exception as e:
            logger.warning(f"Audio synthesis skipped in text pipeline: {e}")
            audio_base64 = ""

        target_lang_display = settings.LANGUAGE_NAMES.get(target_language, "Urdu" if target_language == "ur" else "English")

        return TextTranslateResponse(
            success=True,
            detected_source_language=gemini_result.detected_source_language,
            original_text=clean_text,
            source_romanized_pronunciation=gemini_result.source_romanized_pronunciation or "",
            target_language=target_lang_display,
            translated_text=gemini_result.translated_text,
            romanized_pronunciation=gemini_result.romanized_pronunciation,
            audio_base64=audio_base64 or "",
        )

    async def translate_voice(
        self,
        audio_file: UploadFile,
        source_language: str = "auto",
        target_language: str = "ur",
    ) -> VoiceTranslateResponse:
        """Pipeline 2: Voice Audio -> Groq Whisper -> Gemini -> Edge-TTS Audio."""
        # 1. Validate file extension
        filename = audio_file.filename or "audio.wav"
        ext = Path(filename).suffix.lower()
        if ext not in settings.SUPPORTED_AUDIO_EXTENSIONS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"Unsupported audio format '{ext}'. "
                    f"Supported formats: {', '.join(sorted(list(settings.SUPPORTED_AUDIO_EXTENSIONS)))}"
                ),
            )

        # 2. Read and validate size
        if hasattr(audio_file, "read"):
            read_fn = audio_file.read
            if asyncio.iscoroutinefunction(read_fn):
                contents = await read_fn()
            else:
                contents = read_fn()
        elif isinstance(audio_file, (bytes, bytearray)):
            contents = bytes(audio_file)
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid audio payload provided.",
            )

        if len(contents) == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Uploaded audio file is empty (0 bytes).",
            )
        if len(contents) > settings.MAX_AUDIO_SIZE_BYTES:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"Audio file exceeds maximum allowed size of {settings.MAX_AUDIO_SIZE_BYTES // (1024 * 1024)} MB.",
            )

        temp_path = None
        try:
            # 3. Save uploaded bytes to temporary file on disk with proper extension
            with tempfile.NamedTemporaryFile(suffix=ext, delete=False) as tmp_file:
                tmp_file.write(contents)
                temp_path = Path(tmp_file.name)

            # 4. Transcribe via Groq Whisper with real file bytes
            try:
                groq_client = groq_service._get_client()
                with open(str(temp_path), "rb") as f:
                    transcription = await groq_client.audio.transcriptions.create(
                        file=(os.path.basename(str(temp_path)), f.read()),
                        model=settings.GROQ_WHISPER_MODEL,
                        response_format="json",
                    )
                raw_transcript = (transcription.text or "").strip()
            except Exception as e:
                logger.error(f"Groq transcription failed: {e}")
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail=f"Speech recognition service error: {str(e)}",
                )

            # Validate speech detection
            if not raw_transcript:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="No clear speech detected in audio",
                )

            # 5. Translate transcript via Gemini
            try:
                gemini_result = await gemini_service.translate_text(
                    text=raw_transcript,
                    source_language=source_language,
                    target_language=target_language,
                )
            except Exception as e:
                logger.error(f"Gemini translation failed for voice: {e}")
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail=f"Translation AI service error: {str(e)}",
                )

            # 6. Synthesize translation to speech (Safe fallback)
            audio_base64 = ""
            try:
                audio_base64 = await tts_service.synthesize_to_base64(
                    text=gemini_result.translated_text,
                    language=target_language,
                )
            except Exception as e:
                logger.warning(f"Audio synthesis skipped in voice pipeline: {e}")
                audio_base64 = ""

            target_lang_display = settings.LANGUAGE_NAMES.get(target_language, "Urdu" if target_language == "ur" else "English")

            return VoiceTranslateResponse(
                success=True,
                detected_source_language=gemini_result.detected_source_language,
                original_text=raw_transcript,
                transcript=raw_transcript,
                source_romanized_pronunciation=gemini_result.source_romanized_pronunciation or "",
                target_language=target_lang_display,
                translated_text=gemini_result.translated_text,
                romanized_pronunciation=gemini_result.romanized_pronunciation,
                audio_base64=audio_base64 or "",
            )

        finally:
            # Safe temporary file cleanup guaranteed
            if temp_path and temp_path.exists():
                try:
                    temp_path.unlink()
                except Exception as cleanup_err:
                    logger.warning(f"Failed to remove temporary audio file {temp_path}: {cleanup_err}")

    async def synthesize(self, text: str, language: str = "ur") -> SynthesizeResponse:
        """Pipeline 3: Text -> Edge-TTS Audio Base64."""
        clean_text = text.strip()
        if not clean_text:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Text cannot be empty or whitespace only.",
            )

        try:
            audio_base64 = await tts_service.synthesize_to_base64(
                text=clean_text,
                language=language,
            )
            return SynthesizeResponse(
                success=True,
                audio_base64=audio_base64 or "",
            )
        except Exception as e:
            logger.warning(f"Synthesis failed, returning empty audio: {e}")
            return SynthesizeResponse(
                success=True,
                audio_base64="",
            )


translation_pipeline = TranslationPipelineService()

