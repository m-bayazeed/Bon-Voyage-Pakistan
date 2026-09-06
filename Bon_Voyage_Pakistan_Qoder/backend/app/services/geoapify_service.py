import logging
import math
from typing import Any, Dict, List, Optional, Tuple
import httpx
from app.core.config import settings
from app.models.hotel import StayItem

logger = logging.getLogger(__name__)


def haversine_distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate the great circle distance between two points on earth in kilometers."""
    earth_radius_km = 6371.0
    d_lat = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)
    a = (
        math.sin(d_lat / 2.0) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(d_lon / 2.0) ** 2
    )
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return round(earth_radius_km * c, 2)


def classify_stay_category(
    name: str,
    categories: List[str],
    tags: Optional[Dict[str, Any]] = None,
    city: Optional[str] = None,
    lat: Optional[float] = None,
    lon: Optional[float] = None,
    address: Optional[str] = None,
) -> Tuple[str, str]:
    """
    Categorize a real place into one of the 5 project categories:
    luxury, resort, boutique, budget, glamping
    Returns (category_key, badge_label).
    Geographically and contextually aware: strictly prevents 'Mountain Resort'
    in non-mountainous plains and coastal cities like Multan and Karachi.
    """
    name_lower = name.lower().strip()
    cat_str = " ".join(categories).lower()
    tags_str = str(tags or {}).lower()
    c = (city or "").lower().strip()
    a = (address or "").lower().strip()
    combined = f"{name_lower} {cat_str} {tags_str} {c} {a}"

    # ── 1. GEOGRAPHICAL TERRAIN CONTEXT ──
    is_coastal = (
        any(k in c for k in ["karachi", "gwadar", "ormara", "pasni", "manora"])
        or (lat is not None and lat < 26.0)
        or any(k in a for k in ["karachi", "clifton", "sea view", "beach", "creek", "port qasim", "hawksbay", "sandspit"])
    )

    is_mountain = (
        any(k in c for k in [
            "hunza", "karimabad", "passu", "skardu", "gilgit", "swat", "kalam",
            "malam jabba", "murree", "bhurban", "galyat", "galiyat", "nathia",
            "ayubia", "naran", "kaghan", "chitral", "abbottabad", "ziarat"
        ])
        or (lat is not None and lat > 34.2)
        or (lat is not None and lon is not None and lat > 33.84 and lon > 73.26)
    )

    is_islamabad = "islamabad" in c or "rawalpindi" in c
    is_margalla_hills = is_islamabad and (
        any(k in combined for k in ["pir sohawa", "margalla", "highland", "whispering pines", "sangada"])
        or (lat is not None and lat > 33.78 and lon is not None and lon > 73.10)
    )

    # ── 2. BRAND & CHAIN NORMALIZATION ──
    is_hotel_one = "hotel one" in name_lower
    is_luxury_brand = any(
        w in name_lower for w in [
            "serena", "marriott", "pearl continental", "pearl-continental",
            "pc hotel", "mvenpick", "movenpick", "nishat", "avari",
            "faletti", "best western premier", "best western plus",
            "wyndham grand", "ramada", "intercontinental", "radisson",
            "kempinski", "sheraton", "four seasons"
        ]
    )

    # ── 3. Campsite / Glamping ──
    glamping_keywords = [
        "camping", "camp_site", "glamping", "campsite", "camp", "dome",
        "tent", "pod", "caravan", "huts", "hut", "bivouac"
    ]
    if any(k in combined for k in glamping_keywords) or "camping" in cat_str or "accommodation.hut" in cat_str:
        if is_coastal:
            return "glamping", "Beach Glamping"
        elif is_mountain:
            if "dome" in name_lower or "stargaz" in name_lower:
                return "glamping", "Stargazing Domes"
            return "glamping", "Alpine Glamping"
        elif is_islamabad:
            return "glamping", "Margalla Glamping Pods"
        return "glamping", "Campsite / Glamping"

    # ── 4. Hotel One Chain Override ──
    if is_hotel_one:
        return "budget", "Business Comfort Stay"

    # ── 5. Resorts & Retreats ──
    is_resort = (
        "accommodation.resort" in cat_str
        or any(w in name_lower for w in ["resort", "retreat", "country club", "golf club", "golf resort", "ski resort", "beach resort"])
    )

    if is_resort:
        if is_coastal:
            if any(w in name_lower for w in ["beach", "sea", "ocean", "turtle", "hawksbay", "french", "sandspit"]):
                return "resort", "Beach Resort"
            elif any(w in name_lower for w in ["waterfront", "creek", "marina", "port"]):
                return "resort", "Waterfront Resort"
            elif any(w in name_lower for w in ["golf", "club", "dreamworld"]):
                return "resort", "Golf & Country Club"
            return "resort", "Coastal Resort"

        elif is_mountain:
            if "ski" in name_lower or "malam jabba" in name_lower or "malam" in name_lower:
                return "resort", "Alpine Ski Resort"
            elif "lake" in name_lower or "attabad" in name_lower or "shangrila" in name_lower or "kachura" in name_lower:
                return "resort", "Lakeside Resort"
            elif "pine" in name_lower or "forest" in name_lower or "woods" in name_lower:
                return "resort", "Pine Forest Resort"
            elif "valley" in name_lower or "river" in name_lower or "heights" in name_lower:
                return "resort", "Valley View Resort"
            return "resort", "Mountain Resort"

        elif is_islamabad:
            if is_margalla_hills:
                return "resort", "Margalla Hill Resort"
            return "resort", "City Resort & Spa"

        else:
            # Plains (Multan, Lahore, Faisalabad, Bahawalpur, etc.)
            if "golf" in name_lower or "rumanza" in name_lower:
                return "resort", "Golf & Country Resort"
            elif "heritage" in name_lower:
                return "resort", "Heritage Resort"
            elif any(w in name_lower for w in ["oasis", "garden", "farm", "lake"]):
                return "resort", "Garden & Oasis Resort"
            return "resort", "City Resort & Spa"

    # ── 6. 5-Star Luxury ──
    if is_luxury_brand or "stars:5" in tags_str or any(w in name_lower for w in ["5 star", "5-star", "luxury", "grand hotel", "palace", "royal"]):
        if is_mountain:
            if any(w in name_lower for w in ["fort", "palace", "serena shigar", "khaplu"]):
                return "luxury", "Heritage Royal Palace"
            return "luxury", "5-Star Mountain Luxury"
        elif is_coastal:
            return "luxury", "5-Star Luxury"
        elif is_islamabad:
            return "luxury", "5-Star Luxury"
        elif any(w in name_lower for w in ["faletti", "heritage"]):
            return "luxury", "Grand Heritage Luxury"
        elif "4 star" in name_lower or "4-star" in name_lower or "ramada" in name_lower or "best western" in name_lower:
            return "luxury", "4-Star Luxury"
        return "luxury", "5-Star Luxury"

    # ── 7. Boutique & Lodge ──
    boutique_keywords = [
        "boutique", "lodge", "inn", "villas", "villa", "cottage",
        "heritage", "fort", "manor", "haven", "retreat", "residence",
        "club", "house", "residency", "castle", "mansion", "suites"
    ]
    if any(k in combined for k in boutique_keywords) or "accommodation.lodge" in cat_str or "accommodation.apartment" in cat_str or "stars:4" in tags_str:
        if is_mountain:
            if any(w in name_lower for w in ["chalet", "cabin"]):
                return "boutique", "Alpine Chalet"
            elif "lodge" in name_lower:
                return "boutique", "Mountain Lodge"
            return "boutique", "Alpine Boutique"
        elif is_coastal:
            return "boutique", "City Boutique"
        elif is_islamabad:
            return "boutique", "Executive Boutique"
        else:
            if any(w in name_lower for w in ["heritage", "haveli", "colonial"]):
                return "boutique", "Heritage Stay"
            return "boutique", "Boutique & Suites"

    # ── 8. Guest House / Budget ──
    budget_keywords = [
        "guest house", "guesthouse", "hostel", "motel", "budget",
        "dorm", "dormitory", "backpackers", "rooms", "homestay",
        "yha", "rest house", "inn", "hotel", "travelers", "stop"
    ]
    if any(k in combined for k in budget_keywords) or "accommodation.guest_house" in cat_str or "accommodation.hostel" in cat_str or "accommodation.motel" in cat_str:
        if is_mountain:
            if any(w in name_lower for w in ["hostel", "backpacker", "trekker"]):
                return "budget", "Trekker Hostel"
            return "budget", "Alpine Guest House"
        elif is_coastal:
            return "budget", "City Center Stay"
        elif is_islamabad:
            return "budget", "Capital Guest House"
        else:
            if any(w in name_lower for w in ["guest house", "guesthouse"]):
                return "budget", "Guest House"
            return "budget", "Comfort Budget Stay"

    if is_mountain:
        return "budget", "Alpine Stay"
    elif is_coastal:
        return "budget", "Coastal Stay"
    return "budget", "Hotel & Stay"


class GeoapifyService:
    """Geoapify Places, Geocoding, and Routing Matrix Client."""

    def __init__(self):
        self._places_url = settings.GEOAPIFY_PLACES_URL
        self._geocode_url = settings.GEOAPIFY_GEOCODE_URL
        self._routematrix_url = "https://api.geoapify.com/v1/routematrix"

    async def search_nearby_stays(
        self,
        latitude: float,
        longitude: float,
        radius_km: float = 40.0,
        limit: int = 100,
        origin_lat: Optional[float] = None,
        origin_lon: Optional[float] = None,
    ) -> List[StayItem]:
        """
        Query Geoapify Places API for all accommodation types around (latitude, longitude).
        Returns deduplicated raw StayItem list with real coordinates and initial distances.
        """
        api_key = settings.GEOAPIFY_API_KEY
        if not api_key:
            logger.warning("GEOAPIFY_API_KEY is not configured.")
            return []

        radius_meters = int(min(max(radius_km, 1.0), settings.MAX_SEARCH_RADIUS_KM) * 1000)
        categories_param = ",".join(settings.GEOAPIFY_ACCOMMODATION_CATEGORIES)

        params = {
            "categories": categories_param,
            "filter": f"circle:{longitude},{latitude},{radius_meters}",
            "bias": f"proximity:{longitude},{latitude}",
            "limit": limit,
            "apiKey": api_key,
        }

        try:
            async with httpx.AsyncClient(timeout=12.0) as client:
                response = await client.get(self._places_url, params=params)

                if response.status_code != 200:
                    logger.warning(
                        f"Geoapify Places API responded with status {response.status_code}: {response.text[:200]}"
                    )
                    return []

                data = response.json()
                features = data.get("features", [])

                stays: List[StayItem] = []
                seen_keys = set()

                calc_origin_lat = origin_lat if origin_lat is not None else latitude
                calc_origin_lon = origin_lon if origin_lon is not None else longitude

                for feat in features:
                    props = feat.get("properties", {})
                    geometry = feat.get("geometry", {})
                    coords = geometry.get("coordinates", [])

                    p_lon = props.get("lon") or (coords[0] if len(coords) >= 2 else None)
                    p_lat = props.get("lat") or (coords[1] if len(coords) >= 2 else None)

                    if p_lat is None or p_lon is None:
                        continue

                    name = (
                        props.get("name")
                        or props.get("address_line1")
                        or props.get("formatted")
                        or "Accommodation Stay"
                    ).strip()

                    # Deduplicate using place_id or coordinate rounded key
                    place_id = props.get("place_id") or f"geo_{p_lat:.4f}_{p_lon:.4f}_{name}"
                    dedup_key = f"{round(p_lat, 4)}_{round(p_lon, 4)}_{name.lower()}"
                    if dedup_key in seen_keys or place_id in seen_keys:
                        continue
                    seen_keys.add(dedup_key)
                    seen_keys.add(place_id)

                    formatted_address = (
                        props.get("formatted")
                        or f"{props.get('address_line1', '')}, {props.get('address_line2', '')}".strip(" ,")
                        or f"Near {latitude:.3f}, {longitude:.3f}"
                    )
                    city = props.get("city") or props.get("suburb") or props.get("district") or props.get("state") or "Pakistan"
                    country = props.get("country") or "Pakistan"

                    categories = props.get("categories", [])
                    contact = props.get("contact", {})
                    phone = (
                        props.get("datasource", {}).get("raw", {}).get("phone")
                        or contact.get("phone")
                        or props.get("phone")
                    )
                    website = (
                        props.get("website")
                        or props.get("datasource", {}).get("raw", {}).get("website")
                        or contact.get("website")
                    )
                    opening_hours = (
                        props.get("opening_hours")
                        or props.get("datasource", {}).get("raw", {}).get("opening_hours")
                    )

                    dist_km = haversine_distance_km(calc_origin_lat, calc_origin_lon, p_lat, p_lon)
                    directions_url = f"https://www.google.com/maps/dir/?api=1&origin={calc_origin_lat},{calc_origin_lon}&destination={p_lat},{p_lon}&travelmode=driving"

                    raw_tags = props.get("datasource", {}).get("raw", {})
                    cat_key, badge_label = classify_stay_category(
                        name=name,
                        categories=categories,
                        tags=raw_tags,
                        city=city,
                        lat=p_lat,
                        lon=p_lon,
                        address=formatted_address,
                    )

                    osm_stars = raw_tags.get("stars")
                    rating = None
                    if osm_stars:
                        try:
                            rating = float(osm_stars)
                        except ValueError:
                            pass

                    phone_val = str(phone).strip() if phone is not None and str(phone).strip() else None
                    website_val = str(website).strip() if website is not None and str(website).strip() else None
                    hours_val = str(opening_hours).strip() if opening_hours is not None and str(opening_hours).strip() else None

                    item = StayItem(
                        id=place_id,
                        name=name,
                        category=cat_key,
                        badge_label=badge_label,
                        description=None,
                        latitude=p_lat,
                        longitude=p_lon,
                        distance_km=dist_km,
                        road_distance_km=None,
                        driving_duration_min=None,
                        formatted_distance=f"{dist_km} km away",
                        address=formatted_address,
                        city=city,
                        country=country,
                        image_url=None,
                        rating=rating,
                        reviews_count=None,
                        price_per_night_pkr=None,
                        website=website_val,
                        phone=phone_val,
                        opening_hours=hours_val,
                        amenities=[],
                        highlight=None,
                        directions_url=directions_url,
                    )
                    stays.append(item)

                return stays

        except httpx.TimeoutException:
            logger.warning("Geoapify Places API request timed out after 12s.")
            return []
        except Exception as e:
            logger.error(f"Error fetching stays from Geoapify: {e}", exc_info=True)
            return []

    async def compute_route_matrix(
        self,
        origin_lat: float,
        origin_lon: float,
        stays: List[StayItem],
    ) -> List[StayItem]:
        """
        Compute real road distance and driving ETA from user's current GPS position
        to each hotel destination using Geoapify Route Matrix API.
        """
        api_key = settings.GEOAPIFY_API_KEY
        if not api_key or not stays:
            return stays

        targets = [{"location": [s.longitude, s.latitude]} for s in stays]
        payload = {
            "mode": "drive",
            "sources": [{"location": [origin_lon, origin_lat]}],
            "targets": targets,
        }

        try:
            async with httpx.AsyncClient(timeout=8.0) as client:
                response = await client.post(
                    self._routematrix_url,
                    params={"apiKey": api_key},
                    json=payload,
                )

                if response.status_code == 200:
                    data = response.json()
                    matrix = data.get("sources_to_targets", [])

                    if matrix and len(matrix) > 0:
                        row = matrix[0]
                        for idx, element in enumerate(row):
                            if idx < len(stays) and isinstance(element, dict):
                                stay = stays[idx]
                                dist_meters = element.get("distance")
                                time_sec = element.get("time")

                                if dist_meters is not None:
                                    road_km = round(dist_meters / 1000.0, 1)
                                    stay.road_distance_km = road_km

                                    if time_sec is not None:
                                        dur_min = max(1, round(time_sec / 60.0))
                                        stay.driving_duration_min = dur_min
                                        stay.formatted_distance = f"{road_km} km • ~{dur_min} min"
                                    else:
                                        stay.formatted_distance = f"{road_km} km away"

                                    stay.directions_url = f"https://www.google.com/maps/dir/?api=1&origin={origin_lat},{origin_lon}&destination={stay.latitude},{stay.longitude}&travelmode=driving"

                                    # Routing Debug Log
                                    print("\n========== ROUTING DEBUG ==========")
                                    print(f"Origin: {origin_lat:.4f}, {origin_lon:.4f}")
                                    print(f"Hotel: {stay.name}")
                                    print(f"Destination: {stay.latitude:.4f}, {stay.longitude:.4f}")
                                    print(f"Road Distance: {stay.road_distance_km} km")
                                    print(f"ETA: {stay.driving_duration_min} min")
                                    print("===================================\n")
                else:
                    logger.warning(f"Geoapify Route Matrix returned status {response.status_code}: {response.text[:200]}")
        except Exception as e:
            logger.warning(f"Geoapify Route Matrix error: {e}. Retaining straight-line distance.")

        return stays

    async def geocode_location(self, query: str) -> List[Dict[str, Any]]:
        """
        Geocode a location query in Pakistan using Geoapify Geocoding API.
        """
        api_key = settings.GEOAPIFY_API_KEY
        if not api_key or not query.strip():
            return []

        params = {
            "text": query.strip(),
            "filter": "countrycode:pk",
            "limit": 5,
            "apiKey": api_key,
        }

        try:
            async with httpx.AsyncClient(timeout=8.0) as client:
                response = await client.get(self._geocode_url, params=params)
                if response.status_code != 200:
                    return []

                data = response.json()
                features = data.get("features", [])
                results = []

                for feat in features:
                    props = feat.get("properties", {})
                    lat = props.get("lat")
                    lon = props.get("lon")
                    if lat is not None and lon is not None:
                        results.append({
                            "name": props.get("name") or props.get("city") or query,
                            "formatted_address": props.get("formatted") or props.get("address_line1") or query,
                            "latitude": float(lat),
                            "longitude": float(lon),
                            "city": props.get("city") or props.get("state") or "Pakistan",
                        })
                return results
        except Exception as e:
            logger.error(f"Error geocoding location '{query}': {e}")
            return []

    async def fetch_map_tile(
        self,
        style: str,
        z: int,
        x: int,
        y: int,
    ) -> Optional[bytes]:
        """
        Fetch official Geoapify map tile using backend API key.
        Supports styles: osm-bright, osm-bright-smooth, dark-matter, positron, etc.
        """
        api_key = settings.GEOAPIFY_API_KEY
        if not api_key:
            return None

        # Sanitize style name
        safe_style = style.lower().strip()
        allowed_styles = {
            "osm-bright", "osm-bright-smooth", "osm-bright-grey",
            "dark-matter", "dark-matter-purple-roads",
            "dark-matter-yellow-roads", "positron", "positron-blue",
            "positron-red", "klokantech-basic", "osm-liberty", "toner"
        }
        if safe_style not in allowed_styles:
            safe_style = "osm-bright"

        tile_url = f"https://maps.geoapify.com/v1/tile/{safe_style}/{z}/{x}/{y}.png"

        try:
            async with httpx.AsyncClient(timeout=8.0) as client:
                response = await client.get(tile_url, params={"apiKey": api_key})
                if response.status_code == 200:
                    return response.content
                else:
                    logger.warning(f"Geoapify tile fetch ({safe_style}/{z}/{x}/{y}) failed with status {response.status_code}")
                    return None
        except Exception as e:
            logger.warning(f"Error fetching Geoapify tile: {e}")
            return None


geoapify_service = GeoapifyService()
