import logging
from pathlib import Path
from typing import Optional
from groq import AsyncGroq
from app.core.config import settings

logger = logging.getLogger(__name__)


class GroqService:
    """Service for Audio Transcription using Groq Whisper."""

    def __init__(self):
        self._client: Optional[AsyncGroq] = None

    def _get_client(self) -> AsyncGroq:
        api_key = settings.GROQ_API_KEY
        if not api_key:
            raise RuntimeError(
                "Groq API Key is not configured. Please set GROQ_API_KEY_TripPlan or GROQ_API_KEY in backend/.env"
            )
        if self._client is None:
            self._client = AsyncGroq(api_key=api_key)
        return self._client

    async def transcribe_audio_file(self, file_path: str, filename: Optional[str] = None) -> str:
        """Transcribe an audio file using Groq whisper-large-v3."""
        client = self._get_client()
        path = Path(file_path)
        if not path.exists():
            raise FileNotFoundError(f"Audio file not found: {file_path}")

        file_display_name = filename or path.name
        try:
            with open(path, "rb") as f:
                file_bytes = f.read()

            transcription = await client.audio.transcriptions.create(
                file=(file_display_name, file_bytes),
                model=settings.GROQ_WHISPER_MODEL,
                response_format="json",
            )
            text = (transcription.text or "").strip()
            logger.info("Transcribed audio successfully: %d characters", len(text))
            return text
        except Exception as e:
            logger.error(f"Error during Groq audio transcription: {e}")
            raise RuntimeError(f"Groq Whisper transcription failed: {str(e)}") from e


groq_service = GroqService()
