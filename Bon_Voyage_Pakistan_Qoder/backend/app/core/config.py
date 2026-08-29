import os
from pathlib import Path
from typing import List, Set
from dotenv import load_dotenv

# Explicitly load .env from the backend directory
BACKEND_DIR = Path(__file__).resolve().parent.parent.parent
ENV_PATH = BACKEND_DIR / ".env"
load_dotenv(dotenv_path=ENV_PATH)


class Settings:
    """Application Settings and Configuration."""

    # Project metadata
    PROJECT_NAME: str = "Bon Voyage Pakistan - Translator API"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"

    # API Keys with fallback priority
    @property
    def GROQ_API_KEY(self) -> str:
        # Priority: GROQ_API_KEY_TripPlan -> GROQ_API_KEY
        return (
            os.getenv("GROQ_API_KEY_TripPlan")
            or os.getenv("GROQ_API_KEY")
            or ""
        ).strip()

    @property
    def GEMINI_API_KEY(self) -> str:
        # Priority: GEMINI_API_KEY -> GoogleAPI -> GOOGLE_API_KEY
        return (
            os.getenv("GEMINI_API_KEY")
            or os.getenv("GoogleAPI")
            or os.getenv("GOOGLE_API_KEY")
            or ""
        ).strip()

    # AI Models
    GEMINI_MODEL: str = os.getenv("GEMINI_MODEL", "gemini-3.6-flash").strip()
    GROQ_WHISPER_MODEL: str = os.getenv("GROQ_WHISPER_MODEL", "whisper-large-v3").strip()

    # CORS Settings
    @property
    def CORS_ORIGINS(self) -> List[str]:
        raw_origins = os.getenv("CORS_ORIGINS", "*").strip()
        if not raw_origins or raw_origins == "*":
            return ["*"]
        return [origin.strip() for origin in raw_origins.split(",") if origin.strip()]

    # Supported Languages & Limits
    SUPPORTED_SOURCE_LANGUAGES: Set[str] = {
        "auto",
        "en",
        "ur",
        "ar",
        "de",
        "fr",
        "zh",
        "ru",
        "es",
    }
    SUPPORTED_TARGET_LANGUAGES: Set[str] = {"en", "ur"}

    LANGUAGE_NAMES = {
        "en": "English",
        "ur": "Urdu",
        "ar": "Arabic",
        "de": "German",
        "fr": "French",
        "zh": "Chinese",
        "ru": "Russian",
        "es": "Spanish",
    }

    # Text & Audio Constraints
    MAX_TEXT_LENGTH: int = 5000
    MAX_AUDIO_SIZE_BYTES: int = 10 * 1024 * 1024  # 10 MB
    SUPPORTED_AUDIO_EXTENSIONS: Set[str] = {
        ".mp3",
        ".wav",
        ".m4a",
        ".ogg",
        ".webm",
    }

    # Edge TTS Voice Mappings
    TTS_VOICES = {
        "ur": "ur-PK-UzmaNeural",
        "en": "en-US-ChristopherNeural",
    }


settings = Settings()
