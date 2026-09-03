import logging
from typing import List, Optional
from fastapi import APIRouter, status
from app.core.config import settings
from app.models.food import FoodMapPinItem, FoodPlaceItem, FoodSearchRequest, FoodSearchResponse
from app.services.google_places_service import google_places_service
from app.services.google_routes_service import google_routes_service
from app.services.location_resolution_service import location_resolution_service
from app.utils.geo import is_valid_coordinates

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/food", tags=["Food & Dining"])


@router.post(
    "/search",
    response_model=FoodSearchResponse,
    status_code=status.HTTP_200_OK,
    summary="Search Live Food & Dining with Google Places (New) & Google Routes API",
    description="Discovers live restaurants and dhabas via Google Places API (New), computes real driving distance and duration via Google Routes API, and maps exact coordinates.",
)
async def search_food(req: FoodSearchRequest):
    """
    Live food & dining discovery system for Pakistan destinations or user's GPS.
    
    Location Separation:
    1. CURRENT DEVICE GPS (user_latitude, user_longitude):
       - Origin for Google Routes matrix & Google Maps turn-by-turn directions.
    2. SEARCH CENTER & RADIUS (latitude, longitude, radius_km):
       - Controls where Google Places searches for restaurants within 25-30 km.
    3. FOOD DESTINATION (place.latitude, place.longitude):
       - Exact Google Places coordinates for markers, cards, and directions.
    """
    # 1. Determine Location Intent
    raw_location = req.city or req.location_name or "Current Location (GPS)"
    location_name = raw_location.strip()
    is_gps_mode = (
        "current location" in location_name.lower()
        or "gps" in location_name.lower()
        or "nearby" in location_name.lower()
    )

    # 2. Resolve User Device GPS Origin
    user_gps_lat = req.user_latitude
    user_gps_lon = req.user_longitude

    if user_gps_lat is None or user_gps_lon is None:
        if is_gps_mode:
            user_gps_lat = req.latitude or 33.6844
            user_gps_lon = req.longitude or 73.0479

    # 3. Resolve Search Center Coordinates
    if is_gps_mode:
        search_lat = req.latitude if req.latitude is not None else (user_gps_lat or 33.6844)
        search_lon = req.longitude if req.longitude is not None else (user_gps_lon or 73.0479)
    else:
        if req.latitude is not None and req.longitude is not None and is_valid_coordinates(req.latitude, req.longitude):
            search_lat = req.latitude
            search_lon = req.longitude
        else:
            try:
                resolved = await location_resolution_service.resolve_destination(location_name)
                search_lat = resolved.latitude
                search_lon = resolved.longitude
            except Exception as e:
                logger.warning(f"[Food] Coordinate resolution error for '{location_name}': {e}")
                search_lat = 33.6844
                search_lon = 73.0479

    # Configurable 25-30 km radius (per prompt requirement)
    radius_km = float(req.radius_km or 30.0)
    if radius_km < 10.0:
        radius_km = 30.0
    elif radius_km > 40.0:
        radius_km = 30.0

    category = (req.category or "all").strip()
    cuisine = req.cuisine
    sort_by = (req.sort_by or "rating").lower().strip()

    print("\n========== GOOGLE FOOD & ROUTES SEARCH ==========")
    print(f"Destination: {location_name}")
    print(f"Search Center: ({search_lat:.4f}, {search_lon:.4f}) | Radius: {radius_km:.1f} km")
    print(f"Device GPS: ({user_gps_lat if user_gps_lat else 'N/A'}, {user_gps_lon if user_gps_lon else 'N/A'})")
    print(f"Category: {category} | Cuisine: {cuisine}")
    print("=================================================\n")

    # 4. Query Google Places API (New) for Live Food Places
    try:
        all_places = await google_places_service.search_nearby_food(
            latitude=search_lat,
            longitude=search_lon,
            radius_km=radius_km,
            category=category,
            cuisine=cuisine,
            city_name=location_name,
            origin_lat=user_gps_lat,
            origin_lon=user_gps_lon,
            search_query=req.search_query,
        )
    except Exception as e:
        logger.error(f"[Food] Google Places search exception: {e}")
        all_places = []

    is_fallback = False

    # 5. Filter by Category if specific
    filtered_places: List[FoodPlaceItem] = []
    if category.lower() in ["all", "all cuisines"]:
        filtered_places = all_places
    else:
        cat_norm = category.lower().replace(" ", "").replace("_", "")
        matched = [
            p for p in all_places
            if p.category.lower().replace(" ", "").replace("_", "") == cat_norm
            or cat_norm in p.category.lower()
            or cat_norm in p.cuisine.lower()
        ]
        filtered_places = matched if matched else all_places

    # 6. Apply Text Query Filter if provided
    if req.search_query and req.search_query.strip():
        q = req.search_query.lower().strip()
        filtered_places = [
            p for p in filtered_places
            if q in p.name.lower()
            or q in p.cuisine.lower()
            or (p.address and q in p.address.lower())
            or any(q in s.lower() for s in p.specialties)
        ]

    # Limit to top 25 results for routing calculation
    target_places = filtered_places[:25]

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
    if sort_by == "nearest":
        target_places.sort(
            key=lambda p: p.distance_km if p.distance_km is not None else p.distanceKm
        )
    elif sort_by == "rating":
        target_places.sort(key=lambda p: p.rating, reverse=True)
    elif sort_by == "reviews":
        target_places.sort(key=lambda p: p.reviewCount, reverse=True)
    elif sort_by in ["price_low", "pricelow"]:
        target_places.sort(key=lambda p: p.avgCostPerPersonPkr)
    elif sort_by in ["price_high", "pricehigh"]:
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

    header_status = f"{len(target_places)} Food Spots Mapped • 30 km radius"

    return FoodSearchResponse(
        success=True,
        city=location_name,
        location_name=location_name,
        total_found=len(target_places),
        header_status=header_status,
        center_latitude=search_lat,
        center_longitude=search_lon,
        radius_km=radius_km,
        map_pins=map_pins,
        places=target_places,
        is_fallback=is_fallback,
    )
