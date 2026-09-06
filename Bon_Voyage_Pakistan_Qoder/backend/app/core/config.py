import os
from pathlib import Path
from typing import Dict, List, Set
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
        return (
            os.getenv("GROQ_API_KEY_TripPlan")
            or os.getenv("GROQ_API_KEY")
            or ""
        ).strip()

    @property
    def GEMINI_API_KEY(self) -> str:
        # Priority: GEMINI_API_KEY -> GoogleAPI -> GOOGLE_API_KEY -> Google_Places_API_Key -> GOOGLE_PLACES_API_KEY -> GOOGLE_MAPS_API_KEY
        return (
            os.getenv("GEMINI_API_KEY")
            or os.getenv("GoogleAPI")
            or os.getenv("GOOGLE_API_KEY")
            or os.getenv("Google_Places_API_Key")
            or os.getenv("GOOGLE_PLACES_API_KEY")
            or os.getenv("GOOGLE_MAPS_API_KEY")
            or ""
        ).strip()

    @property
    def GOOGLE_PLACES_API_KEY(self) -> str:
        # Priority: Google_Places_API_Key -> GOOGLE_PLACES_API_KEY -> GOOGLE_MAPS_API_KEY -> GOOGLE_API_KEY -> GoogleAPI -> GEMINI_API_KEY
        return (
            os.getenv("Google_Places_API_Key")
            or os.getenv("GOOGLE_PLACES_API_KEY")
            or os.getenv("GOOGLE_MAPS_API_KEY")
            or os.getenv("GOOGLE_API_KEY")
            or os.getenv("GoogleAPI")
            or os.getenv("GEMINI_API_KEY")
            or ""
        ).strip()

    @property
    def GOOGLE_ROUTES_API_KEY(self) -> str:
        # Priority: GOOGLE_MAPS_API_KEY -> Google_Places_API_Key -> GOOGLE_PLACES_API_KEY -> GOOGLE_API_KEY -> GoogleAPI -> GEMINI_API_KEY
        return (
            os.getenv("GOOGLE_MAPS_API_KEY")
            or os.getenv("Google_Places_API_Key")
            or os.getenv("GOOGLE_PLACES_API_KEY")
            or os.getenv("GOOGLE_API_KEY")
            or os.getenv("GoogleAPI")
            or os.getenv("GEMINI_API_KEY")
            or ""
        ).strip()

    @property
    def GEOAPIFY_API_KEY(self) -> str:
        # Priority: GEOAPIFY_API_KEY -> GeoapifyAPI
        return (
            os.getenv("GEOAPIFY_API_KEY")
            or os.getenv("GeoapifyAPI")
            or ""
        ).strip()

    @property
    def OPENWEATHER_API_KEY(self) -> str:
        # Priority: OpenWeather_API -> OPENWEATHER_API_KEY -> OPEN_WEATHER_API
        return (
            os.getenv("OpenWeather_API")
            or os.getenv("OPENWEATHER_API_KEY")
            or os.getenv("OPEN_WEATHER_API")
            or ""
        ).strip()

    # AI Models
    GEMINI_MODEL: str = os.getenv("GEMINI_MODEL", "gemini-3.5-flash").strip()
    GEMINI_FALLBACK_MODELS: List[str] = [
        os.getenv("GEMINI_MODEL", "gemini-3.5-flash").strip(),
        "gemini-3.5-flash",
        "gemini-3.7-flash",
        "gemini-flash-latest",
        "gemini-3.6-flash",
    ]
    GROQ_WHISPER_MODEL: str = os.getenv("GROQ_WHISPER_MODEL", "whisper-large-v3").strip()




    # Google Places (New) & Google Routes Endpoints
    GOOGLE_PLACES_NEARBY_URL: str = "https://places.googleapis.com/v1/places:searchNearby"
    GOOGLE_PLACES_TEXT_SEARCH_URL: str = "https://places.googleapis.com/v1/places:searchText"
    GOOGLE_PLACES_DETAILS_URL: str = "https://places.googleapis.com/v1/places"
    GOOGLE_ROUTES_MATRIX_URL: str = "https://routes.googleapis.com/distanceMatrix/v2:computeRouteMatrix"
    GOOGLE_ROUTES_DIRECTIONS_URL: str = "https://routes.googleapis.com/directions/v2:computeRoutes"
    GOOGLE_GEOCODE_URL: str = "https://maps.googleapis.com/maps/api/geocode/json"

    # Geoapify Map Tiles Settings (osm-bright / osm-liberty with full road/street networks)
    GEOAPIFY_TILES_BASE_URL: str = "https://maps.geoapify.com/v1/tile"
    GEOAPIFY_DEFAULT_STYLE: str = "osm-bright"
    OPENSTREETMAP_TILES_URL: str = "https://tile.openstreetmap.org"

    # Search Radii
    CURRENT_LOCATION_RADIUS_KM: float = float(os.getenv("CURRENT_LOCATION_RADIUS_KM", "15.0"))
    CITY_SEARCH_RADIUS_KM: float = float(os.getenv("CITY_SEARCH_RADIUS_KM", "40.0"))
    DEFAULT_SEARCH_RADIUS_KM: float = 20.0
    MAX_SEARCH_RADIUS_KM: float = 60.0
    GOOGLE_PLACES_MAX_RESULTS: int = 20

    # Official Google Places API (New) Accommodation Included Types
    # Verified types supported by Places API (New) table A
    GOOGLE_ACCOMMODATION_TYPES: List[str] = [
        "hotel",
        "resort_hotel",
        "motel",
        "guest_house",
        "bed_and_breakfast",
        "lodging",
        "campground",
        "cottage",
        "extended_stay_hotel",
        "farmstay",
        "inn",
        "hostel",
    ]

    # Food & Dining settings (Places API New)
    FOOD_SEARCH_RADIUS_METERS: int = 30000
    GOOGLE_FOOD_TYPES: List[str] = [
        "restaurant",
        "cafe",
        "bakery",
        "fast_food_restaurant",
        "meal_takeaway",
        "meal_delivery",
    ]

    # Help & Emergency Facilities settings (Places API New)
    HELP_SEARCH_RADIUS_METERS: int = 30000
    HELP_TYPE_MAPPING: Dict[str, List[str]] = {
        "hospital": ["hospital"],
        "clinic": ["medical_clinic"],
        "pharmacy": ["pharmacy"],
        "doctor": ["doctor"],
        "first_aid": ["hospital", "medical_clinic", "doctor"],
        "firstaid": ["hospital", "medical_clinic", "doctor"],
        "emergency": ["hospital"],
        "police": ["police"],
        "fire": ["fire_station"],
        "ambulance": ["hospital"],
        "government": ["hospital"],
        "govt": ["hospital"],
        "private": ["hospital", "medical_clinic"],
        "privatehospital": ["hospital", "medical_clinic"],
    }
    GOOGLE_HELP_TYPES: List[str] = [
        "hospital",
        "pharmacy",
        "medical_clinic",
        "doctor",
        "police",
        "fire_station",
    ]

    # Supported Pakistani Cities with canonical center coordinates
    SUPPORTED_CITIES = [
        {"name": "Islamabad", "latitude": 33.6844, "longitude": 73.0479},
        {"name": "Lahore", "latitude": 31.5204, "longitude": 74.3587},
        {"name": "Hunza", "latitude": 36.3167, "longitude": 74.6500},
        {"name": "Hunza / Karimabad", "latitude": 36.3167, "longitude": 74.6500},
        {"name": "Skardu", "latitude": 35.2971, "longitude": 75.6333},
        {"name": "Gilgit", "latitude": 35.9208, "longitude": 74.3144},
        {"name": "Swat / Kalam", "latitude": 35.4859, "longitude": 72.5855},
        {"name": "Karachi", "latitude": 24.8607, "longitude": 67.0011},
        {"name": "Rawalpindi", "latitude": 33.5973, "longitude": 73.0479},
        {"name": "Murree", "latitude": 33.9062, "longitude": 73.3903},
        {"name": "Naran / Kaghan", "latitude": 34.9085, "longitude": 73.6542},
        {"name": "Peshawar", "latitude": 34.0151, "longitude": 71.5249},
        {"name": "Quetta", "latitude": 30.1798, "longitude": 66.9750},
        {"name": "Ziarat", "latitude": 30.3824, "longitude": 67.7256},
        {"name": "Multan", "latitude": 30.1575, "longitude": 71.5249},
        {"name": "Gwadar", "latitude": 25.1264, "longitude": 62.3225},
    ]

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
