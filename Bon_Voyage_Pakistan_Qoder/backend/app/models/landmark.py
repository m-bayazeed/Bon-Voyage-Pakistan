from typing import List, Optional
from pydantic import BaseModel, Field


class LandmarkResponse(BaseModel):
    """Pydantic model representing structured AI landmark identification and historical details."""

    success: bool = Field(default=True, description="Indicates whether the API request succeeded")
    identified: bool = Field(default=False, description="Indicates whether a recognizable Pakistani landmark was identified")
    landmark_name: Optional[str] = Field(default=None, description="Recognized Pakistani landmark name")
    city_or_region: Optional[str] = Field(default=None, description="City or region in Pakistan where the landmark is located")
    historical_era: Optional[str] = Field(default=None, description="Historical period or dynasty (e.g. Mughal era, Indus Valley Civilization)")
    history_overview: Optional[str] = Field(default=None, description="Concise historical background of the landmark")
    historical_events: List[str] = Field(default_factory=list, description="Important historical events associated with the site")
    interesting_facts: List[str] = Field(default_factory=list, description="Curated fascinating facts about the landmark")
    architectural_significance: Optional[str] = Field(default=None, description="Architectural design and cultural significance")
    travel_tip: Optional[str] = Field(default=None, description="Practical travel/visitor tip")
    confidence: Optional[float] = Field(default=None, description="Confidence score from 0.0 to 1.0")
    message: Optional[str] = Field(default=None, description="Informative status message")


class StoryAudioRequest(BaseModel):
    """Request model for AI landmark audio story synthesis."""

    text: str = Field(..., min_length=1, description="Story text to synthesize to speech")
    language: Optional[str] = Field(default="en", description="Target audio language code ('en' or 'ur')")


class StoryAudioResponse(BaseModel):
    """Response model containing synthesized base64 MP3 audio."""

    success: bool = Field(default=True, description="Indicates whether TTS audio generation succeeded")
    audio_base64: str = Field(default="", description="Base64-encoded MP3 audio bytes")
    format: str = Field(default="mp3", description="Audio format")
    error: Optional[str] = Field(default=None, description="Error message if audio generation failed")
    message: Optional[str] = Field(default=None, description="Status or info message")
