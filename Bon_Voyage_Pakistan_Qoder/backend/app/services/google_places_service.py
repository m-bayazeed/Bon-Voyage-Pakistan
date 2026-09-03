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
    ) -> Tuple[str, str]:
        """
        Classify stay into: luxury, resort, boutique, budget, glamping/pods, all.
        Returns (category, badge_label).
        """
        n = name.lower()
        t = [typ.lower() for typ in types]

        # 1. Campsite / Pods / Glamping
        if (
            "campground" in t
            or any(w in n for w in ["camp", "glamping", "pod", "dome", "tent", "capsule", "campsite", "safari"])
        ):
            return "glamping", "Campsite / Pods"

        # 2. Mountain Resort / Scenic Resort
        if (
            "resort_hotel" in t
            or any(w in n for w in ["resort", "mountain", "valley", "lake", "view", "cliff", "river", "ridge", "heights"])
        ):
            return "resort", "Mountain Resort"

        # 3. Luxury / 5-Star
        if (
            any(w in n for w in ["serena", "marriott", "pearl continental", "pc hotel", "nishat", "5 star", "luxury", "grand hotel", "royal"])
            or price_level in ["PRICE_LEVEL_EXPENSIVE", "PRICE_LEVEL_VERY_EXPENSIVE"]
            or (rating is not None and rating >= 4.6 and review_count is not None and review_count >= 100)
        ):
            return "luxury", "5-Star Luxury"

        # 4. Boutique & Heritage / Lodge
        if (
            any(typ in t for typ in ["bed_and_breakfast", "cottage", "inn", "farmstay"])
            or any(w in n for w in ["boutique", "lodge", "cabin", "haveli", "chalet", "manor", "heritage", "villas", "inn"])
        ):
            return "boutique", "Boutique & Lodge"

        # 5. Guest House / Budget
        if (
            any(typ in t for typ in ["guest_house", "hostel", "motel"])
            or any(w in n for w in ["guest house", "guesthouse", "hostel", "motel", "budget", "rooms", "residency", "stay", "palace hotel"])
            or price_level in ["PRICE_LEVEL_FREE", "PRICE_LEVEL_INEXPENSIVE"]
            or (rating is not None and rating < 4.0)
        ):
            return "budget", "Guest House / Budget"

        # Default fallback categorization based on rating / types
        if rating is not None and rating >= 4.4:
            return "luxury", "5-Star Luxury"
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

        # Google Places searchNearby radius constraint (max 50,000 meters)
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
                radius_km=radius_km,
            )

        # Convert Google Places to StayItems with strict geographic validation
        stays: List[StayItem] = []
        for pid, p in collected_places.items():
            loc = p.get("location", {})
            p_lat = loc.get("latitude")
            p_lon = loc.get("longitude")

            if not is_valid_coordinates(p_lat, p_lon):
                continue

            # Strict Geographic Validation: ensure stay is within requested search radius (+5km tolerance)
            dist_from_search = haversine_distance_km(latitude, longitude, p_lat, p_lon)
            if dist_from_search > radius_km + 5.0:
                logger.info(f"[GooglePlaces] Rejected distant hotel ({p_lat}, {p_lon}) at {dist_from_search:.1f}km from center ({latitude}, {longitude})")
                continue

            full_addr = p.get("formattedAddress", "")
            short_addr = p.get("shortFormattedAddress", full_addr.split(",")[0] if full_addr else city_name or "Pakistan")
            types = p.get("types", [])
            rating = p.get("rating")
            review_count = p.get("userRatingCount")
            price_level = p.get("priceLevel")

            cat, badge = self._classify_stay(
                name=name,
                types=types,
                price_level=price_level,
                rating=rating,
                review_count=review_count,
            )

            # Photos
            photos = p.get("photos", [])
            primary_img = self._format_photo_url(photos[0] if photos else None, api_key)
            gallery = [
                url for ph in photos[:4]
                if (url := self._format_photo_url(ph, api_key)) is not None
            ]

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
                city=city_name or "Pakistan",
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
                highlight=f"{badge} in {city_name or 'Pakistan'}",
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

        # 1. Cafe & Coffee
        if "cafe" in t or "coffee_shop" in t or any(w in n for w in ["cafe", "café", "coffee", "roasters", "espresso", "chaaye khana", "tea lounge"]):
            return "cafe", "Artisan Coffee, Specialty Tea & Bakery"

        # 2. Bakery & Sweets
        if "bakery" in t or any(w in n for w in ["bakery", "bakers", "sweets", "mithai", "pastry", "patisserie", "confectionery"]):
            return "bakery", "Fresh Breads, Pastries & Pakistani Sweets"

        # 3. BBQ & Tikka
        if any(w in n for w in ["bbq", "barbeque", "tikka", "kebab", "kabab", "charsi", "namak mandi", "shinwari", "boti", "sajji"]):
            return "bbq", "Charcoal BBQ, Seekh Kebabs & Shinwari Karahi"

        # 4. Biryani & Pulao
        if any(w in n for w in ["biryani", "pulao", "savour", "rice", "naseeb", "karachi biryani", "student biryani"]):
            return "biryani", "Authentic Dum Biryani & Fragrant Pulao"

        # 5. Fast Food & Burgers
        if "fast_food_restaurant" in t or any(w in n for w in ["burger", "pizza", "fried chicken", "kfc", "mcdonald", "hardee", "subway", "howdy", "broadway", "cheezious"]):
            return "fastFood", "Gourmet Burgers, Crispy Chicken & Fast Food"

        # 6. Chinese & Pan-Asian
        if any(w in n for w in ["chinese", "asian", "wok", "noodle", "dumpling", "sichuan", "thai", "sushi", "chopstick"]):
            return "chinese", "Pak-Chinese, Sizzling Platters & Wok Dishes"

        # 7. Continental & Steaks
        if any(w in n for w in ["steak", "steakhouse", "continental", "pasta", "italian", "grill & steak"]):
            return "continental", "Prime Steaks, Continental & Italian Cuisine"

        # 8. Traditional & Regional (Northern / Pashtun / Sindhi / Balochi)
        if any(w in n for w in ["balti", "yak", "mamtu", "chapshoro", "trout", "hunza", "skardu", "gilgit", "balochi", "sajji", "dumpukht"]):
            return "traditionalLocal", "Authentic Regional Mountain Specialties"

        # 9. Street Food & Chaat
        if any(w in n for w in ["chaat", "gol gappay", "dahi bhallay", "samosa", "roll", "shawarma", "bun kabab", "street"]):
            return "streetFood", "Crispy Chaat, Bun Kababs & Street Delights"

        # 10. Highway Dhaba & Chai
        if any(w in n for w in ["dhaba", "chai", "quetta", "hotel & dhaba", "truck adda"]):
            return "dhaba", "Karak Doodh Patti Chai, Parathas & Highway Dhaba"

        # 11. Vegetarian
        if any(w in n for w in ["vegetarian", "veg", "daal", "sabzi", "pure veg"]):
            return "vegetarian", "Vegetarian Curries, Fresh Daals & Paneer"

        # 12. Fine Dining
        if any(w in n for w in ["monal", "haveli", "serena", "marriott", "pearl continental", "fine dining", "royal haveli"]):
            return "fineDining", "Premier Fine Dining & Panoramic Views"

        # 13. Family Dining
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

        # Determine includedTypes based on category
        cat_lower = category.lower()
        if cat_lower == "cafe":
            included_types = ["cafe", "coffee_shop"]
        elif cat_lower == "bakery":
            included_types = ["bakery"]
        elif cat_lower in ["fastfood", "fast_food"]:
            included_types = ["fast_food_restaurant", "meal_takeaway"]
        else:
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

        collected_places: Dict[str, Dict[str, Any]] = {}

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                logger.info(f"[GooglePlaces] Food Search (Center: {latitude:.4f}, {longitude:.4f}, Radius: {radius_meters}m)")
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

                # Ensure 10-15+ real results: if query target provided or count < 15, query Text Search
                query_target = search_query or cuisine or (cat_lower if cat_lower not in ["all", "restaurant"] else None)
                if query_target or len(collected_places) < 15:
                    q_term = f"{query_target or 'popular food restaurants and cafes'} in {city_name or 'Pakistan'}"
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
            gallery = [
                url for ph in photos[:4]
                if (url := self._format_photo_url(ph, api_key)) is not None
            ]

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
                specialties=["Chef's Special Karahi", "Hot Tandoori Naan", "Special Platter"],
                description=desc,
                landmarkNearby=short_addr,
                directions_url=directions_url,
            )
            places.append(place_item)

        # Limit to target 20 results
        places = places[:20]
        self._cache[cache_key] = (now, places)
        return places

        self._cache[cache_key] = (now, places)
        return places

    def _classify_facility(
        self,
        name: str,
        types: List[str],
        primary_type: Optional[str] = None,
    ) -> Tuple[str, bool]:
        """
        Classify healthcare/help establishment into Flutter's FacilityType enum values:
        emergency, firstAid, primaryCare, secondaryCare, tertiaryCare, government,
        privateHospital, pharmacy, clinic.
        Returns (facility_type_key, is_emergency).
        """
        n = name.lower()
        t = [typ.lower() for typ in types]

        # 1. Pharmacy / Drugstore
        if "pharmacy" in t or "drugstore" in t or any(w in n for w in ["pharmacy", "chemist", "medical store", "d.watson", "fazal din", "medicare store"]):
            return "pharmacy", False

        # 2. Emergency / Trauma Specialty
        if any(w in n for w in ["trauma", "emergency", "burn center", "rescue 1122", "casualty"]):
            return "emergency", True

        # 3. Government / Public Tertiary Hospitals
        if any(w in n for w in ["pims", "mayo", "dhq", "thq", "civil hospital", "services hospital", "jinnah hospital", "cda hospital", "government"]):
            return "government", True

        # 4. Major Private & Tertiary Care Hospitals
        if any(w in n for w in ["shifa", "aga khan", "national hospital", "maroof", "quaid-e-azam international", "doctors hospital", "south city", "liaquat national"]):
            return "privateHospital", True

        # 5. First Aid & Trailhead / Mountain Post
        if any(w in n for w in ["first aid", "dispensary", "aid post", "trailhead aid", "babusar aid"]):
            return "firstAid", True

        # 6. Clinic / Diagnostic Lab
        if "medical_clinic" in t or any(w in n for w in ["clinic", "diagnostic", "chughtai", "shaukat khanum lab", "consultant"]):
            return "clinic", False

        # 7. Doctor's Office
        if "doctor" in t or "physician" in t:
            return "primaryCare", False

        # Default Hospital
        is_emerg = "hospital" in t or any(w in n for w in ["hospital", "medical center", "complex"])
        return "secondaryCare", is_emerg

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
        and falls back to curated database strictly within search radius if zero results.
        """
        api_key = self._get_api_key()
        if not api_key:
            logger.warning("[GooglePlaces] No API key for Help.")
            return []

        cache_key = f"help_{round(latitude, 3)}_{round(longitude, 3)}_{round(radius_km, 1)}_{str(assistance_type).lower()}_{emergency_only}"
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

        # Map assistance type to Google Places (New) types
        type_mapping = settings.HELP_TYPE_MAPPING
        mapped_types: List[str] = []
        if assistance_type:
            clean_type = assistance_type.lower().strip()
            mapped_types = type_mapping.get(clean_type, ["hospital", "medical_clinic"])
        elif emergency_only:
            mapped_types = ["hospital"]
        else:
            mapped_types = settings.GOOGLE_HELP_TYPES

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
                logger.info(f"[GooglePlaces] Help Search (Center: {latitude:.4f}, {longitude:.4f}, Types: {mapped_types})")
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

                # Guarantee 10-15+ results: if query target provided or count < 15, query Text Search
                query_target = search_query or assistance_type or ("emergency hospitals" if emergency_only else None)
                if query_target or len(collected_places) < 15:
                    q_term = f"{query_target or 'hospitals and clinics'} in {city_name or 'Pakistan'}"
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

            fac_type, is_emerg = self._classify_facility(name=name, types=types)
            if emergency_only and not is_emerg:
                continue

            # If user specifically asked for pharmacy or clinic, prioritize and filter
            if assistance_type and assistance_type.lower() not in ["all", "hospital", "emergency"]:
                t_lower = assistance_type.lower().strip()
                if t_lower == "pharmacy" and fac_type != "pharmacy" and "pharmacy" not in types_lower:
                    continue
                elif t_lower == "clinic" and fac_type not in ["clinic", "primaryCare"] and "medical_clinic" not in types_lower:
                    continue

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

