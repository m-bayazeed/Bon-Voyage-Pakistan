from typing import Optional
from pydantic import BaseModel, Field


class WeatherResponse(BaseModel):
    """Clean model for live weather and road conditions."""
    success: bool = True
    city: str = Field(..., description="Destination city name in Pakistan")
    temperature: float = Field(..., description="Current temperature in Celsius")
    feels_like: float = Field(..., description="Feels-like temperature in Celsius")
    condition: str = Field(..., description="Main weather condition (Clear, Rain, Clouds, etc.)")
    description: str = Field(..., description="Capitalized condition description")
    icon_url: str = Field(..., description="OpenWeatherMap condition icon URL")
    humidity: int = Field(..., description="Humidity percentage")
    wind_speed_kmh: float = Field(..., description="Wind speed converted to km/h")
    pressure: Optional[int] = Field(default=None, description="Atmospheric pressure in hPa")
    travel_advisory: str = Field(..., description="Dynamic travel advisory tailored for Pakistani routes")
    is_favorable: bool = Field(default=True, description="Whether travel conditions are favorable")
    advisory_level: str = Field(default="favorable", description="Level: favorable, moderate, or alert")
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    error: Optional[str] = None
