from typing import Optional
from pydantic import BaseModel, Field, field_validator
from app.core.config import settings


class TextTranslateRequest(BaseModel):
    """Request payload for text translation."""
    text: str = Field(
        ...,
        description="The source text to translate (max 5,000 characters).",
        min_length=1,
        max_length=settings.MAX_TEXT_LENGTH,
    )
    source_language: str = Field(
        default="auto",
        description="Source language code ('auto', 'en', 'ur', 'ar', 'de', 'fr', 'zh', 'ru', 'es').",
    )
    target_language: str = Field(
        default="ur",
        description="Target language code (strictly 'en' or 'ur').",
    )

    @field_validator("text")
    @classmethod
    def validate_text(cls, v: str) -> str:
        trimmed = v.strip()
        if not trimmed:
            raise ValueError("Text cannot be empty or whitespace only.")
        if len(trimmed) > settings.MAX_TEXT_LENGTH:
            raise ValueError(f"Text length exceeds maximum of {settings.MAX_TEXT_LENGTH} characters.")
        return trimmed

    @field_validator("source_language")
    @classmethod
    def validate_source_language(cls, v: str) -> str:
        code = v.lower().strip()
        if code not in settings.SUPPORTED_SOURCE_LANGUAGES:
            raise ValueError(
                f"Unsupported source language '{v}'. Supported: {sorted(list(settings.SUPPORTED_SOURCE_LANGUAGES))}"
            )
        return code

    @field_validator("target_language")
    @classmethod
    def validate_target_language(cls, v: str) -> str:
        code = v.lower().strip()
        if code not in settings.SUPPORTED_TARGET_LANGUAGES:
            raise ValueError(
                f"Unsupported target language '{v}'. Target must be strictly 'en' or 'ur'."
            )
        return code


class SynthesizeRequest(BaseModel):
    """Request payload for direct audio synthesis."""
    text: str = Field(
        ...,
        description="The text to synthesize to speech.",
        min_length=1,
        max_length=settings.MAX_TEXT_LENGTH,
    )
    language: str = Field(
        default="ur",
        description="Language code (strictly 'en' or 'ur').",
    )

    @field_validator("text")
    @classmethod
    def validate_text(cls, v: str) -> str:
        trimmed = v.strip()
        if not trimmed:
            raise ValueError("Text cannot be empty or whitespace only.")
        if len(trimmed) > settings.MAX_TEXT_LENGTH:
            raise ValueError(f"Text length exceeds maximum of {settings.MAX_TEXT_LENGTH} characters.")
        return trimmed

    @field_validator("language")
    @classmethod
    def validate_language(cls, v: str) -> str:
        code = v.lower().strip()
        if code not in settings.SUPPORTED_TARGET_LANGUAGES:
            raise ValueError(
                f"Unsupported language '{v}'. Only 'en' and 'ur' are supported for speech synthesis."
            )
        return code


class TranslationEngineOutput(BaseModel):
    """Structured response format generated strictly by Gemini / Groq."""
    detected_source_language: str = Field(
        description="Auto-detected source language name (e.g., English, German, Arabic, Urdu)."
    )
    source_romanized_pronunciation: Optional[str] = Field(
        default="",
        description="Romanized phonetic pronunciation of the original input text (e.g., Roman Urdu 'Aap kaise hain?' if input is Urdu script).",
    )
    translated_text: str = Field(
        description="High-quality, grammatically correct translation strictly in the target language script (Urdu Nastaliq or English)."
    )
    romanized_pronunciation: str = Field(
        description="Pronunciation guide for translated text. For Urdu target, provide Roman Urdu (e.g., 'Aap kaise hain?'). For English target, provide phonetic/plain Roman text."
    )


class TextTranslateResponse(BaseModel):
    """Response payload for text translation."""
    success: bool = True
    detected_source_language: str
    original_text: str
    source_romanized_pronunciation: Optional[str] = ""
    target_language: str
    translated_text: str
    romanized_pronunciation: str
    audio_base64: str


class VoiceTranslateResponse(BaseModel):
    """Response payload for voice translation."""
    success: bool = True
    detected_source_language: str
    original_text: str
    transcript: str
    source_romanized_pronunciation: Optional[str] = ""
    target_language: str
    translated_text: str
    romanized_pronunciation: str
    audio_base64: str


class SynthesizeResponse(BaseModel):
    """Response payload for speech synthesis."""
    success: bool = True
    audio_base64: str


class ErrorResponse(BaseModel):
    """Standard error response format."""
    success: bool = False
    error: str

