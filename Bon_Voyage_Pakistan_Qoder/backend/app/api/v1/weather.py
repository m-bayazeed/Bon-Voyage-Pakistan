import logging
from typing import Optional
from fastapi import APIRouter, Query, status
from app.models.weather import WeatherResponse
from app.services.weather_service import weather_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/weather", tags=["Live Weather & Travel Conditions"])


@router.get(
    "/current",
    response_model=WeatherResponse,
    status_code=status.HTTP_200_OK,
    summary="Get Current Weather & Travel Conditions",
    description="Retrieves live real-time weather from OpenWeatherMap API and generates dynamic travel safety advisories for Pakistani routes.",
)
async def get_current_weather(
    city: Optional[str] = Query(default=None, description="Pakistani city name (e.g. Islamabad, Hunza, Skardu, Lahore)"),
    lat: Optional[float] = Query(default=None, description="Latitude coordinate"),
    lon: Optional[float] = Query(default=None, description="Longitude coordinate"),
):
    """Retrieve live weather and situational road safety advisories."""
    return await weather_service.get_current_weather(city=city, lat=lat, lon=lon)
