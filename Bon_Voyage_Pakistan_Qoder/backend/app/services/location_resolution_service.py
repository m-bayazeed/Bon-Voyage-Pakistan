import asyncio
import json
import logging
import re
from typing import Any, Dict, List, Optional
import httpx
from google import genai
from google.genai import types
from pydantic import BaseModel, Field
from app.core.config import settings

logger = logging.getLogger(__name__)


class ResolvedLocation(BaseModel):
    name: str = Field(..., description="Destination name in Pakistan")
    country: str = Field(default="Pakistan", description="Country name")
    latitude: float = Field(..., description="Geographic latitude coordinate")
    longitude: float = Field(..., description="Geographic longitude coordinate")
    radius_km: float = Field(default=40.0, description="Recommended search radius in km to cover the entire destination")
    is_ambiguous: bool = Field(default=False, description="Whether the location is ambiguous")


# Canonical coordinates and search radii for supported Pakistani cities
CANONICAL_CITY_COORDINATES: Dict[str, Dict[str, Any]] = {
    "islamabad": {"name": "Islamabad", "latitude": 33.6844, "longitude": 73.0479, "radius_km": 20.0},
    "rawalpindi": {"name": "Rawalpindi", "latitude": 33.5973, "longitude": 73.0479, "radius_km": 20.0},
    "lahore": {"name": "Lahore", "latitude": 31.5204, "longitude": 74.3587, "radius_km": 28.0},
    "karachi": {"name": "Karachi", "latitude": 24.8607, "longitude": 67.0011, "radius_km": 32.0},
    "hunza": {"name": "Hunza", "latitude": 36.3167, "longitude": 74.6500, "radius_km": 25.0},
    "karimabad": {"name": "Hunza / Karimabad", "latitude": 36.3167, "longitude": 74.6500, "radius_km": 20.0},
    "hunza / karimabad": {"name": "Hunza / Karimabad", "latitude": 36.3167, "longitude": 74.6500, "radius_km": 25.0},
    "skardu": {"name": "Skardu", "latitude": 35.2971, "longitude": 75.6333, "radius_km": 25.0},
    "gilgit": {"name": "Gilgit", "latitude": 35.9208, "longitude": 74.3144, "radius_km": 20.0},
    "swat": {"name": "Swat / Kalam", "latitude": 35.4859, "longitude": 72.5855, "radius_km": 30.0},
    "kalam": {"name": "Swat / Kalam", "latitude": 35.4859, "longitude": 72.5855, "radius_km": 20.0},
    "swat / kalam": {"name": "Swat / Kalam", "latitude": 35.4859, "longitude": 72.5855, "radius_km": 30.0},
    "murree": {"name": "Murree", "latitude": 33.9062, "longitude": 73.3903, "radius_km": 15.0},
    "murree & galiyat": {"name": "Murree & Galiyat", "latitude": 33.9062, "longitude": 73.3903, "radius_km": 15.0},
    "bhurban": {"name": "Bhurban", "latitude": 33.9570, "longitude": 73.4590, "radius_km": 12.0},
    "naran": {"name": "Naran / Kaghan", "latitude": 34.9085, "longitude": 73.6542, "radius_km": 25.0},
    "kaghan": {"name": "Naran / Kaghan", "latitude": 34.9085, "longitude": 73.6542, "radius_km": 25.0},
    "naran / kaghan": {"name": "Naran / Kaghan", "latitude": 34.9085, "longitude": 73.6542, "radius_km": 25.0},
    "peshawar": {"name": "Peshawar", "latitude": 34.0151, "longitude": 71.5249, "radius_km": 20.0},
    "quetta": {"name": "Quetta", "latitude": 30.1798, "longitude": 66.9750, "radius_km": 20.0},
    "ziarat": {"name": "Ziarat", "latitude": 30.3824, "longitude": 67.7256, "radius_km": 18.0},
    "multan": {"name": "Multan", "latitude": 30.1575, "longitude": 71.5249, "radius_km": 20.0},
    "gwadar": {"name": "Gwadar", "latitude": 25.1264, "longitude": 62.3225, "radius_km": 20.0},
    "chitral": {"name": "Chitral", "latitude": 35.8510, "longitude": 71.7864, "radius_km": 25.0},
    "abbottabad": {"name": "Abbottabad", "latitude": 34.1688, "longitude": 73.2215, "radius_km": 20.0},
}

# In-memory coordinate cache initialized with canonical cities
_COORDINATE_CACHE: Dict[str, ResolvedLocation] = {
    k: ResolvedLocation(
        name=v["name"],
        country="Pakistan",
        latitude=v["latitude"],
        longitude=v["longitude"],
        radius_km=v["radius_km"],
        is_ambiguous=False,
    )
    for k, v in CANONICAL_CITY_COORDINATES.items()
}


class LocationResolutionService:
    """Service to dynamically resolve Pakistani destinations and whole-city search radii using Google Geocoding / Gemini / City Registry."""

    def __init__(self):
        self._client: Optional[genai.Client] = None

    def _get_client(self) -> Optional[genai.Client]:
        api_key = settings.GEMINI_API_KEY
        if not api_key:
            return None
        if self._client is None:
            self._client = genai.Client(api_key=api_key)
        return self._client

    async def _resolve_via_google_geocoding(self, destination: str) -> Optional[ResolvedLocation]:
        """Attempt resolution via Google Maps Geocoding API if key available."""
        api_key = settings.GOOGLE_PLACES_API_KEY or settings.GEMINI_API_KEY
        if not api_key:
            return None

        try:
            async with httpx.AsyncClient(timeout=6.0) as client:
                params = {
                    "address": f"{destination}, Pakistan",
                    "key": api_key,
                }
                res = await client.get(settings.GOOGLE_GEOCODE_URL, params=params)
                if res.status_code == 200:
                    data = res.json()
                    results = data.get("results", [])
                    if results:
                        first = results[0]
                        loc = first.get("geometry", {}).get("location", {})
                        lat = loc.get("lat")
                        lng = loc.get("lng")
                        if lat is not None and lng is not None:
                            return ResolvedLocation(
                                name=destination,
                                country="Pakistan",
                                latitude=float(lat),
                                longitude=float(lng),
                                radius_km=settings.CITY_SEARCH_RADIUS_KM,
                                is_ambiguous=False,
                            )
        except Exception as e:
            logger.warning(f"[LocationResolution] Google Geocoding error for '{destination}': {e}")
        return None

    def _resolve_via_gemini_sync(self, destination: str) -> ResolvedLocation:
        """Resolve destination center coordinates and radius using Gemini."""
        client = self._get_client()
        if not client:
            raise RuntimeError("Gemini API key is not configured.")

        prompt = f"""Given the Pakistani destination or city name provided by the user, return:
1. The approximate geographic center latitude and longitude of that destination.
2. The recommended search radius in kilometers (radius_km, typically 30.0 to 50.0 km) to cover the destination area.
3. The country and whether it is ambiguous.

Return only structured JSON matching the schema. Do not invent coordinates.

Destination: "{destination}"
"""
        config = types.GenerateContentConfig(
            response_mime_type="application/json",
            response_schema=ResolvedLocation,
            temperature=0.0,
        )

        candidate_models = settings.GEMINI_FALLBACK_MODELS
        unique_models = [m for m in dict.fromkeys(candidate_models) if m]


        last_err = None
        for model_name in unique_models:
            try:
                response = client.models.generate_content(
                    model=model_name,
                    contents=prompt,
                    config=config,
                )
                if response.text:
                    res = ResolvedLocation.model_validate_json(response.text)
                    res.radius_km = max(25.0, min(res.radius_km, 60.0))
                    return res
            except Exception as e:
                logger.warning(f"[LocationResolution] Gemini model {model_name} failed: {e}")
                last_err = e

        if last_err:
            raise last_err
        raise ValueError("Gemini returned empty response for destination coordinate resolution.")

    async def resolve_destination(self, destination: str) -> ResolvedLocation:
        """
        Dynamically resolve destination into geographic coordinates and radius.
        Priority: Cache -> Supported Cities Registry -> Google Geocoding -> Gemini -> Fallback.
        """
        dest_clean = destination.strip()
        cache_key = dest_clean.lower()

        if cache_key in _COORDINATE_CACHE:
            return _COORDINATE_CACHE[cache_key]

        # 1. Direct canonical lookup & stem/substring matching
        for key, info in CANONICAL_CITY_COORDINATES.items():
            key_clean = key.lower()
            if (
                key_clean == cache_key
                or key_clean in cache_key
                or cache_key in key_clean
            ):
                res = ResolvedLocation(
                    name=info["name"],
                    country="Pakistan",
                    latitude=info["latitude"],
                    longitude=info["longitude"],
                    radius_km=info["radius_km"],
                    is_ambiguous=False,
                )
                _COORDINATE_CACHE[cache_key] = res
                return res

        # 2. Key stem matching for common variations / typos
        stem_map = {
            "islamab": "islamabad",
            "isb": "islamabad",
            "lahor": "lahore",
            "lhr": "lahore",
            "karach": "karachi",
            "khi": "karachi",
            "hunza": "hunza",
            "karimabad": "karimabad",
            "skardu": "skardu",
            "skard": "skardu",
            "gilgit": "gilgit",
            "swat": "swat",
            "kalam": "kalam",
            "murree": "murree",
            "naran": "naran",
            "kaghan": "kaghan",
            "rawalpind": "rawalpindi",
            "pindi": "rawalpindi",
            "peshaw": "peshawar",
            "quetta": "quetta",
            "ziarat": "ziarat",
            "multan": "multan",
            "gwadar": "gwadar",
        }
        for stem, target_key in stem_map.items():
            if stem in cache_key:
                info = CANONICAL_CITY_COORDINATES[target_key]
                res = ResolvedLocation(
                    name=info["name"],
                    country="Pakistan",
                    latitude=info["latitude"],
                    longitude=info["longitude"],
                    radius_km=info["radius_km"],
                    is_ambiguous=False,
                )
                _COORDINATE_CACHE[cache_key] = res
                return res

        # Attempt Google Geocoding
        geo_res = await self._resolve_via_google_geocoding(dest_clean)
        if geo_res:
            _COORDINATE_CACHE[cache_key] = geo_res
            return geo_res

        # Attempt Gemini resolution
        try:
            resolved = await asyncio.to_thread(self._resolve_via_gemini_sync, dest_clean)
            _COORDINATE_CACHE[cache_key] = resolved
            return resolved
        except Exception as e:
            logger.warning(f"[LocationResolution] Gemini resolution failed for '{dest_clean}': {e}")

        # Safe fallback to Islamabad
        fallback = ResolvedLocation(
            name=dest_clean,
            country="Pakistan",
            latitude=33.6844,
            longitude=73.0479,
            radius_km=settings.DEFAULT_SEARCH_RADIUS_KM,
            is_ambiguous=True,
        )
        _COORDINATE_CACHE[cache_key] = fallback
        return fallback


location_resolution_service = LocationResolutionService()
