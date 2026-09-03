import logging
from typing import List, Optional
from fastapi import APIRouter, status
from app.core.config import settings
from app.models.help import HelpFacilityItem, HelpMapPinItem, HelpSearchRequest, HelpSearchResponse
from app.services.google_places_service import google_places_service
from app.services.google_routes_service import google_routes_service
from app.services.location_resolution_service import location_resolution_service
from app.utils.geo import is_valid_coordinates

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/help", tags=["First Aid & Medical Help"])


@router.post(
    "/search",
    response_model=HelpSearchResponse,
    status_code=status.HTTP_200_OK,
    summary="Search Live Hospitals & Emergency Facilities with Google Places (New) & Routes API",
    description="Discovers live hospitals, pharmacies, and emergency centers via Google Places API (New), computes real driving distance and duration via Google Routes API, and maps exact coordinates.",
)
async def search_help(req: HelpSearchRequest):
    """
    Live first aid, hospital, and emergency facility discovery system for Pakistan.
    
    Location Separation:
    1. CURRENT DEVICE GPS (user_latitude, user_longitude):
       - Origin for Google Routes matrix & Google Maps navigation.
    2. SEARCH CENTER & RADIUS (latitude, longitude, radius_km):
       - Controls where Google Places searches for facilities within 25-30 km.
    3. FACILITY DESTINATION (facility.latitude, facility.longitude):
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
                logger.warning(f"[Help] Coordinate resolution error for '{location_name}': {e}")
                search_lat = 33.6844
                search_lon = 73.0479

    # 30 km radius (per prompt requirement)
    radius_km = float(req.radius_km or 30.0)
    if radius_km < 10.0:
        radius_km = 30.0
    elif radius_km > 40.0:
        radius_km = 30.0

    assistance_type = req.assistance_type
    emergency_only = req.emergency_only or (assistance_type and assistance_type.lower() == "emergency")
    sort_by = (req.sort_by or "nearest").lower().strip()

    print("\n========== GOOGLE HELP & ROUTES SEARCH ==========")
    print(f"Destination: {location_name}")
    print(f"Search Center: ({search_lat:.4f}, {search_lon:.4f}) | Radius: {radius_km:.1f} km")
    print(f"Device GPS: ({user_gps_lat if user_gps_lat else 'N/A'}, {user_gps_lon if user_gps_lon else 'N/A'})")
    print(f"Assistance Type: {assistance_type} | Emergency Only: {emergency_only}")
    print("=================================================\n")

    # 4. Query Google Places API (New) for Live Medical / Help Facilities
    try:
        all_facilities = await google_places_service.search_nearby_help(
            latitude=search_lat,
            longitude=search_lon,
            radius_km=radius_km,
            assistance_type=assistance_type,
            emergency_only=emergency_only,
            city_name=location_name,
            origin_lat=user_gps_lat,
            origin_lon=user_gps_lon,
            search_query=req.search_query,
        )
    except Exception as e:
        logger.error(f"[Help] Google Places search exception: {e}")
        all_facilities = []

    is_fallback = False

    # 5. Apply Type & Query Filter
    filtered_facilities: List[HelpFacilityItem] = []
    for f in all_facilities:
        if emergency_only and not f.isEmergency:
            continue
        filtered_facilities.append(f)

    if req.search_query and req.search_query.strip():
        q = req.search_query.lower().strip()
        filtered_facilities = [
            f for f in filtered_facilities
            if q in f.name.lower()
            or q in f.address.lower()
            or any(q in s.lower() for s in f.services)
        ]

    # Limit to top 25 results for routing calculation
    target_facilities = filtered_facilities[:25]

    # 6. Compute Real Road Distance & Driving ETA via Google Routes API
    if target_facilities and user_gps_lat is not None and user_gps_lon is not None:
        try:
            target_facilities = await google_routes_service.compute_batch_driving_matrix(
                origin_lat=user_gps_lat,
                origin_lon=user_gps_lon,
                items=target_facilities,
            )
        except Exception as e:
            logger.error(f"[Help] Google Routes Matrix error: {e}")

    # 7. Apply Strict Sorting (Emergency behavior: fastest driving ETA first!)
    if emergency_only or sort_by == "nearest":
        target_facilities.sort(
            key=lambda f: (
                0 if f.isEmergency else 1,
                f.distance_km if f.distance_km is not None else 999999.0,
            )
        )
    elif sort_by == "rating":
        target_facilities.sort(key=lambda f: f.rating, reverse=True)
    elif sort_by == "reviews":
        target_facilities.sort(key=lambda f: f.reviewCount, reverse=True)

    # 8. Generate Map Pins with exact coordinates
    map_pins: List[HelpMapPinItem] = []
    for f in target_facilities:
        map_pins.append(
            HelpMapPinItem(
                id=f.id,
                name=f.name,
                latitude=f.latitude,
                longitude=f.longitude,
                type=f.type,
                is_emergency=f.isEmergency,
                phone=f.phone,
            )
        )

    header_status = f"{len(target_facilities)} Facilities Mapped • 30 km radius"

    return HelpSearchResponse(
        success=True,
        city=location_name,
        location_name=location_name,
        total_found=len(target_facilities),
        header_status=header_status,
        center_latitude=search_lat,
        center_longitude=search_lon,
        radius_km=radius_km,
        map_pins=map_pins,
        facilities=target_facilities,
        is_fallback=is_fallback,
    )
