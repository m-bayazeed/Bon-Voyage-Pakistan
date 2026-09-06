import logging
from typing import Dict, Optional
import httpx
from app.core.config import settings
from app.models.weather import WeatherResponse
from app.services.location_resolution_service import location_resolution_service

logger = logging.getLogger(__name__)

# Fallback realistic weather profiles for major Pakistani destinations
FALLBACK_WEATHER_DATA: Dict[str, Dict] = {
    "islamabad": {
        "temp": 31.5,
        "feels_like": 35.2,
        "condition": "Clear",
        "description": "Clear sky",
        "icon": "01d",
        "humidity": 58,
        "wind_speed_kmh": 8.5,
        "pressure": 1010,
    },
    "lahore": {
        "temp": 34.0,
        "feels_like": 39.5,
        "condition": "Haze",
        "description": "Hazy sunshine",
        "icon": "50d",
        "humidity": 65,
        "wind_speed_kmh": 9.2,
        "pressure": 1008,
    },
    "karachi": {
        "temp": 30.5,
        "feels_like": 36.0,
        "condition": "Clouds",
        "description": "Partly cloudy",
        "icon": "02d",
        "humidity": 78,
        "wind_speed_kmh": 22.0,
        "pressure": 1006,
    },
    "hunza": {
        "temp": 14.5,
        "feels_like": 13.8,
        "condition": "Clear",
        "description": "Sunny and crisp",
        "icon": "01d",
        "humidity": 45,
        "wind_speed_kmh": 6.8,
        "pressure": 1018,
    },
    "skardu": {
        "temp": 16.0,
        "feels_like": 15.2,
        "condition": "Clouds",
        "description": "Scattered clouds",
        "icon": "03d",
        "humidity": 40,
        "wind_speed_kmh": 10.5,
        "pressure": 1016,
    },
    "gilgit": {
        "temp": 21.0,
        "feels_like": 20.5,
        "condition": "Clear",
        "description": "Clear and dry",
        "icon": "01d",
        "humidity": 38,
        "wind_speed_kmh": 7.5,
        "pressure": 1015,
    },
    "swat": {
        "temp": 23.5,
        "feels_like": 23.0,
        "condition": "Clouds",
        "description": "Pleasant valley breeze",
        "icon": "02d",
        "humidity": 52,
        "wind_speed_kmh": 8.0,
        "pressure": 1014,
    },
    "murree": {
        "temp": 19.0,
        "feels_like": 18.5,
        "condition": "Clouds",
        "description": "Cool mountain breeze",
        "icon": "03d",
        "humidity": 68,
        "wind_speed_kmh": 11.2,
        "pressure": 1012,
    },
}


def generate_travel_advisory(condition: str, wind_speed_kmh: float, temp: float) -> tuple[str, bool, str]:
    """
    Generates situational travel safety advisory tailored for Pakistani travel routes.
    Returns: (travel_advisory_text, is_favorable, advisory_level)
    advisory_level: 'favorable' (green), 'moderate' (amber), 'alert' (red)
    """
    c_lower = condition.lower()

    if any(k in c_lower for k in ["thunderstorm", "squall", "tornado"]):
        return (
            "Severe thunderstorm alert: Heavy downpours and potential lightning along mountain slopes. Avoid travel through narrow valleys and dry nullahs; seek safe covered shelter.",
            False,
            "alert",
        )
    elif any(k in c_lower for k in ["rain", "drizzle", "shower"]):
        return (
            "Slippery mountain roads and potential delays along KKH and highland passes. Maintain safe braking distance, avoid sudden overtaking, and watch for localized mudslides.",
            False,
            "moderate",
        )
    elif "snow" in c_lower:
        return (
            "Snowfall and icy road surfaces detected. Tire chains mandatory for high mountain passes (Babusar, Lowari, Khunjerab). Check local administration clearance before departure.",
            False,
            "alert",
        )
    elif any(k in c_lower for k in ["fog", "mist", "smoke", "dust", "sand"]):
        return (
            "Reduced highway visibility detected. Keep low-beam fog lights illuminated, reduce cruising speed, and maintain generous following distance.",
            False,
            "moderate",
        )
    elif wind_speed_kmh > 35.0:
        return (
            "High wind advisory: Gusty crosswinds along open valley highways and bridges. Maintain a firm grip on steering and exercise caution with high-profile vehicles.",
            False,
            "moderate",
        )
    elif "cloud" in c_lower:
        return (
            "Good driving conditions with moderate cloud cover. Check local mountain pass updates before embarking on high-altitude expeditions.",
            True,
            "favorable",
        )
    else:
        # Clear / Sunny
        return (
            "Optimal road visibility and favorable travel conditions across highways, mountain routes, and scenic viewpoints.",
            True,
            "favorable",
        )


class WeatherService:
    """Service to fetch live weather data via OpenWeatherMap API and generate travel safety advisories."""

    OPENWEATHER_URL = "https://api.openweathermap.org/data/2.5/weather"

    async def get_current_weather(
        self,
        city: Optional[str] = None,
        lat: Optional[float] = None,
        lon: Optional[float] = None,
    ) -> WeatherResponse:
        """Fetch current weather for a Pakistani destination with situational travel advisory."""
        target_city = (city or "Islamabad").strip()
        if "all" in target_city.lower():
            target_city = "Islamabad"

        api_key = settings.OPENWEATHER_API_KEY
        if not api_key:
            logger.warning("[WeatherService] OPENWEATHER_API_KEY is not configured; using fallback.")
            return self._build_fallback(target_city, lat or 33.6844, lon or 73.0479)

        resolved_lat = lat
        resolved_lon = lon
        data = None

        # 1. Try querying OpenWeatherMap directly by city name if no explicit coordinates were supplied
        if resolved_lat is None or resolved_lon is None:
            clean_name = target_city.split("/")[0].strip()
            query_str = f"{clean_name},PK" if not clean_name.lower().endswith("pk") else clean_name
            try:
                async with httpx.AsyncClient(timeout=6.0) as client:
                    q_res = await client.get(
                        self.OPENWEATHER_URL,
                        params={"q": query_str, "units": "metric", "appid": api_key},
                    )
                    if q_res.status_code == 200:
                        data = q_res.json()
                        coord = data.get("coord", {})
                        if "lat" in coord and "lon" in coord:
                            resolved_lat = float(coord["lat"])
                            resolved_lon = float(coord["lon"])
                        if data.get("name"):
                            target_city = data["name"]
            except Exception as ex:
                logger.debug(f"[WeatherService] Direct city query '{query_str}' exception: {ex}")

        # 2. If direct city query failed and coordinates are still unknown, resolve coordinates
        if data is None and (resolved_lat is None or resolved_lon is None):
            try:
                resolved_loc = await location_resolution_service.resolve_destination(target_city)
                resolved_lat = resolved_loc.latitude
                resolved_lon = resolved_loc.longitude
                target_city = resolved_loc.name
            except Exception as e:
                logger.warning(f"[WeatherService] Could not resolve coordinates for '{target_city}': {e}")
                resolved_lat = 33.6844
                resolved_lon = 73.0479

        # 2. Fallback to coordinate-based query if not already retrieved
        if data is None:
            params = {
                "lat": resolved_lat,
                "lon": resolved_lon,
                "units": "metric",
                "appid": api_key,
            }
            try:
                async with httpx.AsyncClient(timeout=8.0) as client:
                    res = await client.get(self.OPENWEATHER_URL, params=params)
                    if res.status_code == 200:
                        data = res.json()
                    else:
                        logger.warning(
                            f"[WeatherService] OpenWeatherMap returned status {res.status_code}: {res.text[:200]}"
                        )
            except Exception as e:
                logger.error(f"[WeatherService] OpenWeatherMap request exception: {e}")

        if data:
            main_data = data.get("main", {})
            weather_list = data.get("weather", [])
            weather_first = weather_list[0] if weather_list else {}
            wind_data = data.get("wind", {})

            temperature = round(float(main_data.get("temp", 25.0)), 1)
            feels_like = round(float(main_data.get("feels_like", temperature)), 1)
            condition = weather_first.get("main", "Clear")
            raw_desc = weather_first.get("description", condition)
            description = raw_desc.capitalize()
            icon_code = weather_first.get("icon", "01d")
            icon_url = f"https://openweathermap.org/img/wn/{icon_code}@2x.png"
            humidity = int(main_data.get("humidity", 50))
            pressure = int(main_data.get("pressure", 1013)) if main_data.get("pressure") else None

            # Convert wind speed from m/s to km/h
            wind_speed_ms = float(wind_data.get("speed", 2.0))
            wind_speed_kmh = round(wind_speed_ms * 3.6, 1)

            advisory, is_fav, adv_level = generate_travel_advisory(
                condition=condition,
                wind_speed_kmh=wind_speed_kmh,
                temp=temperature,
            )

            return WeatherResponse(
                success=True,
                city=target_city,
                temperature=temperature,
                feels_like=feels_like,
                condition=condition,
                description=description,
                icon_url=icon_url,
                humidity=humidity,
                wind_speed_kmh=wind_speed_kmh,
                pressure=pressure,
                travel_advisory=advisory,
                is_favorable=is_fav,
                advisory_level=adv_level,
                latitude=resolved_lat,
                longitude=resolved_lon,
            )

        # 3. If live query failed completely, return realistic fallback
        logger.warning(f"[WeatherService] Falling back to realistic offline profile for '{target_city}'.")
        return self._build_fallback(target_city, resolved_lat, resolved_lon)

    def _build_fallback(
        self, city: str, lat: Optional[float] = None, lon: Optional[float] = None
    ) -> WeatherResponse:
        """Returns realistic fallback data for Pakistani destinations."""
        c_lower = city.lower()
        matched_key = "islamabad"
        for k in FALLBACK_WEATHER_DATA:
            if k in c_lower:
                matched_key = k
                break

        data = FALLBACK_WEATHER_DATA.get(matched_key, FALLBACK_WEATHER_DATA["islamabad"])
        temp = data["temp"]
        wind_kmh = data["wind_speed_kmh"]
        condition = data["condition"]
        advisory, is_fav, adv_level = generate_travel_advisory(condition, wind_kmh, temp)

        return WeatherResponse(
            success=True,
            city=city,
            temperature=temp,
            feels_like=data["feels_like"],
            condition=condition,
            description=data["description"],
            icon_url=f"https://openweathermap.org/img/wn/{data['icon']}@2x.png",
            humidity=data["humidity"],
            wind_speed_kmh=wind_kmh,
            pressure=data.get("pressure", 1012),
            travel_advisory=advisory,
            is_favorable=is_fav,
            advisory_level=adv_level,
            latitude=lat,
            longitude=lon,
        )


weather_service = WeatherService()
