import logging
from typing import List, Optional
from fastapi import APIRouter, Query, status
from app.core.config import settings
from app.models.food import FoodMapPinItem, FoodPlaceItem, FoodSearchRequest, FoodSearchResponse
from app.services.google_places_service import google_places_service
from app.services.google_routes_service import google_routes_service
from app.services.location_resolution_service import location_resolution_service
from app.utils.geo import is_valid_coordinates

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/food", tags=["Food & Dining"])


async def _execute_food_search(
    city: Optional[str] = None,
    location_name: Optional[str] = None,
    user_latitude: Optional[float] = None,
    user_longitude: Optional[float] = None,
    latitude: Optional[float] = None,
    longitude: Optional[float] = None,
    radius_km: Optional[float] = 30.0,
    category: Optional[str] = "all",
    cuisine: Optional[str] = None,
    sort_by: Optional[str] = "rating",
    search_query: Optional[str] = None,
) -> FoodSearchResponse:
    """
    Core live food & dining discovery engine for Pakistan destinations or user's GPS.
    
    Location Separation:
    1. CURRENT DEVICE GPS (user_latitude, user_longitude):
       - Origin for Google Routes matrix & Google Maps turn-by-turn directions.
    2. SEARCH CENTER & RADIUS (latitude, longitude, radius_km):
       - Controls where Google Places searches for restaurants within 25-30 km.
    3. FOOD DESTINATION (place.latitude, place.longitude):
       - Exact Google Places coordinates for markers, cards, and directions.
    """
    # 1. Determine Location Intent
    raw_location = city or location_name or "Current Location (GPS)"
    resolved_location_name = raw_location.strip()
    is_gps_mode = (
        "current location" in resolved_location_name.lower()
        or "gps" in resolved_location_name.lower()
        or "nearby" in resolved_location_name.lower()
    )

    # 2. Resolve User Device GPS Origin
    user_gps_lat = user_latitude
    user_gps_lon = user_longitude

    if user_gps_lat is None or user_gps_lon is None:
        if is_gps_mode:
            user_gps_lat = latitude or 33.6844
            user_gps_lon = longitude or 73.0479

    # 3. Resolve Search Center Coordinates
    if is_gps_mode:
        search_lat = latitude if latitude is not None else (user_gps_lat or 33.6844)
        search_lon = longitude if longitude is not None else (user_gps_lon or 73.0479)
    else:
        if latitude is not None and longitude is not None and is_valid_coordinates(latitude, longitude):
            search_lat = latitude
            search_lon = longitude
        else:
            try:
                resolved = await location_resolution_service.resolve_destination(resolved_location_name)
                search_lat = resolved.latitude
                search_lon = resolved.longitude
            except Exception as e:
                logger.warning(f"[Food] Coordinate resolution error for '{resolved_location_name}': {e}")
                search_lat = 33.6844
                search_lon = 73.0479

    # Configurable 25-30 km radius
    effective_radius = float(radius_km or 30.0)
    if effective_radius < 10.0:
        effective_radius = 30.0
    elif effective_radius > 40.0:
        effective_radius = 30.0

    cat_clean = (category or "all").strip()
    cuisine_clean = cuisine.strip() if cuisine and cuisine.strip() else None
    effective_sort = (sort_by or "rating").lower().strip()

    print("\n========== GOOGLE FOOD & ROUTES SEARCH ==========")
    print(f"Destination: {resolved_location_name}")
    print(f"Search Center: ({search_lat:.4f}, {search_lon:.4f}) | Radius: {effective_radius:.1f} km")
    print(f"Device GPS: ({user_gps_lat if user_gps_lat else 'N/A'}, {user_gps_lon if user_gps_lon else 'N/A'})")
    print(f"Category: {cat_clean} | Cuisine: {cuisine_clean}")
    print("=================================================\n")

    # 4. Query Google Places API (New) for Live Food Places
    try:
        all_places = await google_places_service.search_nearby_food(
            latitude=search_lat,
            longitude=search_lon,
            radius_km=effective_radius,
            category=cat_clean,
            cuisine=cuisine_clean,
            city_name=resolved_location_name,
            origin_lat=user_gps_lat,
            origin_lon=user_gps_lon,
            search_query=search_query,
        )
    except Exception as e:
        logger.error(f"[Food] Google Places search exception: {e}")
        all_places = []

    is_fallback = False

    # 5. Strict Category & Cuisine Filtering (Zero-Tolerance: No generic fallback when specific cuisine requested)
    filtered_places: List[FoodPlaceItem] = []
    
    active_cuisine = (cuisine_clean or "").strip()
    if active_cuisine.lower() in ["all", "all cuisines"]:
        active_cuisine = ""
        
    active_category = (cat_clean or "").strip()
    if active_category.lower() in ["all", "all cuisines"]:
        active_category = ""

    if not active_cuisine and not active_category:
        filtered_places = all_places
    else:
        matched: List[FoodPlaceItem] = []
        for p in all_places:
            p_cat = p.category.lower().replace(" ", "").replace("_", "")
            p_cuis = p.cuisine.lower()
            p_name = p.name.lower()
            p_specs = [s.lower() for s in p.specialties]

            matches_cuisine = False
            if active_cuisine:
                c_low = active_cuisine.lower()
                c_norm = c_low.replace(" ", "").replace("_", "")
                matches_cuisine = (
                    c_low in p_cuis
                    or c_norm in p_cat
                    or c_low in p_name
                    or any(c_low in s for s in p_specs)
                )

            matches_category = False
            if active_category:
                cat_low = active_category.lower()
                cat_norm = cat_low.replace(" ", "").replace("_", "")
                matches_category = (
                    cat_norm in p_cat
                    or cat_low in p_cuis
                    or cat_low in p_name
                    or any(cat_low in s for s in p_specs)
                )

            if active_cuisine and active_category:
                if matches_cuisine or matches_category:
                    matched.append(p)
            elif active_cuisine:
                if matches_cuisine:
                    matched.append(p)
            elif active_category:
                if matches_category:
                    matched.append(p)

        # Strict: NEVER fall back to generic all_places when specialized query yields zero records!
        filtered_places = matched

    # 6. Apply Text Query Filter if provided
    if search_query and search_query.strip():
        q = search_query.lower().strip()
        filtered_places = [
            p for p in filtered_places
            if q in p.name.lower()
            or q in p.cuisine.lower()
            or (p.address and q in p.address.lower())
            or any(q in s.lower() for s in p.specialties)
        ]

    # Limit to top 25 results for routing calculation
    target_places = filtered_places[:25]

    # Required backend debug logging
    logger.info(
        f"[Food] Search request: city={resolved_location_name}, cuisine={cuisine_clean}, "
        f"category={cat_clean}, lat={search_lat}, lon={search_lon} -> found {len(target_places)} items"
    )

    # 7. Compute Real Road Distance & Driving ETA via Google Routes API
    if target_places and user_gps_lat is not None and user_gps_lon is not None:
        try:
            target_places = await google_routes_service.compute_batch_driving_matrix(
                origin_lat=user_gps_lat,
                origin_lon=user_gps_lon,
                items=target_places,
            )
        except Exception as e:
            logger.error(f"[Food] Google Routes Matrix error: {e}")

    # 8. Apply Strict Sorting
    if effective_sort == "nearest":
        target_places.sort(
            key=lambda p: p.distance_km if p.distance_km is not None else p.distanceKm
        )
    elif effective_sort == "rating":
        target_places.sort(key=lambda p: p.rating, reverse=True)
    elif effective_sort == "reviews":
        target_places.sort(key=lambda p: p.reviewCount, reverse=True)
    elif effective_sort in ["price_low", "pricelow"]:
        target_places.sort(key=lambda p: p.avgCostPerPersonPkr)
    elif effective_sort in ["price_high", "pricehigh"]:
        target_places.sort(key=lambda p: p.avgCostPerPersonPkr, reverse=True)

    # 9. Generate Map Pins with exact coordinates
    map_pins: List[FoodMapPinItem] = []
    for p in target_places:
        map_pins.append(
            FoodMapPinItem(
                id=p.id,
                name=p.name,
                latitude=p.latitude,
                longitude=p.longitude,
                category=p.category,
                rating=p.rating,
                cuisine=p.cuisine,
            )
        )

    header_status = f"{len(target_places)} Food Spots Mapped • {effective_radius:.0f} km radius"

    return FoodSearchResponse(
        success=True,
        city=resolved_location_name,
        location_name=resolved_location_name,
        total_found=len(target_places),
        header_status=header_status,
        center_latitude=search_lat,
        center_longitude=search_lon,
        radius_km=effective_radius,
        map_pins=map_pins,
        places=target_places,
        is_fallback=is_fallback,
    )


@router.get(
    "/search",
    response_model=FoodSearchResponse,
    status_code=status.HTTP_200_OK,
    summary="Search Live Food & Dining with Google Places (GET)",
    description="Discovers live restaurants and dhabas via Google Places API (New) via GET query parameters.",
)
async def search_food_get(
    city: Optional[str] = Query(None, description="Destination city name"),
    location_name: Optional[str] = Query(None, description="Location label"),
    user_latitude: Optional[float] = Query(None, description="User device GPS latitude"),
    user_longitude: Optional[float] = Query(None, description="User device GPS longitude"),
    latitude: Optional[float] = Query(None, description="Search center latitude"),
    longitude: Optional[float] = Query(None, description="Search center longitude"),
    radius_km: Optional[float] = Query(30.0, description="Search radius in km"),
    category: Optional[str] = Query("all", description="Category filter"),
    cuisine: Optional[str] = Query(None, description="Cuisine query filter"),
    sort_by: Optional[str] = Query("rating", description="Sort option"),
    search_query: Optional[str] = Query(None, description="Text search query"),
):
    """GET handler with query parameters."""
    return await _execute_food_search(
        city=city,
        location_name=location_name,
        user_latitude=user_latitude,
        user_longitude=user_longitude,
        latitude=latitude,
        longitude=longitude,
        radius_km=radius_km,
        category=category,
        cuisine=cuisine,
        sort_by=sort_by,
        search_query=search_query,
    )


@router.post(
    "/search",
    response_model=FoodSearchResponse,
    status_code=status.HTTP_200_OK,
    summary="Search Live Food & Dining with Google Places (POST)",
    description="Discovers live restaurants and dhabas via Google Places API (New) via POST JSON body.",
)
async def search_food(
    req: FoodSearchRequest,
    cuisine: Optional[str] = Query(None, description="Optional cuisine query parameter fallback"),
    category: Optional[str] = Query(None, description="Optional category query parameter fallback"),
    city: Optional[str] = Query(None, description="Optional city query parameter fallback"),
):
    """POST handler with JSON payload and query parameter fallback."""
    effective_cuisine = req.cuisine or cuisine
    effective_category = req.category if req.category and req.category != "all" else (category or req.category or "all")
    effective_city = req.city or city
    return await _execute_food_search(
        city=effective_city,
        location_name=req.location_name,
        user_latitude=req.user_latitude,
        user_longitude=req.user_longitude,
        latitude=req.latitude,
        longitude=req.longitude,
        radius_km=req.radius_km,
        category=effective_category,
        cuisine=effective_cuisine,
        sort_by=req.sort_by,
        search_query=req.search_query,
    )
