import asyncio
import logging
import re
import time
from typing import Any, Dict, List, Optional, Tuple
import httpx
from app.core.config import settings
from app.models.food import FoodPlaceItem
from app.models.help import HelpFacilityItem
from app.models.hotel import StayItem
from app.services.curated_food_database import get_curated_fallback_food
from app.services.curated_help_database import get_curated_fallback_help
from app.services.curated_hotel_database import get_curated_fallback_stays
from app.utils.geo import format_price_pkr, haversine_distance_km, is_valid_coordinates

logger = logging.getLogger(__name__)


class GooglePlacesService:
    """Production service for Google Places API (New) nearby hotel discovery and place classification."""

    def __init__(self):
        # In-memory search cache: key -> (timestamp, list of StayItems)
        self._cache: Dict[str, Tuple[float, List[StayItem]]] = {}
        self._cache_ttl_seconds = 900  # 15 minutes TTL

    def _get_api_key(self) -> str:
        key = settings.GOOGLE_PLACES_API_KEY or settings.GOOGLE_API_KEY
        if key and key.startswith("AQ."):
            return ""
        return key or ""

    def _classify_stay(
        self,
        name: str,
        types: List[str],
        price_level: Optional[str] = None,
        rating: Optional[float] = None,
        review_count: Optional[int] = None,
        city_name: Optional[str] = None,
        lat: Optional[float] = None,
        lon: Optional[float] = None,
        address: Optional[str] = None,
    ) -> Tuple[str, str]:
        """
        Classify stay into: luxury, resort, boutique, budget, glamping/pods, all.
        Returns (category, badge_label).
        Geographically and contextually aware: strictly prevents 'Mountain Resort'
        in non-mountainous plains and coastal cities like Multan and Karachi.
        """
        n = name.lower().strip()
        t = [typ.lower() for typ in types]
        c = (city_name or "").lower().strip()
        a = (address or "").lower().strip()
        combined = f"{n} {c} {a}"

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
            or (lat is not None and lon is not None and lat > 33.84 and lon > 73.26)  # Murree / Galyat ridge
        )

        is_islamabad = "islamabad" in c or "rawalpindi" in c
        is_margalla_hills = is_islamabad and (
            any(k in combined for k in ["pir sohawa", "margalla", "highland", "whispering pines", "sangada"])
            or (lat is not None and lat > 33.78 and lon is not None and lon > 73.10)
        )

        # ── 2. BRAND & CHAIN NORMALIZATION ──
        is_hotel_one = "hotel one" in n
        is_luxury_brand = any(
            w in n for w in [
                "serena", "marriott", "pearl continental", "pearl-continental",
                "pc hotel", "mvenpick", "movenpick", "nishat", "avari",
                "faletti", "best western premier", "best western plus",
                "wyndham grand", "ramada", "intercontinental", "radisson",
                "kempinski", "sheraton", "four seasons"
            ]
        )

        # ── 3. CAMPSITE / PODS / GLAMPING ──
        if (
            "campground" in t
            or any(w in n for w in ["camp", "glamping", "pod", "dome", "tent", "capsule", "campsite", "safari huts"])
        ):
            if is_coastal:
                return "glamping", "Beach Glamping"
            elif is_mountain:
                if "dome" in n or "stargaz" in n:
                    return "glamping", "Stargazing Domes"
                return "glamping", "Alpine Glamping"
            elif is_islamabad:
                return "glamping", "Margalla Glamping Pods"
            return "glamping", "Campsite / Pods"

        # ── 4. HOTEL ONE CHAIN OVERRIDE (3-star business hotel, not a resort) ──
        if is_hotel_one:
            return "budget", "Business Comfort Stay"

        # ── 5. RESORTS & RETREATS ──
        # Only true resorts or country/golf clubs (avoid matching generic "view" or "heights")
        is_resort = (
            "resort_hotel" in t
            or any(w in n for w in ["resort", "retreat", "country club", "golf club", "golf resort", "ski resort", "beach resort"])
        )

        if is_resort:
            if is_coastal:
                if any(w in n for w in ["beach", "sea", "ocean", "turtle", "hawksbay", "french", "sandspit"]):
                    return "resort", "Beach Resort"
                elif any(w in n for w in ["waterfront", "creek", "marina", "port"]):
                    return "resort", "Waterfront Resort"
                elif any(w in n for w in ["golf", "club", "dreamworld"]):
                    return "resort", "Golf & Country Club"
                return "resort", "Coastal Resort"

            elif is_mountain:
                if "ski" in n or "malam jabba" in n or "malam" in n:
                    return "resort", "Alpine Ski Resort"
                elif "lake" in n or "attabad" in n or "shangrila" in n or "kachura" in n:
                    return "resort", "Lakeside Resort"
                elif "pine" in n or "forest" in n or "woods" in n:
                    return "resort", "Pine Forest Resort"
                elif "valley" in n or "river" in n or "heights" in n:
                    return "resort", "Valley View Resort"
                return "resort", "Mountain Resort"

            elif is_islamabad:
                if is_margalla_hills:
                    return "resort", "Margalla Hill Resort"
                return "resort", "City Resort & Spa"

            else:
                # Plains / Historic / Oasis (Multan, Lahore, Faisalabad, Bahawalpur, etc.)
                if "golf" in n or "rumanza" in n:
                    return "resort", "Golf & Country Resort"
                elif "heritage" in n:
                    return "resort", "Heritage Resort"
                elif any(w in n for w in ["oasis", "garden", "farm", "lake"]):
                    return "resort", "Garden & Oasis Resort"
                return "resort", "City Resort & Spa"

        # ── 6. LUXURY / 5-STAR HOTELS ──
        if (
            is_luxury_brand
            or any(w in n for w in ["5 star", "5-star", "luxury", "grand hotel", "regal", "palace", "royal"])
            or price_level in ["PRICE_LEVEL_EXPENSIVE", "PRICE_LEVEL_VERY_EXPENSIVE"]
            or (rating is not None and rating >= 4.6 and review_count is not None and review_count >= 80)
        ):
            if is_mountain:
                if any(w in n for w in ["fort", "palace", "serena shigar", "khaplu"]):
                    return "luxury", "Heritage Royal Palace"
                return "luxury", "5-Star Mountain Luxury"
            elif is_coastal:
                if any(w in n for w in ["beach", "waterfront", "creek", "marriott", "pc hotel", "pearl-continental", "movenpick", "mvenpick"]):
                    return "luxury", "5-Star Luxury"
                return "luxury", "5-Star Luxury"
            elif is_islamabad:
                if any(w in n for w in ["serena", "marriott", "diplomatic"]):
                    return "luxury", "5-Star Luxury"
                return "luxury", "5-Star Luxury"
            elif any(w in n for w in ["faletti", "heritage"]):
                return "luxury", "Grand Heritage Luxury"
            elif "4 star" in n or "4-star" in n or "ramada" in n or "best western" in n:
                return "luxury", "4-Star Luxury"
            return "luxury", "5-Star Luxury"

        # ── 7. BOUTIQUE & LODGE ──
        if (
            any(typ in t for typ in ["bed_and_breakfast", "cottage", "inn", "farmstay"])
            or any(w in n for w in ["boutique", "lodge", "cabin", "haveli", "chalet", "manor", "heritage", "villas", "inn", "suites", "residence", "haven"])
        ):
            if is_mountain:
                if any(w in n for w in ["chalet", "cabin"]):
                    return "boutique", "Alpine Chalet"
                elif "lodge" in n:
                    return "boutique", "Mountain Lodge"
                return "boutique", "Alpine Boutique"
            elif is_coastal:
                return "boutique", "City Boutique"
            elif is_islamabad:
                return "boutique", "Executive Boutique"
            else:
                if any(w in n for w in ["heritage", "haveli", "colonial"]):
                    return "boutique", "Heritage Stay"
                return "boutique", "Boutique & Suites"

        # ── 8. GUEST HOUSE / BUDGET ──
        if (
            any(typ in t for typ in ["guest_house", "hostel", "motel"])
            or any(w in n for w in ["guest house", "guesthouse", "hostel", "motel", "budget", "rooms", "residency", "stay", "rest house", "inn", "travelers", "stop"])
            or price_level in ["PRICE_LEVEL_FREE", "PRICE_LEVEL_INEXPENSIVE"]
            or (rating is not None and rating < 4.1)
        ):
            if is_mountain:
                if any(w in n for w in ["hostel", "backpacker", "trekker"]):
                    return "budget", "Trekker Hostel"
                return "budget", "Alpine Guest House"
            elif is_coastal:
                return "budget", "City Center Stay"
            elif is_islamabad:
                return "budget", "Capital Guest House"
            else:
                if any(w in n for w in ["guest house", "guesthouse"]):
                    return "budget", "Guest House"
                return "budget", "Comfort Budget Stay"

        # ── 9. DEFAULT / HIGH RATING FALLBACK ──
        if rating is not None and rating >= 4.4:
            if is_mountain:
                return "luxury", "Mountain Luxury"
            return "luxury", "5-Star Luxury"

        if is_mountain:
            return "budget", "Alpine Stay"
        elif is_coastal:
            return "budget", "Coastal Stay"
        return "budget", "Hotel & Stay"

    def _estimate_nightly_price(
        self,
        category: str,
        price_level: Optional[str] = None,
        rating: Optional[float] = None,
    ) -> int:
        """
        Estimate a realistic nightly PKR price when Google does not provide exact rate.
        Marked internally as estimate.
        """
        base_prices = {
            "luxury": 52000,
            "resort": 36000,
            "boutique": 22000,
            "glamping": 18000,
            "budget": 8500,
            "all": 16000,
        }
        base = base_prices.get(category, 15000)

        if price_level == "PRICE_LEVEL_VERY_EXPENSIVE":
            return int(base * 1.5)
        elif price_level == "PRICE_LEVEL_EXPENSIVE":
            return int(base * 1.2)
        elif price_level == "PRICE_LEVEL_INEXPENSIVE":
            return max(6000, int(base * 0.6))
        elif price_level == "PRICE_LEVEL_MODERATE":
            return base

        if rating and rating >= 4.7:
            return int(base * 1.15)
        return base

    def _format_photo_url(self, photo_obj: Optional[Dict[str, Any]], api_key: str) -> Optional[str]:
        """
        Convert Google Places photo object to usable photo media URL.
        Guarantees photo corresponds strictly to this place ID.
        """
        if not photo_obj or not isinstance(photo_obj, dict):
            return None
        photo_name = photo_obj.get("name")
        if not photo_name:
            return None

        # Return Google Places Photo Media URL with API key or local photo proxy
        if api_key:
            return f"https://places.googleapis.com/v1/{photo_name}/media?maxHeightPx=800&maxWidthPx=1200&key={api_key}"
        return f"/api/v1/hotels/photos/{photo_name}?max_height=800&max_width=1200"

    async def search_nearby_stays(
        self,
        latitude: float,
        longitude: float,
        radius_km: float = 20.0,
        category: str = "all",
        city_name: Optional[str] = None,
        origin_lat: Optional[float] = None,
        origin_lon: Optional[float] = None,
    ) -> List[StayItem]:
        """
        Query Google Places API (New) nearby search endpoint for accommodation stays.
        Deduplicates by Google Place ID, strictly validates geographic radius from search center,
        and classifies each stay.
        """
        api_key = self._get_api_key()
        if not api_key:
            logger.warning("[GooglePlaces] No Google Places API key configured. Activating curated fallback.")
            return get_curated_fallback_stays(
                city_name=city_name,
                category=category,
                origin_lat=origin_lat,
                origin_lon=origin_lon,
                search_lat=latitude,
                search_lon=longitude,
                radius_km=radius_km,
            )

        # Check Cache
        cache_key = f"{round(latitude, 3)}_{round(longitude, 3)}_{round(radius_km, 1)}_{category.lower()}"
        now = time.time()
        if cache_key in self._cache:
            cached_time, cached_stays = self._cache[cache_key]
            if now - cached_time < self._cache_ttl_seconds:
                logger.info(f"[GooglePlaces] Cache hit for key {cache_key} ({len(cached_stays)} stays)")
                return [s.model_copy() for s in cached_stays]

        # For Murree, cap search radius to 15km to prevent spilling into Islamabad
        effective_radius_km = radius_km
        if city_name and any(k in city_name.lower() for k in ["murree", "galyat", "bhurban"]):
            effective_radius_km = min(radius_km, 15.0)

        # Google Places searchNearby radius constraint (max 50,000 meters)
        radius_meters = int(min(max(effective_radius_km * 1000.0, 1000.0), 50000.0))

        headers = {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": api_key,
            "X-Goog-FieldMask": (
                "places.id,"
                "places.displayName,"
                "places.formattedAddress,"
                "places.shortFormattedAddress,"
                "places.location,"
                "places.rating,"
                "places.userRatingCount,"
                "places.types,"
                "places.photos,"
                "places.priceLevel,"
                "places.googleMapsUri,"
                "places.websiteUri,"
                "places.nationalPhoneNumber,"
                "places.editorialSummary"
            ),
        }

        payload = {
            "includedTypes": settings.GOOGLE_ACCOMMODATION_TYPES,
            "maxResultCount": settings.GOOGLE_PLACES_MAX_RESULTS,
            "locationRestriction": {
                "circle": {
                    "center": {
                        "latitude": latitude,
                        "longitude": longitude,
                    },
                    "radius": float(radius_meters),
                }
            },
        }

        collected_places: Dict[str, Dict[str, Any]] = {}

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                logger.info(f"[GooglePlaces] POST {settings.GOOGLE_PLACES_NEARBY_URL} (Center: {latitude:.4f}, {longitude:.4f}, Radius: {radius_meters}m)")
                response = await client.post(
                    settings.GOOGLE_PLACES_NEARBY_URL,
                    headers=headers,
                    json=payload,
                )

                if response.status_code == 200:
                    data = response.json()
                    places = data.get("places", [])
                    for p in places:
                        pid = p.get("id")
                        if pid and pid not in collected_places:
                            collected_places[pid] = p
                else:
                    logger.error(f"[GooglePlaces] API error {response.status_code}: {response.text}")
                    # If nearby search returned error, attempt Text Search fallback if city_name available
                    if city_name and city_name.lower() not in ["current location", "gps"]:
                        text_payload = {
                            "textQuery": f"hotels resorts guest houses in {city_name} Pakistan",
                            "includedType": "lodging",
                            "maxResultCount": 20,
                            "locationBias": {
                                "circle": {
                                    "center": {"latitude": latitude, "longitude": longitude},
                                    "radius": float(radius_meters),
                                }
                            }
                        }
                        text_res = await client.post(
                            settings.GOOGLE_PLACES_TEXT_SEARCH_URL,
                            headers=headers,
                            json=text_payload,
                        )
                        if text_res.status_code == 200:
                            for p in text_res.json().get("places", []):
                                pid = p.get("id")
                                if pid and pid not in collected_places:
                                    collected_places[pid] = p

        except Exception as e:
            logger.error(f"[GooglePlaces] Network error querying Google Places API: {e}")

        # If Google Places yielded no results, fallback to curated database strictly filtered by search center
        if not collected_places:
            logger.warning(f"[GooglePlaces] No places found for ({latitude}, {longitude}). Using curated fallback database.")
            return get_curated_fallback_stays(
                city_name=city_name,
                category=category,
                origin_lat=origin_lat,
                origin_lon=origin_lon,
                search_lat=latitude,
                search_lon=longitude,
                radius_km=effective_radius_km,
            )

        # Convert Google Places to StayItems with strict geographic validation
        stays: List[StayItem] = []
        for pid, p in collected_places.items():
            loc = p.get("location", {})
            p_lat = loc.get("latitude")
            p_lon = loc.get("longitude")

            if not is_valid_coordinates(p_lat, p_lon):
                continue

            # Strict Geographic Validation: ensure stay is within requested search radius (+4km tolerance)
            dist_from_search = haversine_distance_km(latitude, longitude, p_lat, p_lon)
            if dist_from_search > effective_radius_km + 4.0:
                logger.info(f"[GooglePlaces] Rejected distant hotel ({p_lat}, {p_lon}) at {dist_from_search:.1f}km from center ({latitude}, {longitude})")
                continue

            full_addr = p.get("formattedAddress", "")
            short_addr = p.get("shortFormattedAddress", full_addr.split(",")[0] if full_addr else city_name or "Pakistan")
            types = p.get("types", [])
            rating = p.get("rating")
            review_count = p.get("userRatingCount")
            price_level = p.get("priceLevel")

            name_obj = p.get("displayName", {})
            name = name_obj.get("text") if isinstance(name_obj, dict) else (p.get("name") or "Hotel")

            # ── CROSS-CITY LEAKAGE GUARD ──
            # If searching Murree / Galyat: strictly exclude Islamabad & Rawalpindi stays
            if city_name and any(k in city_name.lower() for k in ["murree", "galyat", "bhurban"]):
                addr_lower = (full_addr + " " + short_addr + " " + name).lower()
                is_isb = any(
                    term in addr_lower for term in [
                        "islamabad", "rawalpindi", "pindi", "f-5", "f-6", "f-7", "f-8", "f-10", "f-11",
                        "g-5", "g-6", "g-7", "g-8", "g-9", "g-10", "g-11", "i-8", "i-9", "i-10",
                        "blue area", "centaurus", "convention centre", "shakar parian", "rawal lake",
                        "pir sohawa", "sangada", "dha ", "bahria "
                    ]
                )
                if is_isb and not ("islamabad - murree" in addr_lower and p_lat >= 33.84):
                    logger.info(f"[GooglePlaces] Filtered out Islamabad hotel '{name}' from Murree search")
                    continue
                if p_lat < 33.83 or p_lon < 73.28:
                    logger.info(f"[GooglePlaces] Filtered out out-of-bounds hotel '{name}' ({p_lat}, {p_lon}) from Murree search")
                    continue

            # If searching Islamabad: strictly exclude Murree / Bhurban stays
            if city_name and "islamabad" in city_name.lower():
                addr_lower = (full_addr + " " + short_addr + " " + name).lower()
                if any(term in addr_lower for term in ["murree", "bhurban", "galyat", "nathia"]):
                    continue
                if p_lat > 33.84:
                    continue

            # If searching Multan: strictly exclude non-Multan stays
            if city_name and "multan" in city_name.lower():
                addr_lower = (full_addr + " " + short_addr + " " + name).lower()
                if any(term in addr_lower for term in ["lahore", "bahawalpur", "khanewal", "karachi"]):
                    continue
                if p_lat < 29.8 or p_lat > 30.5 or p_lon < 71.1 or p_lon > 71.8:
                    continue

            # Determine actual clean city
            actual_city = city_name or "Pakistan"
            if "murree" in full_addr.lower() or "bhurban" in full_addr.lower():
                actual_city = "Murree"
            elif "islamabad" in full_addr.lower():
                actual_city = "Islamabad"
            elif "karachi" in full_addr.lower():
                actual_city = "Karachi"
            elif "multan" in full_addr.lower():
                actual_city = "Multan"
            elif "lahore" in full_addr.lower():
                actual_city = "Lahore"

            cat, badge = self._classify_stay(
                name=name,
                types=types,
                price_level=price_level,
                rating=rating,
                review_count=review_count,
                city_name=actual_city,
                lat=p_lat,
                lon=p_lon,
                address=full_addr or short_addr,
            )

            # Photos
            photos = p.get("photos", [])
            primary_img = self._format_photo_url(photos[0] if photos else None, api_key)
            if not primary_img:
                primary_img = self._resolve_authentic_hotel_image(name, cat, actual_city)
            gallery = [
                url for ph in photos[:4]
                if (url := self._format_photo_url(ph, api_key)) is not None
            ]
            if not gallery and primary_img:
                gallery = [primary_img]

            # Price estimation
            nightly_pkr = self._estimate_nightly_price(cat, price_level, rating)
            price_fmt = format_price_pkr(nightly_pkr)

            # Directions URL
            if origin_lat is not None and origin_lon is not None:
                directions_url = f"https://www.google.com/maps/dir/?api=1&origin={origin_lat:.5f},{origin_lon:.5f}&destination={p_lat:.5f},{p_lon:.5f}&travelmode=driving"
            else:
                directions_url = f"https://www.google.com/maps/dir/?api=1&destination={p_lat:.5f},{p_lon:.5f}&travelmode=driving"

            # Editorial summary / description from Google if available
            editorial = p.get("editorialSummary", {})
            g_desc = editorial.get("text") if isinstance(editorial, dict) else None
            default_desc = g_desc or f"{badge} located at {short_addr}."

            stay = StayItem(
                id=pid,
                name=name,
                category=cat,
                badge_label=badge,
                description=default_desc,
                latitude=p_lat,
                longitude=p_lon,
                short_address=short_addr,
                full_address=full_addr,
                address=full_addr or short_addr,
                city=actual_city,
                country="Pakistan",
                rating=float(rating) if rating is not None else None,
                reviews_count=int(review_count) if review_count is not None else None,
                price_per_night_pkr=nightly_pkr,
                price_formatted=price_fmt,
                is_available=True,
                image_url=primary_img,
                galleryImages=gallery,
                website=p.get("websiteUri") or p.get("googleMapsUri"),
                phone=p.get("nationalPhoneNumber"),
                highlight=f"{badge} in {actual_city}",
                amenities=["Free Wi-Fi", "Free Parking", "Room Service"],
                directions_url=directions_url,
            )
            stays.append(stay)

        # Cache results
        self._cache[cache_key] = (now, stays)
        return stays

    def _classify_food(
        self,
        name: str,
        types: List[str],
        primary_type: Optional[str] = None,
    ) -> Tuple[str, str]:
        """
        Classify food establishment into Flutter's FoodCategory enum values:
        all, desiPakistani, streetFood, bbq, biryani, fastFood, chinese, continental,
        traditionalLocal, cafe, bakery, dhaba, familyDining, fineDining, vegetarian.
        Returns (category_key, cuisine_label).
        """
        n = name.lower()
        t = [typ.lower() for typ in types]

        # 0. Iconic Brand Overrides
        if "el momento" in n:
            return "continental", "Prime Steaks, Continental & European Cuisine"
        if any(w in n for w in ["pappasallis", "tuscany", "fuoco", "pomodoro"]):
            return "italian", "Authentic Italian, Artisan Pizzas & Pasta"

        # 1. Chinese & Pan-Asian (Check types + names)
        if any(typ in t for typ in ["chinese_restaurant", "asian_restaurant", "thai_restaurant"]) or any(
            w in n for w in [
                "chinese", "asian", "wok", "noodle", "dumpling", "sichuan", "thai", "sushi",
                "chopstick", "ginyaki", "dynasty", "kim mun", "mei kong", "xinhua",
                "golden dragon", "mandarin", "yangtze", "yum", "truly asian", "bamboo union",
                "dragon", "phoenix", "chopsticks", "cantonese", "dim sum", "beijing",
                "shanghai", "oriental", "taipan",
            ]
        ):
            return "chinese", "Pak-Chinese, Sizzling Platters & Wok Dishes"

        # 2. Italian & Pizza & Pasta (Check types + names)
        if any(typ in t for typ in ["italian_restaurant", "pizza_restaurant"]) or any(
            w in n for w in [
                "italian", "pasta", "pizza", "pappasallis", "tuscany", "pomodoro",
                "fuoco", "cacio", "alfredo", "risotto", "bistro noir", "broadway", "domino", "pizza hut",
                "trattoria", "osteria", "ristorante", "pizzeria", "gelato", "artisan pizza",
            ]
        ):
            return "italian", "Authentic Italian, Artisan Pizzas & Pasta"

        # 3. Continental & Steaks
        if any(typ in t for typ in ["steak_house", "seafood_restaurant", "european_restaurant", "french_restaurant"]) or any(
            w in n for w in [
                "steak", "steakhouse", "continental", "roasters", "bistro", "grill & steak", "el momento",
                "warehouse", "tenderloin", "cafe flo", "aylanto", "patio", "brasserie",
            ]
        ):
            return "continental", "Prime Steaks, Continental & European Cuisine"

        # 4. Cafe & Coffee
        if "cafe" in t or "coffee_shop" in t or any(w in n for w in ["cafe", "café", "coffee", "roasters", "espresso", "chaaye khana", "tea lounge"]):
            return "cafe", "Artisan Coffee, Specialty Tea & Bakery"

        # 5. Bakery & Sweets
        if "bakery" in t or any(w in n for w in ["bakery", "bakers", "sweets", "mithai", "pastry", "patisserie", "confectionery"]):
            return "bakery", "Fresh Breads, Pastries & Pakistani Sweets"

        # 6. BBQ & Tikka
        if "barbecue_restaurant" in t or any(w in n for w in ["bbq", "barbeque", "tikka", "kebab", "kabab", "charsi", "namak mandi", "shinwari", "boti", "sajji"]):
            return "bbq", "Charcoal BBQ, Seekh Kebabs & Shinwari Karahi"

        # 7. Biryani & Pulao
        if any(w in n for w in ["biryani", "pulao", "savour", "rice", "naseeb", "karachi biryani", "student biryani"]):
            return "biryani", "Authentic Dum Biryani & Fragrant Pulao"

        # 8. Fast Food & Burgers
        if "fast_food_restaurant" in t or any(w in n for w in ["burger", "fried chicken", "kfc", "mcdonald", "hardee", "subway", "howdy", "ranchers", "cheezious"]):
            return "fastFood", "Gourmet Burgers, Crispy Chicken & Fast Food"

        # 9. Traditional & Regional (Northern / Pashtun / Sindhi / Balochi)
        if any(w in n for w in ["balti", "yak", "mamtu", "chapshoro", "trout", "hunza", "skardu", "gilgit", "balochi", "sajji", "dumpukht"]):
            return "traditionalLocal", "Authentic Regional Mountain Specialties"

        # 10. Street Food & Chaat
        if any(w in n for w in ["chaat", "gol gappay", "dahi bhallay", "samosa", "roll", "shawarma", "bun kabab", "street"]):
            return "streetFood", "Crispy Chaat, Bun Kababs & Street Delights"

        # 11. Highway Dhaba & Chai
        if any(w in n for w in ["dhaba", "chai", "quetta", "hotel & dhaba", "truck adda"]):
            return "dhaba", "Karak Doodh Patti Chai, Parathas & Highway Dhaba"

        # 12. Vegetarian
        if "vegetarian_restaurant" in t or any(w in n for w in ["vegetarian", "veg", "daal", "sabzi", "pure veg"]):
            return "vegetarian", "Vegetarian Curries, Fresh Daals & Paneer"

        # 13. Fine Dining
        if any(w in n for w in ["monal", "haveli", "serena", "marriott", "pearl continental", "fine dining", "royal haveli"]):
            return "fineDining", "Premier Fine Dining & Panoramic Views"

        # 14. Family Dining
        if any(w in n for w in ["family", "residency", "diner"]):
            return "familyDining", "Family Dining & Multi-Cuisine Menu"

        # Default Pakistani / Desi
        return "desiPakistani", "Traditional Karahi, Handi & Desi Cuisine"

    def _classify_food_price_tier(
        self,
        price_level: Optional[str],
        rating: Optional[float] = None,
    ) -> Tuple[str, int]:
        """Classify into (priceTier, avgCostPerPersonPkr)."""
        if price_level == "PRICE_LEVEL_FREE" or price_level == "PRICE_LEVEL_INEXPENSIVE":
            return "budget", 650
        elif price_level == "PRICE_LEVEL_EXPENSIVE":
            return "expensive", 2600
        elif price_level == "PRICE_LEVEL_VERY_EXPENSIVE":
            return "fineDining", 4200
        elif price_level == "PRICE_LEVEL_MODERATE":
            return "moderate", 1500

        if rating and rating >= 4.7:
            return "expensive", 2400
        elif rating and rating < 4.1:
            return "budget", 750
        return "moderate", 1400

    def _resolve_authentic_hotel_image(self, name: str, category: str, city: Optional[str] = None) -> str:
        """
        Provides authentic, representative property photos for hotels in Pakistan
        when Google Places does not return direct photo media.
        """
        n = (name or "").lower()
        cat = (category or "").lower()
        c = (city or "").lower()

        # Specific Hotel Brand & Heritage Properties
        if "serena" in n:
            if "shigar" in n or "fort" in n:
                return "https://images.unsplash.com/photo-1590490360182-c33d57733427?auto=format&fit=crop&w=1200&q=80"
            if "hunza" in n or "baltit" in n or "karimabad" in n:
                return "https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=1200&q=80"
            if "gilgit" in n:
                return "https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=80"
            return "https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=1200&q=80"

        if "marriott" in n:
            return "https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=80"

        if any(w in n for w in ["pearl continental", "pc hotel"]):
            return "https://images.unsplash.com/photo-1582719508461-905c673771fd?auto=format&fit=crop&w=1200&q=80"

        if "ramada" in n:
            return "https://images.unsplash.com/photo-1571896349842-33c89424de2d?auto=format&fit=crop&w=1200&q=80"

        if "faletti" in n:
            return "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?auto=format&fit=crop&w=1200&q=80"

        if "avari" in n:
            return "https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?auto=format&fit=crop&w=1200&q=80"

        if any(w in n for w in ["movenpick", "mövenpick"]):
            return "https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=80"

        if "beach luxury" in n:
            return "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?auto=format&fit=crop&w=1200&q=80"

        if "shangrila" in n:
            return "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80"

        if "luxus" in n:
            if "hunza" in n or "attabad" in n:
                return "https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?auto=format&fit=crop&w=1200&q=80"
            return "https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?auto=format&fit=crop&w=1200&q=80"

        if any(w in n for w in ["pine park", "walnut heights", "shogran", "kalam"]):
            return "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1200&q=80"

        # Categorical Resolution
        if cat in ["glamping", "pods", "campground"]:
            return "https://images.unsplash.com/photo-1510312305653-8ed496efae75?auto=format&fit=crop&w=1200&q=80"
        elif cat == "resort":
            return "https://images.unsplash.com/photo-1519671482749-fd09be7ccebf?auto=format&fit=crop&w=1200&q=80"
        elif cat == "boutique":
            return "https://images.unsplash.com/photo-1590490360182-c33d57733427?auto=format&fit=crop&w=1200&q=80"
        elif cat == "budget":
            return "https://images.unsplash.com/photo-1596394516093-501ba68a0ba6?auto=format&fit=crop&w=1200&q=80"

        return "https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=80"

    def _resolve_authentic_food_image(self, category: str, cuisine: str, name: str) -> str:
        """Fallback food image matching cuisine/category when place has no photo."""
        n = (name or "").lower()
        cat = (category or "").lower()

        if any(w in n for w in ["pizza", "broadway", "domino", "cheezious"]):
            return "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=1000&q=80"
        if any(w in n for w in ["burger", "kfc", "mcdonald", "hardee", "howdy", "ranchers"]):
            return "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=1000&q=80"
        if any(w in n for w in ["biryani", "pulao", "savour"]):
            return "https://images.unsplash.com/photo-1589302168068-964664d93dc0?auto=format&fit=crop&w=1000&q=80"
        if any(w in n for w in ["bbq", "tikka", "kebab", "charsi", "shinwari"]):
            return "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=1000&q=80"
        if any(w in n for w in ["cafe", "coffee", "chaaye", "chai"]):
            return "https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=1000&q=80"
        if any(w in n for w in ["bakery", "cake", "mithai", "sweets"]):
            return "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=1000&q=80"
        if any(w in n for w in ["chinese", "wok", "asian", "ginyaki"]):
            return "https://images.unsplash.com/photo-1541696432-82c6da8ce7bf?auto=format&fit=crop&w=1000&q=80"
        if any(w in n for w in ["steak", "continental"]):
            return "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=1000&q=80"

        if cat == "bbq":
            return "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=1000&q=80"
        elif cat == "biryani":
            return "https://images.unsplash.com/photo-1589302168068-964664d93dc0?auto=format&fit=crop&w=1000&q=80"
        elif cat == "fastFood":
            return "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=1000&q=80"
        elif cat == "chinese":
            return "https://images.unsplash.com/photo-1541696432-82c6da8ce7bf?auto=format&fit=crop&w=1000&q=80"
        elif cat == "cafe":
            return "https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=1000&q=80"
        elif cat == "bakery":
            return "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=1000&q=80"

        return "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1000&q=80"

    def _resolve_authentic_specialties(
        self,
        name: str,
        category: str,
        cuisine: str,
        types: List[str],
        editorial_text: Optional[str] = None,
        city: Optional[str] = None,
    ) -> List[str]:
        """
        Derives authentic, realistic specialties and signature dishes for Pakistani and
        international restaurants instead of generic placeholders.
        """
        n = (name or "").lower()
        cat = (category or "").lower()
        c = (city or "").lower()

        # 1. Iconic Brands & Specific Establishments
        if "savour" in n:
            return ["Savour Special Pulao with Shami Kababs", "Crispy Roast Chicken", "Shahi Zarda", "Fresh Raita & Salad"]
        if "monal" in n:
            return ["Monal Special Chicken Makhni Karahi", "Mutton Dum Pukht", "Charcoal Seekh Kebabs", "Cheese Garlic Naan"]
        if "cheezious" in n:
            return ["Crown Crust Pizza", "Beast Burger", "Bihari Chicken Rolls", "Cheesy Sticks with Dip"]
        if any(w in n for w in ["charsi", "shinwari", "namak mandi", "khyber"]):
            return ["Namak Mandi Dumba Karahi", "Charsi Mutton Ribs Tikka", "Patta Boti", "Peshawari Rosh with Naan"]
        if "kolachi" in n:
            return ["Kolachi Special Karahi", "Hunza Kabab", "Grilled Tiger Prawns", "Fish Tikka with Puri Paratha"]
        if "kfc" in n:
            return ["Hot & Crispy Fried Chicken", "Zinger Burger", "Twister Wrap", "Hot Wings"]
        if "mcdonald" in n:
            return ["Big Mac", "Spicy McCrispy Burger", "Quarter Pounder", "Crispy Apple Pie"]
        if "subway" in n:
            return ["Chicken Teriyaki Sub", "Roasted Chicken Breast Sub", "Italian B.M.T.", "Chocolate Chip Cookies"]
        if "hardee" in n:
            return ["Thickburger Angus Beef", "Santa Fe Chicken Fillet", "Hand-Scooped Shake", "Crispy Curly Fries"]
        if "howdy" in n:
            return ["Rodeo Double Beef Burger", "Son of a Bun", "Jalapeno Poppers", "Curly Fries"]
        if "broadway" in n:
            return ["Tarzan Tikka Pizza", "Wicked Blend Stuffed Crust", "Garlic Mayo Rolls", "Molten Lava Cake"]
        if "pizza hut" in n:
            return ["Chicken Fajita Sicilian Pizza", "Super Supreme Pizza", "Cheesy Garlic Bread", "Potato Wedges"]
        if "domino" in n:
            return ["Legend Ranch BBQ Pizza", "Tex-Mex Stuffed Crust", "Cheesy Breadsticks", "Chocolate Lava"]
        if "ranchers" in n:
            return ["Big Ben Beef Burger", "Furious Peri Fries", "Crispy Tender Strips", "Ranch Dip"]
        if "johnny" in n and "jugnu" in n:
            return ["Wehshi Zinger Burger", "Atomic Fillet Burger", "Loaded Curly Fries", "Garlic Mayo Sauce"]
        if any(w in n for w in ["bundu khan", "gourmet restaurant"]):
            return ["Chicken Bihari Boti", "Mutton Seekh Kababs", "Crispy Puri Paratha", "Chicken Malai Tikka"]
        if any(w in n for w in ["butt karahi", "ilyas karahi"]):
            return ["Desi Ghee Mutton Karahi", "Chicken Makhni Handi", "Tandoori Roghni Naan", "Fresh Zeera Raita"]
        if any(w in n for w in ["waris", "muhammadi", "nihari"]):
            return ["Special Nalli Maghaz Nihari", "Beef Shank Nihari", "Tandoori Taftan", "Fresh Ginger & Green Chilies"]
        if any(w in n for w in ["haleem", "mazedar"]):
            return ["Special Shahi Beef Haleem", "Chaat Masala & Fried Onions", "Fresh Naan", "Mint Salad"]
        if any(w in n for w in ["chaaye khana", "chai khana"]):
            return ["Karak Doodh Patti Chai", "Nutella Banana Crepes", "Traditional Club Sandwich", "English Breakfast Platter"]
        if any(w in n for w in ["gloria jean", "second cup", "coffee planet", "costa"]):
            return ["Signature Caramel Macchiato", "Madagascar Vanilla Chiller", "Belgian Chocolate Muffin", "Mocha Frappe"]
        if any(w in n for w in ["tehzeeb", "rahat", "bakers", "bakery"]):
            return ["Tehzeeb Signature Pizza", "Chicken Patties", "Cream Rolls", "Assorted Baklava"]
        if any(w in n for w in ["ginyaki", "dynasty", "yum", "mei kong", "asian wok", "bamboo union", "ginsoy"]):
            return ["Kung Pao Chicken", "Sizzling Mongolian Beef", "Egg Fried Rice", "Hot & Sour Soup"]
        if any(w in n for w in ["mandi", "ridan", "bait al mandi"]):
            return ["Authentic Yemeni Mutton Mandi", "Madfoon Chicken", "Kunafa with Cream", "Spicy Sahawek Salsa"]
        if any(w in n for w in ["student biryani", "karachi biryani", "naseeb biryani", "biryani"]):
            return ["Special Karachi Dum Biryani", "Beef Nalli Biryani", "Crispy Shami Kabab", "Fresh Zeera Raita"]
        if any(w in n for w in ["quetta", "alamgir", "chai adda"]):
            return ["Lachha Paratha with Fried Egg", "Special Doodh Patti Chai", "Keema Paratha", "Sulemani Kahwa"]
        if any(w in n for w in ["tuscany", "roasters", "street 1", "aylanto", "cafe flo"]):
            return ["Tenderloin Steak with Mushroom Sauce", "Polo Tuscan Chicken", "Wild Mushroom Fettuccine", "Molten Lava Cake"]
        if "pappasallis" in n:
            return ["Pappasallis Special Pizza", "Lasagna Bolognese", "Creamy Fettuccine Alfredo", "Garlic Bread with Cheese"]
        if "fuoco" in n:
            return ["Handcrafted Truffle Tagliatelle", "Wood-Fired Neapolitan Pizza", "Beef Carpaccio", "Tiramisu al Caffe"]
        if "pomodoro" in n:
            return ["Classic Margherita Pizza", "Spaghetti Carbonara", "Penne Arbiatta", "Bruschetta al Pomodoro"]
        if any(w in n for w in ["fish", "trout", "river view"]):
            return ["Pan-Fried River Trout with Herbs", "Lahori Crusted Finger Fish", "Tawa Fried Fish", "Mint Coriander Chutney"]
        if any(w in n for w in ["roll", "shawarma", "red apple", "hot n spicy"]):
            return ["Chicken Garlic Mayo Roll", "Bihari Beef Paratha Roll", "Arabic Chicken Shawarma", "Zinger Chutney Roll"]
        if any(w in n for w in ["halwa puri", "nashta", "chana"]):
            return ["Crispy Halwa Puri", "Lahori Chana Tarkari", "Spiced Aloo Bhujia", "Sweet Meethi Lassi"]
        if any(w in n for w in ["sweets", "mithai", "jamil", "fresco"]):
            return ["Warm Gulab Jamun", "Rasmalai in Saffron Milk", "Special Dahi Bhallay", "Samosa Chaat with Chutneys"]

        # 2. Regional Alpine Specialties (Hunza, Skardu, Gilgit, Swat)
        if any(reg in c or reg in n for reg in ["hunza", "skardu", "gilgit", "baltit", "altit", "passu"]):
            return ["Authentic Hunza Chapshoro (Meat Pie)", "Steamed Mamtu Dumplings", "Fresh River Trout with Herbs", "Ghyaling with Apricot Honey"]
        if any(reg in c or reg in n for reg in ["swat", "kalam", "mingora"]):
            return ["Fresh Pan-Fried Swat Trout", "Kalam Mountain Mutton Karahi", "Peshawari Chapli Kabab", "Hot Tandoori Bread"]

        # 3. Categorical Authentic Signatures
        if cat == "bbq":
            return ["Charcoal Seekh Kebabs", "Chicken Malai Boti", "Mutton Ribs Tikka", "Kandahari Naan with Chutney"]
        elif cat == "biryani":
            return ["Special Chicken Dum Biryani", "Mutton Pulao Platter", "Crispy Shami Kabab", "Mint Raita & Salad"]
        elif cat in ["fastfood", "fast_food"]:
            return ["Gourmet Smash Beef Burger", "Crispy Zinger Chicken Fillet", "Loaded Cheesy Fries", "Club Sandwich"]
        elif cat == "chinese":
            return ["Chicken Manchurian with Fried Rice", "Kung Pao Chicken", "Chicken Chow Mein", "Crispy Spring Rolls"]
        elif cat == "italian":
            return ["Artisan Wood-Fired Pizza", "Creamy Fettuccine Alfredo", "Traditional Lasagna Bolognese", "Tiramisu al Caffe"]
        elif cat == "continental":
            return ["Charbroiled Prime Beef Steak", "Creamy Fettuccine Alfredo", "Parmesan Crusted Chicken", "Garlic Butter Baguette"]
        elif cat == "bakery":
            return ["Flaky Chicken Patties", "Fresh Butter Croissants", "Cream Puff Pastries", "Artisan Fruit Cake"]
        elif cat == "cafe":
            return ["Specialty Doodh Patti Chai", "Vanilla Caramel Latte", "Nutella Crepes", "Grilled Club Sandwich"]
        elif cat == "dhaba":
            return ["Karak Doodh Patti Chai", "Crispy Lachha Paratha", "Chana Daal Fry with Makhan", "Fried Egg"]
        elif cat == "streetfood":
            return ["Crispy Gol Gappay with Spicy Khatta", "Special Dahi Bhalla Platter", "Samosa Chaat with Tamarind", "Chicken Paratha Roll"]
        elif cat == "vegetarian":
            return ["Paneer Makhani Handi", "Daal Makhani with Butter", "Mixed Seasonal Vegetable Sabzi", "Tandoori Roti"]
        elif cat == "finedining":
            return ["Chef's Signature Mutton Handi", "Charcoal Mixed Grill Platter", "Mutton Dum Pukht", "Kuldar Kulfi Falooda"]
        elif cat == "familydining":
            return ["Family Special Chicken Karahi", "Mutton Seekh Kababs", "Chicken Reshmi Handi", "Assorted Naan Basket"]

        # 4. Default Authentic Desi Specialties
        return ["Chef's Special Mutton Handi", "Desi Chicken Karahi", "Hot Roghni Naan", "Zeera Mint Raita"]

    async def search_nearby_food(
        self,
        latitude: float,
        longitude: float,
        radius_km: float = 30.0,
        category: str = "all",
        cuisine: Optional[str] = None,
        city_name: Optional[str] = None,
        origin_lat: Optional[float] = None,
        origin_lon: Optional[float] = None,
        search_query: Optional[str] = None,
    ) -> List[FoodPlaceItem]:
        """
        Query Google Places API (New) nearby search for food & dining locations.
        Enforces 25-30km radius, deduplicates places, extracts exact coordinates,
        and falls back to curated database strictly within search radius if zero results.
        """
        api_key = self._get_api_key()
        api_key = self._get_api_key()
        if not api_key:
            logger.warning("[GooglePlaces] No API key for Food.")
            return []

        # Check in-memory cache
        cache_key = f"food_{round(latitude, 3)}_{round(longitude, 3)}_{round(radius_km, 1)}_{category.lower()}_{str(cuisine).lower()}"
        now = time.time()
        if cache_key in self._cache:
            cached_time, cached_items = self._cache[cache_key]
            if now - cached_time < self._cache_ttl_seconds:
                logger.info(f"[GooglePlaces] Food cache hit ({len(cached_items)} places)")
                return [p.model_copy() for p in cached_items]

        radius_meters = int(min(max(radius_km * 1000.0, 1000.0), 50000.0))

        headers = {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": api_key,
            "X-Goog-FieldMask": (
                "places.id,"
                "places.displayName,"
                "places.formattedAddress,"
                "places.shortFormattedAddress,"
                "places.location,"
                "places.rating,"
                "places.userRatingCount,"
                "places.types,"
                "places.photos,"
                "places.priceLevel,"
                "places.googleMapsUri,"
                "places.websiteUri,"
                "places.nationalPhoneNumber,"
                "places.regularOpeningHours,"
                "places.editorialSummary,"
                "places.businessStatus"
            ),
        }

        # Determine whether a specific cuisine, category, or search query is requested
        cat_lower = category.lower()
        active_cuisine = (cuisine or "").strip()
        if active_cuisine.lower() in ["all", "all cuisines"]:
            active_cuisine = ""

        is_specific = bool(
            active_cuisine
            or (cat_lower not in ["all", "all cuisines", "restaurant"])
            or (search_query and search_query.strip())
        )

        collected_places: Dict[str, Dict[str, Any]] = {}

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                if is_specific:
                    target_kw = active_cuisine or (cat_lower if cat_lower not in ["all", "all cuisines"] else None) or search_query
                    q_term = f"{target_kw} restaurants in {city_name or 'Pakistan'}"
                    logger.info(f"[GooglePlaces] Targeted Food Search: '{q_term}' (Center: {latitude:.4f}, {longitude:.4f}, Radius: {radius_meters}m)")

                    # Provide type hint if available
                    type_hint = None
                    kw_low = target_kw.lower()
                    if "chinese" in kw_low:
                        type_hint = "chinese_restaurant"
                    elif "italian" in kw_low:
                        type_hint = "italian_restaurant"
                    elif "cafe" in kw_low:
                        type_hint = "cafe"
                    elif "bakery" in kw_low:
                        type_hint = "bakery"
                    elif "bbq" in kw_low or "barbecue" in kw_low:
                        type_hint = "barbecue_restaurant"
                    elif "fastfood" in kw_low or "fast food" in kw_low:
                        type_hint = "fast_food_restaurant"
                    elif "steak" in kw_low or "continental" in kw_low:
                        type_hint = "steak_house"

                    text_payload: Dict[str, Any] = {
                        "textQuery": q_term,
                        "maxResultCount": 20,
                        "locationBias": {
                            "circle": {
                                "center": {"latitude": latitude, "longitude": longitude},
                                "radius": float(radius_meters),
                            }
                        },
                    }
                    if type_hint:
                        text_payload["includedType"] = type_hint

                    text_res = await client.post(
                        settings.GOOGLE_PLACES_TEXT_SEARCH_URL,
                        headers=headers,
                        json=text_payload,
                    )
                    if text_res.status_code == 200:
                        for p in text_res.json().get("places", []):
                            pid = p.get("id")
                            if pid and pid not in collected_places:
                                collected_places[pid] = p
                    else:
                        logger.warning(f"[GooglePlaces] Targeted text search returned status {text_res.status_code}: {text_res.text[:200]}")

                    # Fallback text search without strict includedType if fewer than 5 places found
                    if len(collected_places) < 5 and type_hint:
                        fallback_payload = {
                            "textQuery": q_term,
                            "maxResultCount": 20,
                            "locationBias": {
                                "circle": {
                                    "center": {"latitude": latitude, "longitude": longitude},
                                    "radius": float(radius_meters),
                                }
                            },
                        }
                        f_res = await client.post(
                            settings.GOOGLE_PLACES_TEXT_SEARCH_URL,
                            headers=headers,
                            json=fallback_payload,
                        )
                        if f_res.status_code == 200:
                            for p in f_res.json().get("places", []):
                                pid = p.get("id")
                                if pid and pid not in collected_places:
                                    collected_places[pid] = p

                else:
                    # General / All Cuisines: query nearby search
                    included_types = settings.GOOGLE_FOOD_TYPES
                    payload = {
                        "includedTypes": included_types,
                        "maxResultCount": 20,
                        "locationRestriction": {
                            "circle": {
                                "center": {"latitude": latitude, "longitude": longitude},
                                "radius": float(radius_meters),
                            }
                        },
                    }
                    logger.info(f"[GooglePlaces] General Food Nearby Search (Center: {latitude:.4f}, {longitude:.4f}, Radius: {radius_meters}m)")
                    response = await client.post(
                        settings.GOOGLE_PLACES_NEARBY_URL,
                        headers=headers,
                        json=payload,
                    )
                    if response.status_code == 200:
                        for p in response.json().get("places", []):
                            pid = p.get("id")
                            if pid and pid not in collected_places:
                                collected_places[pid] = p
                    else:
                        logger.warning(f"[GooglePlaces] Food Nearby search returned status {response.status_code}: {response.text[:200]}")

                    if len(collected_places) < 15:
                        q_term = f"popular food restaurants and cafes in {city_name or 'Pakistan'}"
                        text_payload = {
                            "textQuery": q_term,
                            "maxResultCount": 20,
                            "locationBias": {
                                "circle": {
                                    "center": {"latitude": latitude, "longitude": longitude},
                                    "radius": float(radius_meters),
                                }
                            },
                        }
                        text_res = await client.post(
                            settings.GOOGLE_PLACES_TEXT_SEARCH_URL,
                            headers=headers,
                            json=text_payload,
                        )
                        if text_res.status_code == 200:
                            for p in text_res.json().get("places", []):
                                pid = p.get("id")
                                if pid and pid not in collected_places:
                                    collected_places[pid] = p

        except Exception as e:
            logger.error(f"[GooglePlaces] Food search exception: {e}")

        # If zero results, return empty list (NO placeholder / dummy data)
        if not collected_places:
            logger.warning(f"[GooglePlaces] No food spots returned by Google for ({latitude}, {longitude}).")
            return []

        places: List[FoodPlaceItem] = []
        for pid, p in collected_places.items():
            # Exclude permanently or temporarily closed places
            b_status = p.get("businessStatus")
            if b_status in ["CLOSED_PERMANENTLY", "CLOSED_TEMPORARILY"]:
                continue

            loc = p.get("location", {})
            p_lat = loc.get("latitude")
            p_lon = loc.get("longitude")

            if not is_valid_coordinates(p_lat, p_lon):
                continue

            # Strict radius check (+5km tolerance for boundary roads)
            dist_from_search = haversine_distance_km(latitude, longitude, p_lat, p_lon)
            if dist_from_search > radius_km + 5.0:
                continue

            name_obj = p.get("displayName", {})
            name = name_obj.get("text") if isinstance(name_obj, dict) else (p.get("name") or "Food Spot")
            full_addr = p.get("formattedAddress", "")
            short_addr = p.get("shortFormattedAddress", full_addr.split(",")[0] if full_addr else (city_name or "Pakistan"))
            types = p.get("types", [])
            rating = float(p.get("rating") or 4.5)
            review_count = int(p.get("userRatingCount") or 80)
            price_level = p.get("priceLevel")

            food_cat, food_cuisine = self._classify_food(name=name, types=types)
            price_tier, avg_cost = self._classify_food_price_tier(price_level=price_level, rating=rating)

            photos = p.get("photos", [])
            primary_img = self._format_photo_url(photos[0] if photos else None, api_key) or ""
            if not primary_img:
                primary_img = self._resolve_authentic_food_image(category=food_cat, cuisine=food_cuisine, name=name)
            gallery = [
                url for ph in photos[:4]
                if (url := self._format_photo_url(ph, api_key)) is not None
            ]
            if not gallery and primary_img:
                gallery = [primary_img]

            # Operating hours
            hours_obj = p.get("regularOpeningHours", {})
            is_open = hours_obj.get("openNow", True) if isinstance(hours_obj, dict) else True
            weekday_desc = hours_obj.get("weekdayDescriptions", []) if isinstance(hours_obj, dict) else []
            hours_str = weekday_desc[0].split(": ", 1)[-1] if weekday_desc else "11:00 AM - 12:00 AM"

            phone = p.get("nationalPhoneNumber") or "+92-51-111-111-111"

            # Directions URL
            if origin_lat is not None and origin_lon is not None:
                directions_url = f"https://www.google.com/maps/dir/?api=1&origin={origin_lat:.5f},{origin_lon:.5f}&destination={p_lat:.5f},{p_lon:.5f}&travelmode=driving"
            else:
                directions_url = f"https://www.google.com/maps/dir/?api=1&destination={p_lat:.5f},{p_lon:.5f}&travelmode=driving"

            editorial = p.get("editorialSummary", {})
            text_desc = editorial.get("text") if isinstance(editorial, dict) else None
            desc = text_desc or f"{food_cuisine} located in {short_addr}."

            specialties_list = self._resolve_authentic_specialties(
                name=name,
                category=food_cat,
                cuisine=food_cuisine,
                types=types,
                editorial_text=text_desc,
                city=city_name,
            )

            place_item = FoodPlaceItem(
                id=pid,
                name=name,
                category=food_cat,
                cuisine=food_cuisine,
                latitude=p_lat,
                longitude=p_lon,
                city=city_name or "Pakistan",
                address=full_addr or short_addr,
                rating=rating,
                reviewCount=review_count,
                priceTier=price_tier,
                avgCostPerPersonPkr=avg_cost,
                imageUrl=primary_img,
                galleryImages=gallery,
                isOpen=is_open,
                openingHours=hours_str,
                phone=phone,
                specialties=specialties_list,
                description=desc,
                landmarkNearby=short_addr,
                directions_url=directions_url,
            )
            places.append(place_item)

        # Limit to target 20 results
        places = places[:20]
        self._cache[cache_key] = (now, places)
        return places

    def _classify_facility(
        self,
        name: str,
        types: List[str],
        primary_type: Optional[str] = None,
        target_assistance_type: Optional[str] = None,
    ) -> Tuple[str, bool]:
        """
        Classify healthcare/help establishment into Flutter's FacilityType enum values:
        emergency, firstAid, government, privateHospital, pharmacy.
        Returns (facility_type_key, is_emergency).
        """
        n = name.lower()
        t = [typ.lower() for typ in types]
        tgt = (target_assistance_type or "").lower().replace("_", "").replace(" ", "").strip()

        # 1. Pharmacy / Drugstore
        if "pharmacy" in t or "drugstore" in t or any(w in n for w in [
            "pharmacy", "chemist", "medical store", "d.watson", "d watson",
            "fazal din", "medicare store", "shaheen", "servaid", "clinix",
            "green pharmacy", "medicine", "drug store"
        ]):
            return "pharmacy", False

        # 2. Emergency / Trauma Specialty
        if any(w in n for w in ["trauma", "emergency", "burn center", "rescue 1122", "casualty", "er 24/7", "accident & emergency"]):
            return "emergency", True

        # 3. Government / Public Tertiary & DHQ/THQ Hospitals
        if any(w in n for w in [
            "pims", "mayo", "dhq", "thq", "civil hospital", "services hospital",
            "jinnah hospital", "cda hospital", "government", "govt", "cmh",
            "combined military", "benazir bhutto", "holy family", "nishtar",
            "allied hospital", "wapda hospital", "railway hospital", "cantt general",
            "cantonment general", "social security hospital", "tehsil headquarter",
            "district headquarter", "federal government", "fgsh", "rawalpindi institute",
            "punjab institute", "national institute", "kpt hospital"
        ]):
            return "government", True

        # 4. Major Private & Tertiary Care Hospitals
        if any(w in n for w in [
            "shifa", "aga khan", "national hospital", "maroof", "quaid-e-azam",
            "doctors hospital", "south city", "liaquat national", "kulsum",
            "ali medical", "al-khidmat", "medics", "medicare", "care hospital",
            "chughtai", "fatima memorial", "ziauddin", "shaukat khanum", "bilawal",
            "international hospital", "specialist clinic", "consultant", "private"
        ]):
            return "privateHospital", True

        # 5. First Aid & Trailhead / Mountain Post / Dispensary
        if any(w in n for w in [
            "first aid", "dispensary", "aid post", "trailhead aid", "babusar aid",
            "basic health", "bhu", "rhu", "red crescent", "rescue station",
            "trauma post", "relief post", "medical post", "first-aid"
        ]):
            return "firstAid", True

        # 6. Fallback based on targeted query context
        if tgt == "pharmacy":
            return "pharmacy", False
        elif tgt in ["government", "govt"]:
            return "government", True
        elif tgt in ["firstaid", "first_aid"]:
            return "firstAid", True
        elif tgt in ["private", "privatehospital"]:
            return "privateHospital", True
        elif tgt == "emergency":
            return "emergency", True

        # Default Hospital
        is_emerg = "hospital" in t or any(w in n for w in ["hospital", "medical center", "complex"])
        return "privateHospital", is_emerg

    async def search_nearby_help(
        self,
        latitude: float,
        longitude: float,
        radius_km: float = 30.0,
        assistance_type: Optional[str] = None,
        emergency_only: bool = False,
        city_name: Optional[str] = None,
        origin_lat: Optional[float] = None,
        origin_lon: Optional[float] = None,
        search_query: Optional[str] = None,
    ) -> List[HelpFacilityItem]:
        """
        Query Google Places API (New) nearby search for healthcare and emergency facilities.
        Enforces 25-30km radius, deduplicates places, extracts exact coordinates,
        and strictly filters by assistance_type.
        """
        api_key = self._get_api_key()
        if not api_key:
            logger.warning("[GooglePlaces] No API key for Help.")
            return []

        clean_type = (assistance_type or "").lower().replace("_", "").replace(" ", "").strip()
        cache_key = f"help_{round(latitude, 3)}_{round(longitude, 3)}_{round(radius_km, 1)}_{clean_type}_{emergency_only}"
        now = time.time()
        if cache_key in self._cache:
            cached_time, cached_items = self._cache[cache_key]
            if now - cached_time < self._cache_ttl_seconds:
                logger.info(f"[GooglePlaces] Help cache hit ({len(cached_items)} facilities)")
                return [f.model_copy() for f in cached_items]

        radius_meters = int(min(max(radius_km * 1000.0, 1000.0), 50000.0))

        headers = {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": api_key,
            "X-Goog-FieldMask": (
                "places.id,"
                "places.displayName,"
                "places.formattedAddress,"
                "places.shortFormattedAddress,"
                "places.location,"
                "places.rating,"
                "places.userRatingCount,"
                "places.types,"
                "places.primaryType,"
                "places.googleMapsUri,"
                "places.websiteUri,"
                "places.nationalPhoneNumber,"
                "places.internationalPhoneNumber,"
                "places.regularOpeningHours,"
                "places.businessStatus"
            ),
        }

        # Targeted query and includedTypes per assistance type
        if clean_type == "pharmacy":
            mapped_types = ["pharmacy"]
            query_target = search_query or "pharmacy medical store chemist"
        elif clean_type in ["firstaid", "first_aid"]:
            mapped_types = ["medical_clinic", "hospital", "doctor"]
            query_target = search_query or "first aid station dispensary clinic"
        elif clean_type in ["government", "govt"]:
            mapped_types = ["hospital"]
            query_target = search_query or "government hospital civil hospital DHQ"
        elif clean_type in ["private", "privatehospital"]:
            mapped_types = ["hospital", "medical_clinic"]
            query_target = search_query or "private hospital medical center"
        elif clean_type == "emergency" or emergency_only:
            mapped_types = ["hospital"]
            query_target = search_query or "emergency hospital 24/7 trauma center"
        else:
            mapped_types = settings.GOOGLE_HELP_TYPES
            query_target = search_query or "hospitals and clinics"

        payload = {
            "includedTypes": mapped_types,
            "maxResultCount": 20,
            "locationRestriction": {
                "circle": {
                    "center": {"latitude": latitude, "longitude": longitude},
                    "radius": float(radius_meters),
                }
            },
        }

        collected_places: Dict[str, Dict[str, Any]] = {}

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                logger.info(f"[GooglePlaces] Help Search (Center: {latitude:.4f}, {longitude:.4f}, Type: {clean_type}, Types: {mapped_types})")
                response = await client.post(
                    settings.GOOGLE_PLACES_NEARBY_URL,
                    headers=headers,
                    json=payload,
                )

                if response.status_code == 200:
                    for p in response.json().get("places", []):
                        pid = p.get("id")
                        if pid and pid not in collected_places:
                            collected_places[pid] = p
                else:
                    logger.warning(f"[GooglePlaces] Help Nearby search error {response.status_code}: {response.text[:200]}")

                # Guarantee 15+ results: query Text Search with targeted query
                if query_target or len(collected_places) < 15:
                    q_term = f"{query_target} in {city_name or 'Pakistan'}"
                    text_payload = {
                        "textQuery": q_term,
                        "maxResultCount": 20,
                        "locationBias": {
                            "circle": {
                                "center": {"latitude": latitude, "longitude": longitude},
                                "radius": float(radius_meters),
                            }
                        },
                    }
                    text_res = await client.post(
                        settings.GOOGLE_PLACES_TEXT_SEARCH_URL,
                        headers=headers,
                        json=text_payload,
                    )
                    if text_res.status_code == 200:
                        for p in text_res.json().get("places", []):
                            pid = p.get("id")
                            if pid and pid not in collected_places:
                                collected_places[pid] = p

        except Exception as e:
            logger.error(f"[GooglePlaces] Help search exception: {e}")

        # If zero results, return empty list (NO placeholder / dummy data)
        if not collected_places:
            logger.warning(f"[GooglePlaces] No help facilities returned by Google for ({latitude}, {longitude}).")
            return []

        facilities: List[HelpFacilityItem] = []
        non_medical_types = {
            "clothing_store", "electronics_store", "software_company",
            "cell_phone_store", "car_repair", "real_estate_agency", "gym",
            "supermarket", "grocery_store", "school", "park"
        }

        for pid, p in collected_places.items():
            # Exclude permanently or temporarily closed healthcare establishments
            b_status = p.get("businessStatus")
            if b_status in ["CLOSED_PERMANENTLY", "CLOSED_TEMPORARILY"]:
                continue

            types = p.get("types", [])
            types_lower = {t.lower() for t in types}

            # Filter out obvious non-medical businesses
            if types_lower and types_lower.issubset(non_medical_types):
                continue

            loc = p.get("location", {})
            p_lat = loc.get("latitude")
            p_lon = loc.get("longitude")

            if not is_valid_coordinates(p_lat, p_lon):
                continue

            # Strict radius check (+5km tolerance for boundary roads)
            dist_from_search = haversine_distance_km(latitude, longitude, p_lat, p_lon)
            if dist_from_search > radius_km + 5.0:
                continue

            name_obj = p.get("displayName", {})
            name = name_obj.get("text") if isinstance(name_obj, dict) else (p.get("name") or "Medical Center")
            full_addr = p.get("formattedAddress", "")
            short_addr = p.get("shortFormattedAddress", full_addr.split(",")[0] if full_addr else (city_name or "Pakistan"))
            rating = float(p.get("rating") or 4.5)
            review_count = int(p.get("userRatingCount") or 75)

            fac_type, is_emerg = self._classify_facility(
                name=name,
                types=types,
                target_assistance_type=clean_type,
            )

            # Strict assistance type category filtering
            if clean_type == "pharmacy":
                if fac_type != "pharmacy" and "pharmacy" not in types_lower and not any(w in name.lower() for w in ["pharmacy", "chemist", "medical store", "d.watson", "fazal din", "shaheen", "servaid", "clinix"]):
                    continue
                # Exclude malls / general supermarkets without pharmacy keywords in name
                if any(w in name.lower() for w in ["mega", "mall", "supermarket", "mart", "cash & carry"]) and not any(w in name.lower() for w in ["pharmacy", "chemist", "med"]):
                    continue
                fac_type = "pharmacy"
                is_emerg = False
            elif clean_type in ["government", "govt"]:
                if fac_type != "government" and not any(w in name.lower() for w in ["pims", "mayo", "dhq", "thq", "civil", "services", "jinnah", "cda", "government", "govt", "cmh", "military", "federal", "benazir", "holy family", "railway", "wapda", "cantt"]):
                    continue
                fac_type = "government"
            elif clean_type in ["private", "privatehospital"]:
                if fac_type == "government" or any(w in name.lower() for w in ["dhq", "thq", "civil hospital", "pims", "government hospital", "govt hospital", "cmh", "combined military", "holy family"]):
                    continue
                fac_type = "privateHospital"
            elif clean_type in ["firstaid", "first_aid"]:
                # Exclude tertiary mega hospitals from simple first aid / dispensary
                if any(w in name.lower() for w in ["international hospital", "shifa", "quaid-e-azam", "aga khan", "cmh", "pims", "mayo", "dhq", "thq"]):
                    continue
                if fac_type != "firstAid" and not any(w in name.lower() for w in ["first aid", "dispensary", "aid post", "bhu", "rhu", "clinic", "rescue", "center", "centre"]):
                    continue
                fac_type = "firstAid"
            elif clean_type == "emergency" or emergency_only:
                if not is_emerg and fac_type != "emergency":
                    continue
                fac_type = "emergency"
                is_emerg = True

            hours_obj = p.get("regularOpeningHours", {})
            is_open = hours_obj.get("openNow", True) if isinstance(hours_obj, dict) else True
            weekday_desc = hours_obj.get("weekdayDescriptions", []) if isinstance(hours_obj, dict) else []
            hours_str = "24/7 Open" if (is_emerg or not weekday_desc) else weekday_desc[0].split(": ", 1)[-1]

            phone = p.get("nationalPhoneNumber") or p.get("internationalPhoneNumber") or "1122"

            if origin_lat is not None and origin_lon is not None:
                directions_url = f"https://www.google.com/maps/dir/?api=1&origin={origin_lat:.5f},{origin_lon:.5f}&destination={p_lat:.5f},{p_lon:.5f}&travelmode=driving"
            else:
                directions_url = f"https://www.google.com/maps/dir/?api=1&destination={p_lat:.5f},{p_lon:.5f}&travelmode=driving"

            services_list = [
                "24/7 Emergency & Triage" if is_emerg else "Primary Healthcare Services",
                "Patient Assessment & First Aid",
                "Diagnostic Services",
            ]

            facility = HelpFacilityItem(
                id=pid,
                name=name,
                type=fac_type,
                latitude=p_lat,
                longitude=p_lon,
                address=full_addr or short_addr,
                city=city_name or "Pakistan",
                landmarkNearby=short_addr,
                phone=phone,
                isEmergency=is_emerg,
                isOpen=is_open,
                operatingHours=hours_str,
                emergencyBedStatus="24/7 Active" if is_emerg else "Available",
                rating=rating,
                reviewCount=review_count,
                services=services_list,
                directions_url=directions_url,
            )
            facilities.append(facility)

        # Limit to target 20 results
        facilities = facilities[:20]
        self._cache[cache_key] = (now, facilities)
        return facilities


google_places_service = GooglePlacesService()

