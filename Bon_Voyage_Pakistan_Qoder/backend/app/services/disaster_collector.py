import logging
import math
from datetime import datetime, timezone, timedelta
from typing import Dict, List, Optional
import httpx

logger = logging.getLogger(__name__)

# Reference centers of major Pakistani tourist corridors for proximity matching
PAKISTAN_REGIONS = [
    {"city": "Swat & Kalam", "lat": 35.4909, "lon": 72.5878, "region": "Swat Valley & Malakand Belt"},
    {"city": "Hunza Valley", "lat": 36.3167, "lon": 74.6500, "region": "Gilgit-Baltistan & Hunza Valley"},
    {"city": "Skardu & Baltistan", "lat": 35.2971, "lon": 75.6333, "region": "Baltistan & Indus Gorge"},
    {"city": "Naran & Kaghan", "lat": 34.9085, "lon": 73.6542, "region": "Kaghan Valley & Hazara"},
    {"city": "Murree & Galiyat", "lat": 33.9062, "lon": 73.3903, "region": "Murree Hills & Galiyat"},
    {"city": "Islamabad", "lat": 33.6844, "lon": 73.0479, "region": "Potohar & Capital Territory"},
    {"city": "Quetta & Ziarat", "lat": 30.1798, "lon": 66.9750, "region": "Chaman Fault Zone & Quetta Ridge"},
    {"city": "Peshawar", "lat": 34.0151, "lon": 71.5249, "region": "Peshawar & Khyber Corridor"},
    {"city": "Lahore", "lat": 31.5204, "lon": 74.3587, "region": "Punjab Plains"},
    {"city": "Karachi", "lat": 24.8607, "lon": 67.0011, "region": "Sindh Coastal Zone & Makran"},
]


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate great circle distance between two points in km."""
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (
        math.sin(dlat / 2.0) ** 2
        + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2.0) ** 2
    )
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return R * c


class DisasterCollector:
    """Collects real-time seismic and natural disaster feeds from USGS Earthquakes API."""

    def __init__(self):
        self.usgs_url = "https://earthquake.usgs.gov/fdsnws/event/1/query"

    async def collect_live_disasters(self) -> List[Dict]:
        """
        Query real earthquake events for Pakistan and bordering northern/western seismic regions.
        Covers latitudes 23.0 to 37.5 N and longitudes 60.0 to 78.5 E.
        Only keeps events with magnitude >= 4.0 within the last 7 days.
        """
        now_utc = datetime.now(timezone.utc)
        start_time = (now_utc - timedelta(days=7)).strftime("%Y-%m-%dT%H:%M:%S")

        params = {
            "format": "geojson",
            "minmagnitude": 4.0,
            "minlatitude": 23.0,
            "maxlatitude": 37.5,
            "minlongitude": 60.0,
            "maxlongitude": 78.5,
            "starttime": start_time,
            "orderby": "time",
            "limit": 15,
        }

        alerts = []
        try:
            async with httpx.AsyncClient(timeout=12.0) as client:
                response = await client.get(self.usgs_url, params=params)
                if response.status_code == 200:
                    data = response.json()
                    features = data.get("features", [])
                    for feat in features:
                        props = feat.get("properties", {})
                        geom = feat.get("geometry", {})
                        coords = geom.get("coordinates", [])

                        if len(coords) < 2:
                            continue

                        eq_lon = float(coords[0])
                        eq_lat = float(coords[1])
                        depth_km = float(coords[2]) if len(coords) > 2 else 10.0

                        mag = float(props.get("mag") or 4.0)
                        place = props.get("place") or "Regional Seismic Zone"
                        time_ms = props.get("time")
                        usgs_id = feat.get("id") or f"usgs_{int(time_ms)}"

                        event_time = (
                            datetime.fromtimestamp(time_ms / 1000.0, tz=timezone.utc)
                            if time_ms
                            else now_utc
                        )

                        # Find closest Pakistani tourist corridor
                        closest_region = None
                        min_dist = float("inf")
                        for r in PAKISTAN_REGIONS:
                            d = haversine_km(eq_lat, eq_lon, r["lat"], r["lon"])
                            if d < min_dist:
                                min_dist = d
                                closest_region = r

                        # Proximity filtering: only alert if within 450 km of Pakistan tourist corridor
                        if min_dist > 450.0:
                            continue

                        city_assigned = closest_region["city"] if closest_region else "All Pakistan"
                        loc_display = f"{place} (~{min_dist:.0f} km from {city_assigned})"

                        # Severity classification based on magnitude
                        if mag >= 6.0:
                            severity = "critical"
                            title = f"Major Earthquake M{mag:.1f} Recorded: {place}"
                            action = "Inspect structures for damage before re-entering. Check roads for rockfall before driving through mountain cuts."
                        elif mag >= 5.0:
                            severity = "high"
                            title = f"Moderate-Strong Earthquake M{mag:.1f}: {place}"
                            action = "Stay alert for aftershocks and potential roadside rock slippage along steep cliffs."
                        else:
                            severity = "moderate"
                            title = f"Earthquake Tremor M{mag:.1f}: {place}"
                            action = "No immediate damage reported. Maintain routine situational awareness."

                        desc = (
                            f"A magnitude {mag:.1f} seismic event occurred at depth {depth_km:.1f} km. "
                            f"Epicenter: {place} ({eq_lat:.2f}°N, {eq_lon:.2f}°E). "
                            f"Recorded at {event_time.strftime('%Y-%m-%d %H:%M UTC')}."
                        )

                        stable_id = f"EQ-{usgs_id}"
                        alerts.append({
                            "id": stable_id,
                            "category": "naturalDisaster",
                            "severity": severity,
                            "title": title,
                            "location": loc_display,
                            "city": city_assigned,
                            "latitude": eq_lat,
                            "longitude": eq_lon,
                            "description": desc,
                            "recommended_action": action,
                            "source": "USGS Real-Time Earthquake Hazards Program",
                            "created_at": event_time,
                            "expires_at": event_time + timedelta(days=5),
                            "raw_data": f"mag={mag},depth={depth_km},place={place}",
                        })
        except Exception as e:
            logger.warning(f"Failed to query USGS Earthquake API: {e}")

        logger.info(f"Disaster collector completed: {len(alerts)} real seismic events identified.")
        return alerts


disaster_collector = DisasterCollector()
