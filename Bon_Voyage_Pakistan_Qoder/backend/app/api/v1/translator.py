import logging
from typing import Optional
from fastapi import APIRouter, File, Form, HTTPException, UploadFile, status
from app.core.config import settings
from app.models.translator import (
    ErrorResponse,
    SynthesizeRequest,
    SynthesizeResponse,
    TextTranslateRequest,
    TextTranslateResponse,
    VoiceTranslateResponse,
)
from app.services.translation_service import translation_pipeline

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/translate", tags=["Translator"])


@router.post(
    "/text",
    response_model=TextTranslateResponse,
    responses={
        400: {"model": ErrorResponse, "description": "Invalid input"},
        422: {"model": ErrorResponse, "description": "Validation error"},
        502: {"model": ErrorResponse, "description": "External AI failure"},
    },
    summary="Translate Text",
    description="Translate text between supported languages and synthesize audio in target language.",
)
async def translate_text_endpoint(
    request: TextTranslateRequest,
) -> TextTranslateResponse:
    """Endpoint for text translation with travel context and neural TTS."""
    return await translation_pipeline.translate_text(
        text=request.text,
        source_language=request.source_language,
        target_language=request.target_language,
    )


@router.post(
    "/voice",
    response_model=VoiceTranslateResponse,
    responses={
        400: {"model": ErrorResponse, "description": "Invalid file format or empty file"},
        413: {"model": ErrorResponse, "description": "File too large (exceeds 10 MB)"},
        422: {"model": ErrorResponse, "description": "No speech recognized in audio"},
        502: {"model": ErrorResponse, "description": "Speech recognition or AI failure"},
    },
    summary="Translate Voice Audio",
    description="Upload voice recording (.mp3, .wav, .m4a, .ogg, .webm, max 10MB) to transcribe, translate, and synthesize.",
)
async def translate_voice_endpoint(
    audio_file: UploadFile = File(..., description="Audio recording file (max 10MB)"),
    source_language: str = Form(
        "auto",
        description="Source language code ('auto', 'en', 'ur', 'ar', 'de', 'fr', 'zh', 'ru', 'es')",
    ),
    target_language: str = Form(
        "ur",
        description="Target language code ('en' or 'ur')",
    ),
) -> VoiceTranslateResponse:
    """Endpoint for voice translation (Groq Whisper -> Gemini -> Edge-TTS)."""
    src_lang = source_language.lower().strip()
    tgt_lang = target_language.lower().strip()

    if src_lang not in settings.SUPPORTED_SOURCE_LANGUAGES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported source language '{source_language}'. Supported: {sorted(list(settings.SUPPORTED_SOURCE_LANGUAGES))}",
        )

    if tgt_lang not in settings.SUPPORTED_TARGET_LANGUAGES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported target language '{target_language}'. Target must be strictly 'en' or 'ur'.",
        )

    return await translation_pipeline.translate_voice(
        audio_file=audio_file,
        source_language=src_lang,
        target_language=tgt_lang,
    )


@router.post(
    "/synthesize",
    response_model=SynthesizeResponse,
    responses={
        400: {"model": ErrorResponse, "description": "Invalid text or language"},
        502: {"model": ErrorResponse, "description": "TTS synthesis failure"},
    },
    summary="Synthesize Text to Speech",
    description="Generate neural voice audio (Base64 MP3) for English or Urdu text.",
)
async def synthesize_endpoint(
    request: SynthesizeRequest,
) -> SynthesizeResponse:
    """Endpoint for direct neural speech synthesis via Edge-TTS."""
    return await translation_pipeline.synthesize(
        text=request.text,
        language=request.language,
    )
