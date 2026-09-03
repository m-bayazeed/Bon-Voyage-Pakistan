import hashlib
import logging
from datetime import datetime, timezone, timedelta
from typing import Dict, List, Optional
import httpx

logger = logging.getLogger(__name__)

# Key Pakistani Tourist Hubs, Corridors, and Mountain Passes
MONITORED_WEATHER_LOCATIONS = [
    {
        "name": "Babusar Pass Summit",
        "city": "Naran & Kaghan",
        "region": "Babusar Top (13,691 ft), Kaghan Valley",
        "latitude": 35.1500,
        "longitude": 74.0500,
        "is_pass": True,
    },
    {
        "name": "Hunza Valley & KKH",
        "city": "Hunza Valley",
        "region": "Karimabad, Attabad & Upper Hunza (KKH)",
        "latitude": 36.3167,
        "longitude": 74.6500,
        "is_pass": False,
    },
    {
        "name": "Skardu & Baltistan Gorge",
        "city": "Skardu & Baltistan",
        "region": "Skardu, Shigar & Jaglot-Skardu Road",
        "latitude": 35.2971,
        "longitude": 75.6333,
        "is_pass": False,
    },
    {
        "name": "Swat & Kalam Valley",
        "city": "Swat & Kalam",
        "region": "Kalam, Ushu & Bahrain Catchment",
        "latitude": 35.4909,
        "longitude": 72.5878,
        "is_pass": False,
    },
    {
        "name": "Murree & Galiyat Corridor",
        "city": "Murree & Galiyat",
        "region": "Murree Expressway (N-75), Nathia Gali & Changla Gali",
        "latitude": 33.9062,
        "longitude": 73.3903,
        "is_pass": True,
    },
    {
        "name": "Naran & Saif-ul-Malook",
        "city": "Naran & Kaghan",
        "region": "Naran Valley & Kunhar River Basin",
        "latitude": 34.9085,
        "longitude": 73.6542,
        "is_pass": False,
    },
    {
        "name": "Islamabad & Margalla Foothills",
        "city": "Islamabad",
        "region": "Islamabad Capital Territory & Margalla Hills",
        "latitude": 33.6844,
        "longitude": 73.0479,
        "is_pass": False,
    },
    {
        "name": "Lahore & M-2 Motorway",
        "city": "Lahore",
        "region": "Lahore Urban & M-2 / M-3 Motorway Interchange",
        "latitude": 31.5204,
        "longitude": 74.3587,
        "is_pass": False,
    },
    {
        "name": "Karachi Coastal Belt",
        "city": "Karachi",
        "region": "Karachi Coast, Clifton, Manora & Arabian Sea",
        "latitude": 24.8607,
        "longitude": 67.0011,
        "is_pass": False,
    },
    {
        "name": "Quetta & Ziarat Juniper Belt",
        "city": "Quetta & Ziarat",
        "region": "Ziarat Valley, Bolan Pass & Quetta Highlands",
        "latitude": 30.3800,
        "longitude": 67.7200,
        "is_pass": False,
    },
    {
        "name": "Peshawar & Khyber Passway",
        "city": "Peshawar",
        "region": "Peshawar Valley & Northern Ring Road",
        "latitude": 34.0151,
        "longitude": 71.5249,
        "is_pass": False,
    },
]

# WMO Weather Code Interpretations & Hazard Thresholds
WMO_HAZARD_DESCRIPTIONS = {
    95: ("Thunderstorm Active", "high", "Thunderstorm activity detected with potential lightning and localized downpours."),
    96: ("Severe Thunderstorm & Hail", "critical", "Severe thunderstorm with hail hazards detected in the area. Travel on open ridges is dangerous."),
    99: ("Severe Heavy Hailstorm", "critical", "Violent hailstorm and turbulent squalls detected. Immediate shelter advised."),
    71: ("Slight Snowfall Advisory", "moderate", "Light snowfall reported. Slopes and asphalt may become slippery; maintain reduced speeds."),
    73: ("Moderate Snowfall Warning", "high", "Steady snowfall accumulating on mountain tracks. Snow chains strongly recommended."),
    75: ("Heavy Snowfall Hazard", "critical", "Intense snowfall and blizzard conditions causing heavy snow accumulation and reduced traction."),
    77: ("Snow Grains / Freezing Pellets", "moderate", "Snow grains and ice pellets reported on road surface."),
    85: ("Snow Showers Alert", "moderate", "Intermittent snow showers causing rapid visibility drops on high altitude roads."),
    86: ("Heavy Snow Shower Warning", "critical", "Severe snow showers and drifting snow creating treacherous mountain driving conditions."),
    65: ("Heavy Rain Downpour", "high", "Heavy precipitation detected. High risk of localized flash run-off and mountain mudslides."),
    82: ("Violent Rain Showers", "critical", "Torrential rainfall showers active. Mountain nullahs and streams may swell rapidly."),
    66: ("Freezing Rain / Black Ice Alert", "critical", "Freezing drizzle causing invisible black ice formation on road surfaces."),
    67: ("Heavy Freezing Rain Hazard", "critical", "Heavy freezing rain creating severe sheet ice hazard on roadways."),
    45: ("Dense Fog / Low Visibility", "moderate", "Dense fog limiting visibility below safe highway driving margins."),
    48: ("Depositing Rime Fog", "high", "Freezing rime fog coating roads and trees with frost and icy glazing."),
}


class WeatherCollector:
    """Collects real-time live weather hazards for Pakistan from Open-Meteo API."""

    def __init__(self):
        self.api_url = "https://api.open-meteo.com/v1/forecast"

    async def fetch_weather_for_location(
        self,
        client: httpx.AsyncClient,
        loc: Dict,
    ) -> Optional[Dict]:
        """Fetch current weather metrics for a single geographical point."""
        params = {
            "latitude": loc["latitude"],
            "longitude": loc["longitude"],
            "current": [
                "temperature_2m",
                "relative_humidity_2m",
                "precipitation",
                "weather_code",
                "wind_speed_10m",
                "wind_gusts_10m",
            ],
            "timezone": "Asia/Karachi",
        }
        try:
            response = await client.get(self.api_url, params=params, timeout=10.0)
            if response.status_code == 200:
                data = response.json()
                return data.get("current", {})
        except Exception as e:
            logger.warning(f"Failed to fetch weather for {loc['name']}: {e}")
        return None

    def evaluate_hazards(self, loc: Dict, current: Dict) -> Optional[Dict]:
        """
        Evaluate if current weather condition qualifies as an advisory/hazard.
        Returns alert payload if hazardous, None if weather is normal.
        """
        weather_code = int(current.get("weather_code", 0))
        temp = float(current.get("temperature_2m", 25.0))
        precip = float(current.get("precipitation", 0.0))
        wind_speed = float(current.get("wind_speed_10m", 0.0))
        wind_gusts = float(current.get("wind_gusts_10m", 0.0))

        hazard_found = False
        title = ""
        severity = "moderate"
        desc = ""
        action = ""

        # 1. WMO Code evaluation
        if weather_code in WMO_HAZARD_DESCRIPTIONS:
            hazard_found = True
            hazard_name, sev, default_desc = WMO_HAZARD_DESCRIPTIONS[weather_code]
            title = f"{loc['name']}: {hazard_name}"
            severity = sev
            desc = f"{default_desc} Current temperature: {temp}°C, Precipitation: {precip} mm/h, Wind Gusts: {wind_gusts} km/h."
            if sev == "critical":
                action = "Avoid mountain transit until conditions improve. Maintain contact with local rescue helplines."
            elif sev == "high":
                action = "Drive in low gear, ensure high-visibility lights are on, and avoid stopping near steep slopes."
            else:
                action = "Exercise caution and allow extra transit time."

        # 2. High Wind Gusts Evaluation (> 55 km/h or > 45 km/h on mountain passes)
        elif wind_gusts >= 55.0 or (loc.get("is_pass") and wind_gusts >= 45.0):
            hazard_found = True
            is_critical = wind_gusts >= 75.0
            severity = "critical" if is_critical else "high"
            title = f"{loc['name']}: Gale Force Wind Warning ({wind_gusts:.0f} km/h)"
            desc = f"Strong crosswinds and gale gusts reaching {wind_gusts:.0f} km/h recorded. High-sided vehicles and roof-loaded transport at risk of instability."
            action = "Reduce vehicle speed, grip steering firmly with both hands, and avoid overtaking along high ridge corridors."

        # 3. Heavy Rain without specific WMO code (> 8.0 mm/h)
        elif precip >= 8.0:
            hazard_found = True
            severity = "high"
            title = f"{loc['name']}: Heavy Rainfall & Runoff Warning"
            desc = f"Heavy precipitation of {precip:.1f} mm/h actively falling in {loc['region']}. Risk of flash flooding in seasonal nullahs."
            action = "Do not park or camp near dry stream beds or steep mountain faces."

        # 4. Severe Subzero Freeze on Mountain Passes (< -8°C)
        elif loc.get("is_pass") and temp <= -8.0:
            hazard_found = True
            severity = "high"
            title = f"{loc['name']}: Severe Subzero Freezing ({temp:.1f}°C)"
            desc = f"Severe freezing conditions ({temp:.1f}°C) over {loc['region']}. High risk of diesel fuel gelling and frozen brake lines."
            action = "Ensure winter-grade fuel with anti-gel additives and pack thermal emergency sleeping gear."

        if not hazard_found:
            return None

        # Build stable deterministic ID based on location and current date (Asia/Karachi)
        now_utc = datetime.now(timezone.utc)
        date_stamp = now_utc.strftime("%Y%m%d")
        hash_seed = f"wx_{loc['city']}_{loc['name']}_{weather_code}_{severity}_{date_stamp}"
        stable_id = f"WX-{loc['city'][:3].upper()}-{hashlib.md5(hash_seed.encode()).hexdigest()[:8]}"

        return {
            "id": stable_id,
            "category": "weather",
            "severity": severity,
            "title": title,
            "location": loc["region"],
            "city": loc["city"],
            "latitude": loc["latitude"],
            "longitude": loc["longitude"],
            "description": desc,
            "recommended_action": action,
            "source": "Open-Meteo Real-Time Weather & PMD Guidance",
            "created_at": now_utc,
            "expires_at": now_utc + timedelta(hours=6),
            "raw_data": f"temp={temp},precip={precip},wind_gusts={wind_gusts},wmo={weather_code}",
        }

    async def collect_live_alerts(self) -> List[Dict]:
        """Collect all active weather hazards across Pakistani monitoring hubs."""
        alerts = []
        async with httpx.AsyncClient(timeout=12.0) as client:
            for loc in MONITORED_WEATHER_LOCATIONS:
                current_metrics = await self.fetch_weather_for_location(client, loc)
                if current_metrics:
                    alert = self.evaluate_hazards(loc, current_metrics)
                    if alert:
                        alerts.append(alert)
        logger.info(f"Weather collector completed: {len(alerts)} active hazards found.")
        return alerts


weather_collector = WeatherCollector()
