import asyncio
import base64
import logging
import os
import tempfile
from pathlib import Path
import edge_tts
from app.core.config import settings

logger = logging.getLogger(__name__)


class TTSService:
    """Service for Text-to-Speech synthesis using Microsoft Edge TTS with safe non-blocking fallback."""

    def get_voice(self, language: str) -> str:
        """Select appropriate neural voice based on language code."""
        lang_code = language.lower().strip()
        return settings.TTS_VOICES.get(lang_code, settings.TTS_VOICES["en"])

    async def synthesize_to_bytes(self, text: str, language: str = "ur") -> bytes:
        """Synthesize text into MP3 audio bytes using edge-tts with async execution and safe fallback."""
        clean_text = text.strip()
        if not clean_text:
            return b""

        voice = self.get_voice(language)
        temp_path = None
        try:
            # Create a secure temporary file
            with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tmp_file:
                temp_path = Path(tmp_file.name)

            communicate = edge_tts.Communicate(clean_text, voice)
            # Execute with timeout to prevent hanging the connection
            await asyncio.wait_for(communicate.save(str(temp_path)), timeout=10.0)

            if temp_path.exists() and temp_path.stat().st_size > 0:
                with open(temp_path, "rb") as f:
                    audio_bytes = f.read()
                logger.info("Synthesized %d bytes of audio with voice %s", len(audio_bytes), voice)
                return audio_bytes
            return b""

        except asyncio.TimeoutError:
            logger.warning(f"Edge-TTS synthesis timed out for text: '{clean_text[:30]}...'")
            return b""
        except Exception as e:
            logger.warning(f"Edge-TTS synthesis error (fallback to empty audio): {e}")
            return b""
        finally:
            # Ensure all temporary audio files are safely cleaned up
            if temp_path and temp_path.exists():
                try:
                    temp_path.unlink()
                except Exception as cleanup_err:
                    logger.warning(f"Failed to remove temporary TTS file {temp_path}: {cleanup_err}")

    async def synthesize_to_base64(self, text: str, language: str = "ur") -> str:
        """Synthesize text and return base64-encoded MP3 string, or empty string on failure/timeout."""
        try:
            audio_bytes = await self.synthesize_to_bytes(text, language)
            if not audio_bytes:
                return ""
            return base64.b64encode(audio_bytes).decode("utf-8")
        except Exception as e:
            logger.warning(f"Failed to encode synthesized audio to base64: {e}")
            return ""


tts_service = TTSService()

