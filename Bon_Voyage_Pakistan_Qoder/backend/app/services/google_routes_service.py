import asyncio
import logging
import re
import time
from typing import Any, Dict, List, Optional, Tuple
import httpx
from app.core.config import settings
from app.models.hotel import StayItem
from app.utils.geo import format_distance_string, format_eta_string, is_valid_coordinates

logger = logging.getLogger(__name__)


class GoogleRoutesService:
    """
    Production service for driving road distance and duration calculations.
    Supports Google Routes API / Distance Matrix API, with seamless high-accuracy
    Geoapify Route Matrix fallback to guarantee real road distances & ETAs.
    """

    def __init__(self):
        # In-memory route matrix cache: (origin_hash, dest_hash) -> (timestamp, distance_km, eta_minutes)
        self._cache: Dict[Tuple[str, str], Tuple[float, float, int]] = {}
        self._cache_ttl_seconds = 1800  # 30 minutes TTL

    def _get_google_key(self) -> str:
        return (
            settings.GOOGLE_ROUTES_API_KEY
            or settings.GOOGLE_PLACES_API_KEY
            or settings.GEMINI_API_KEY
        )

    def _get_geoapify_key(self) -> str:
        return settings.GEOAPIFY_API_KEY

    def _coord_key(self, lat: float, lon: float) -> str:
        return f"{round(lat, 4)}:{round(lon, 4)}"

    def _parse_duration_seconds(self, duration_str: Optional[str]) -> Optional[int]:
        """Parse duration string e.g. '1080s' into integer seconds."""
        if not duration_str:
            return None
        match = re.match(r"^(\d+)(?:\.\d+)?s$", str(duration_str).strip())
        if match:
            return int(match.group(1))
        return None

    def generate_directions_url(
        self,
        origin_lat: Optional[float],
        origin_lon: Optional[float],
        dest_lat: float,
        dest_lon: float,
    ) -> str:
        """
        Generate dynamic Google Maps turn-by-turn directions URL.
        Origin is user's device GPS; destination is place coordinates.
        """
        if origin_lat is not None and origin_lon is not None and is_valid_coordinates(origin_lat, origin_lon):
            return f"https://www.google.com/maps/dir/?api=1&origin={origin_lat:.5f},{origin_lon:.5f}&destination={dest_lat:.5f},{dest_lon:.5f}&travelmode=driving"
        return f"https://www.google.com/maps/dir/?api=1&destination={dest_lat:.5f},{dest_lon:.5f}&travelmode=driving"

    def _apply_route_to_item(self, item: Any, dist_km: float, eta_min: int):
        """Apply normalized driving distance and ETA to any model item."""
        dist_str = format_distance_string(dist_km)
        eta_str = format_eta_string(eta_min)

        if hasattr(item, "distance_km"):
            setattr(item, "distance_km", dist_km)
        if hasattr(item, "road_distance_km"):
            setattr(item, "road_distance_km", dist_km)
        if hasattr(item, "distanceKm"):
            setattr(item, "distanceKm", dist_km)
        if hasattr(item, "distance"):
            setattr(item, "distance", dist_str)
        if hasattr(item, "formatted_distance"):
            setattr(item, "formatted_distance", dist_str)

        if hasattr(item, "eta_minutes"):
            setattr(item, "eta_minutes", eta_min)
        if hasattr(item, "driving_duration_min"):
            setattr(item, "driving_duration_min", eta_min)
        if hasattr(item, "estimatedTravelTime"):
            setattr(item, "estimatedTravelTime", eta_str)

    async def _compute_via_geoapify(
        self,
        origin_lat: float,
        origin_lon: float,
        items_to_route: List[Any],
        geoapify_key: str,
    ) -> bool:
        """Calculate road distances and driving durations via Geoapify Route Matrix API."""
        if not geoapify_key or not items_to_route:
            return False

        url = f"https://api.geoapify.com/v1/routematrix?apiKey={geoapify_key}"
        # Geoapify takes location as [longitude, latitude]
        payload = {
            "mode": "drive",
            "sources": [{"location": [origin_lon, origin_lat]}],
            "targets": [{"location": [s.longitude, s.latitude]} for s in items_to_route],
        }

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                res = await client.post(url, json=payload)
                if res.status_code == 200:
                    data = res.json()
                    matrix_rows = data.get("sources_to_targets", [])
                    if matrix_rows and isinstance(matrix_rows[0], list):
                        results_row = matrix_rows[0]
                        for idx, target_res in enumerate(results_row):
                            if idx < len(items_to_route):
                                item = items_to_route[idx]
                                dist_meters = target_res.get("distance")
                                time_seconds = target_res.get("time")

                                if dist_meters is not None and time_seconds is not None:
                                    dist_km = round(dist_meters / 1000.0, 1)
                                    eta_min = max(1, int(round(time_seconds / 60.0)))
                                    self._apply_route_to_item(item, dist_km, eta_min)

                                    name = getattr(item, "name", "Destination")
                                    print(f"\n========== ROUTE DEBUG (Geoapify) ==========")
                                    print(f"Origin: ({origin_lat:.5f}, {origin_lon:.5f}) -> {name} ({item.latitude:.5f}, {item.longitude:.5f})")
                                    print(f"Distance: {dist_km} km | Duration: {eta_min} min")
                                    print(f"============================================\n")

                        return True
                else:
                    logger.warning(f"[GoogleRoutes] Geoapify Route Matrix returned status {res.status_code}: {res.text[:200]}")
        except Exception as e:
            logger.error(f"[GoogleRoutes] Geoapify Route Matrix exception: {e}")

        return False

    async def _compute_via_google(
        self,
        origin_lat: float,
        origin_lon: float,
        items_to_route: List[Any],
        google_key: str,
    ) -> bool:
        """Calculate road distances and driving durations via Google Routes API v2."""
        if not google_key or not items_to_route:
            return False

        headers = {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": google_key,
            "X-Goog-FieldMask": "originIndex,destinationIndex,status,distanceMeters,duration,condition",
        }

        payload = {
            "origins": [
                {
                    "waypoint": {
                        "location": {
                            "latLng": {
                                "latitude": origin_lat,
                                "longitude": origin_lon,
                            }
                        }
                    }
                }
            ],
            "destinations": [
                {
                    "waypoint": {
                        "location": {
                            "latLng": {
                                "latitude": s.latitude,
                                "longitude": s.longitude,
                            }
                        }
                    }
                }
                for s in items_to_route
            ],
            "travelMode": "DRIVE",
            "routingPreference": "TRAFFIC_AWARE",
        }

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                res = await client.post(
                    settings.GOOGLE_ROUTES_MATRIX_URL,
                    headers=headers,
                    json=payload,
                )

                if res.status_code == 200:
                    results = res.json()
                    if isinstance(results, list):
                        for el in results:
                            dest_idx = el.get("destinationIndex")
                            if dest_idx is not None and dest_idx < len(items_to_route):
                                item = items_to_route[dest_idx]
                                meters = el.get("distanceMeters")
                                duration_str = el.get("duration")

                                if meters is not None and duration_str is not None:
                                    dur_sec = self._parse_duration_seconds(duration_str) or 60
                                    dist_km = round(meters / 1000.0, 1)
                                    eta_min = max(1, int(round(dur_sec / 60.0)))
                                    self._apply_route_to_item(item, dist_km, eta_min)

                                    name = getattr(item, "name", "Destination")
                                    print(f"\n========== ROUTE DEBUG (Google Routes v2) ==========")
                                    print(f"Origin: ({origin_lat:.5f}, {origin_lon:.5f}) -> {name} ({item.latitude:.5f}, {item.longitude:.5f})")
                                    print(f"Distance: {dist_km} km | Duration: {eta_min} min")
                                    print(f"==================================================\n")

                        return True
                else:
                    logger.warning(f"[GoogleRoutes] Google Routes API returned status {res.status_code}: {res.text[:200]}")
        except Exception as e:
            logger.error(f"[GoogleRoutes] Google Routes API exception: {e}")

        return False

    async def compute_batch_driving_matrix(
        self,
        origin_lat: Optional[float],
        origin_lon: Optional[float],
        items: List[Any],
    ) -> List[Any]:
        """
        Batch compute real driving distance and driving duration from user's GPS origin
        to each item's destination coordinates using Google Routes API / Geoapify Matrix.
        Works across Hotels, Food, and Help facilities.
        """
        if not items:
            return []

        # Validate origin GPS
        if origin_lat is None or origin_lon is None or not is_valid_coordinates(origin_lat, origin_lon):
            logger.info("[GoogleRoutes] No valid user device GPS provided. Setting directions URL without origin.")
            for s in items:
                if hasattr(s, "directions_url"):
                    s.directions_url = self.generate_directions_url(None, None, s.latitude, s.longitude)
            return items

        origin_key = self._coord_key(origin_lat, origin_lon)
        now = time.time()

        # Check cache and identify uncached items
        uncached_items: List[Any] = []
        for item in items:
            if hasattr(item, "directions_url"):
                item.directions_url = self.generate_directions_url(origin_lat, origin_lon, item.latitude, item.longitude)
            dest_key = self._coord_key(item.latitude, item.longitude)
            cache_lookup = (origin_key, dest_key)

            if cache_lookup in self._cache:
                cached_time, dist_km, eta_min = self._cache[cache_lookup]
                if now - cached_time < self._cache_ttl_seconds:
                    self._apply_route_to_item(item, dist_km, eta_min)
                    continue

            uncached_items.append(item)

        if not uncached_items:
            return items

        # Attempt routing calculation (Google Routes first, Geoapify fallback)
        google_key = self._get_google_key()
        geoapify_key = self._get_geoapify_key()

        routed = False
        if google_key and not google_key.startswith("AQ."):
            routed = await self._compute_via_google(origin_lat, origin_lon, uncached_items[:25], google_key)

        if not routed and geoapify_key:
            routed = await self._compute_via_geoapify(origin_lat, origin_lon, uncached_items[:25], geoapify_key)

        # Update cache for successfully routed items
        for item in uncached_items:
            dist = getattr(item, "road_distance_km", None) or getattr(item, "distance_km", None) or getattr(item, "distanceKm", None)
            dur = getattr(item, "driving_duration_min", None) or getattr(item, "eta_minutes", None)
            if dist is not None and dur is not None:
                dest_key = self._coord_key(item.latitude, item.longitude)
                self._cache[(origin_key, dest_key)] = (
                    now,
                    float(dist),
                    int(dur),
                )

        return items

    # Backward-compatible alias for hotel stays
    async def compute_driving_matrix(
        self,
        origin_lat: Optional[float],
        origin_lon: Optional[float],
        stays: List[StayItem],
    ) -> List[StayItem]:
        return await self.compute_batch_driving_matrix(origin_lat, origin_lon, stays)

    async def compute_single_route(
        self,
        origin_lat: float,
        origin_lon: float,
        dest_lat: float,
        dest_lon: float,
        travel_mode: str = "DRIVE",
    ) -> Dict[str, Any]:
        """
        Single route calculation for POST /api/v1/routes endpoint.
        Returns distance_meters, duration_seconds, distance_km, eta_minutes, formatted strings.
        """
        origin_key = self._coord_key(origin_lat, origin_lon)
        dest_key = self._coord_key(dest_lat, dest_lon)
        cache_lookup = (origin_key, dest_key)
        now = time.time()

        directions_url = self.generate_directions_url(origin_lat, origin_lon, dest_lat, dest_lon)

        if cache_lookup in self._cache:
            cached_time, dist_km, eta_min = self._cache[cache_lookup]
            if now - cached_time < self._cache_ttl_seconds:
                return {
                    "distance_meters": int(dist_km * 1000),
                    "duration_seconds": int(eta_min * 60),
                    "distance_km": dist_km,
                    "eta_minutes": eta_min,
                    "formatted_distance": format_distance_string(dist_km),
                    "formatted_eta": format_eta_string(eta_min),
                    "directions_url": directions_url,
                }

        google_key = self._get_google_key()
        geoapify_key = self._get_geoapify_key()

        # 1. Try Google Routes API v2 computeRoutes
        if google_key and not google_key.startswith("AQ."):
            headers = {
                "Content-Type": "application/json",
                "X-Goog-Api-Key": google_key,
                "X-Goog-FieldMask": "routes.distanceMeters,routes.duration",
            }
            payload = {
                "origin": {"location": {"latLng": {"latitude": origin_lat, "longitude": origin_lon}}},
                "destination": {"location": {"latLng": {"latitude": dest_lat, "longitude": dest_lon}}},
                "travelMode": travel_mode.upper() if travel_mode else "DRIVE",
                "routingPreference": "TRAFFIC_AWARE",
            }
            try:
                async with httpx.AsyncClient(timeout=8.0) as client:
                    res = await client.post(
                        settings.GOOGLE_ROUTES_DIRECTIONS_URL,
                        headers=headers,
                        json=payload,
                    )
                    if res.status_code == 200:
                        data = res.json()
                        routes = data.get("routes", [])
                        if routes:
                            route = routes[0]
                            dist_meters = route.get("distanceMeters")
                            dur_str = route.get("duration")
                            dur_sec = self._parse_duration_seconds(dur_str)
                            if dist_meters is not None and dur_sec is not None:
                                dist_km = round(dist_meters / 1000.0, 1)
                                eta_min = max(1, int(round(dur_sec / 60.0)))
                                self._cache[cache_lookup] = (now, dist_km, eta_min)
                                return {
                                    "distance_meters": dist_meters,
                                    "duration_seconds": dur_sec,
                                    "distance_km": dist_km,
                                    "eta_minutes": eta_min,
                                    "formatted_distance": format_distance_string(dist_km),
                                    "formatted_eta": format_eta_string(eta_min),
                                    "directions_url": directions_url,
                                }
            except Exception as e:
                logger.warning(f"[GoogleRoutes] computeRoutes API error: {e}")

        # 2. Try Geoapify Routing API fallback
        if geoapify_key:
            url = f"https://api.geoapify.com/v1/routing?waypoints={origin_lat},{origin_lon}|{dest_lat},{dest_lon}&mode=drive&apiKey={geoapify_key}"
            try:
                async with httpx.AsyncClient(timeout=8.0) as client:
                    res = await client.get(url)
                    if res.status_code == 200:
                        data = res.json()
                        features = data.get("features", [])
                        if features:
                            props = features[0].get("properties", {})
                            dist_meters = props.get("distance")
                            time_seconds = props.get("time")
                            if dist_meters is not None and time_seconds is not None:
                                dist_km = round(dist_meters / 1000.0, 1)
                                eta_min = max(1, int(round(time_seconds / 60.0)))
                                self._cache[cache_lookup] = (now, dist_km, eta_min)
                                return {
                                    "distance_meters": int(dist_meters),
                                    "duration_seconds": int(time_seconds),
                                    "distance_km": dist_km,
                                    "eta_minutes": eta_min,
                                    "formatted_distance": format_distance_string(dist_km),
                                    "formatted_eta": format_eta_string(eta_min),
                                    "directions_url": directions_url,
                                }
            except Exception as e:
                logger.warning(f"[GoogleRoutes] Geoapify routing error: {e}")

        # Fallback if both APIs failed
        return {
            "distance_meters": None,
            "duration_seconds": None,
            "distance_km": None,
            "eta_minutes": None,
            "formatted_distance": None,
            "formatted_eta": None,
            "directions_url": directions_url,
        }


google_routes_service = GoogleRoutesService()
