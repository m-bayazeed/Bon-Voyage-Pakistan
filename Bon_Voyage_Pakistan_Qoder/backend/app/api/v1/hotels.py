import logging
from urllib.parse import quote
from typing import List, Optional
import httpx
from fastapi import APIRouter, Query, Response, status
from app.core.config import settings
from app.models.hotel import (
    CitiesResponse,
    CityItem,
    GeocodeResponse,
    GeocodeResultItem,
    HotelGeocodeRequest,
    HotelSearchRequest,
    HotelSearchResponse,
    LocationResolutionRequest,
    MapPinItem,
    ResolvedLocationResponse,
    StayItem,
)
from app.services.curated_hotel_database import get_curated_fallback_stays
from app.services.google_places_service import google_places_service
from app.services.google_routes_service import google_routes_service
from app.services.hotel_enrichment_service import hotel_enrichment_service
from app.services.location_resolution_service import location_resolution_service
from app.utils.geo import format_price_tag, is_valid_coordinates

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/hotels", tags=["Hotels & Stays"])


@router.post(
    "/resolve-location",
    response_model=ResolvedLocationResponse,
    status_code=status.HTTP_200_OK,
    summary="Dynamically Resolve Destination Coordinates & Whole-City Radius",
    description="Resolves geographic center coordinates and recommended search radius for any Pakistani destination.",
)
async def resolve_location(req: LocationResolutionRequest):
    """Dynamically resolve destination name into geographic coordinates and radius."""
    try:
        resolved = await location_resolution_service.resolve_destination(req.destination)
        return ResolvedLocationResponse(
            success=True,
            name=resolved.name,
            country=resolved.country,
            latitude=resolved.latitude,
            longitude=resolved.longitude,
            radius_km=resolved.radius_km,
            is_ambiguous=resolved.is_ambiguous,
        )
    except Exception as e:
        logger.error(f"[Hotels] Error resolving location for '{req.destination}': {e}")
        return ResolvedLocationResponse(
            success=False,
            name=req.destination,
            country="Pakistan",
            latitude=33.6844,
            longitude=73.0479,
            error=str(e),
        )


@router.post(
    "/search",
    response_model=HotelSearchResponse,
    status_code=status.HTTP_200_OK,
    summary="Search Real Accommodations with Google Places (New) & Google Routes API",
    description="Discovers live hotels using Google Places API (New), calculates actual road distance and driving ETA via Google Routes API, and enriches with Gemini.",
)
async def search_hotels(req: HotelSearchRequest):
    """
    Search real accommodations for any Pakistani destination or current GPS.
    
    Location separation logic:
    1. CURRENT DEVICE GPS:
       - Origin for Google Routes matrix & external navigation directions URL.
       - Source: req.user_latitude, req.user_longitude (defaults to 33.6844, 73.0479 if in GPS mode).
    2. SEARCH CENTER & RADIUS:
       - For City: city coordinates (e.g. Lahore, Karachi, Hunza), NOT the user's GPS!
       - For Current Location: user's GPS coordinates with 15-20km radius.
    3. HOTEL DESTINATION:
       - Actual Google Places coordinates.
    """
    # 1. Determine Location Intent
    raw_location = req.city or req.location_name or "Current Location (GPS)"
    location_name = raw_location.strip()
    is_gps_mode = (
        "current location" in location_name.lower()
        or "gps" in location_name.lower()
        or "nearby" in location_name.lower()
    )

    # 2. Resolve User Device GPS Origin (Used strictly for road routing & navigation origin)
    user_gps_lat = req.user_latitude
    user_gps_lon = req.user_longitude

    if user_gps_lat is None or user_gps_lon is None:
        if is_gps_mode:
            user_gps_lat = req.latitude or 33.6844
            user_gps_lon = req.longitude or 73.0479

    # 3. Resolve Search Center Coordinates & Radius
    if is_gps_mode:
        search_lat = req.latitude if req.latitude is not None else (user_gps_lat or 33.6844)
        search_lon = req.longitude if req.longitude is not None else (user_gps_lon or 73.0479)
        radius_km = req.radius_km or settings.CURRENT_LOCATION_RADIUS_KM
    else:
        # City selection: MUST center on the selected city coordinates
        if req.latitude is not None and req.longitude is not None and is_valid_coordinates(req.latitude, req.longitude):
            search_lat = req.latitude
            search_lon = req.longitude
        else:
            try:
                resolved = await location_resolution_service.resolve_destination(location_name)
                search_lat = resolved.latitude
                search_lon = resolved.longitude
            except Exception as e:
                logger.warning(f"[Hotels] Coordinate resolution failed for '{location_name}': {e}")
                search_lat = 33.6844
                search_lon = 73.0479

        if req.radius_km is not None and req.radius_km >= 25.0:
            radius_km = req.radius_km
        else:
            try:
                resolved = await location_resolution_service.resolve_destination(location_name)
                radius_km = resolved.radius_km
            except Exception:
                radius_km = settings.CITY_SEARCH_RADIUS_KM

    category = (req.category or "all").lower().strip()
    # Normalize category aliases
    if category in ["pods", "campsite", "camping"]:
        category = "glamping"
    elif category in ["heritage"]:
        category = "boutique"

    sort_by = (req.sort_by or "nearest").lower().strip()
    if sort_by in ["price_low", "pricelow"]:
        sort_by = "price_low_high"
    elif sort_by in ["price_high", "pricehigh"]:
        sort_by = "price_high_low"

    # Development Debug Logging
    print("\n========== GOOGLE HOTELS & ROUTES SEARCH ==========")
    print(f"Destination: {location_name}")
    print(f"Search Center: ({search_lat:.4f}, {search_lon:.4f})")
    print(f"User Device GPS: ({user_gps_lat if user_gps_lat else 'N/A'}, {user_gps_lon if user_gps_lon else 'N/A'})")
    print(f"Search Radius: {radius_km:.1f} km")
    print(f"Category: {category}")
    print(f"Sort Option: {sort_by}")
    print("==================================================\n")

    # 4. Query Google Places API (New) for Live Hotel Discovery
    is_fallback = False
    try:
        all_stays = await google_places_service.search_nearby_stays(
            latitude=search_lat,
            longitude=search_lon,
            radius_km=radius_km,
            category=category,
            city_name=location_name,
            origin_lat=user_gps_lat,
            origin_lon=user_gps_lon,
        )
    except Exception as e:
        logger.error(f"[Hotels] Google Places query exception: {e}. Falling back to curated database.")
        all_stays = get_curated_fallback_stays(
            city_name=location_name,
            category=category,
            origin_lat=user_gps_lat,
            origin_lon=user_gps_lon,
        )
        is_fallback = True

    if not all_stays:
        all_stays = get_curated_fallback_stays(
            city_name=location_name,
            category=category,
            origin_lat=user_gps_lat,
            origin_lon=user_gps_lon,
            search_lat=search_lat,
            search_lon=search_lon,
            radius_km=radius_km,
        )
        is_fallback = True
    else:
        is_fallback = any(s.id.startswith("fallback_") for s in all_stays)

    # 5. Filter by Category & Stays per Category
    filtered_stays: List[StayItem] = []
    if category == "all":
        # Group to provide balanced representation across luxury, resort, boutique, budget, glamping
        cat_groups = {"luxury": [], "resort": [], "boutique": [], "budget": [], "glamping": []}
        others = []
        for s in all_stays:
            if s.category in cat_groups:
                cat_groups[s.category].append(s)
            else:
                others.append(s)

        balanced: List[StayItem] = []
        # Take up to 3-4 per category if available
        for c_key, items in cat_groups.items():
            balanced.extend(items[:4])
        # Add remaining if space permits
        for s in all_stays:
            if s not in balanced and len(balanced) < 25:
                balanced.append(s)
        filtered_stays = balanced if balanced else all_stays
    else:
        matched = [
            s for s in all_stays
            if s.category == category or (category == "glamping" and s.category in ["glamping", "pods"])
        ]
        filtered_stays = matched if matched else all_stays

    # 6. Apply Text Query Filter if provided
    if req.search_query and req.search_query.strip():
        q = req.search_query.lower().strip()
        filtered_stays = [
            s for s in filtered_stays
            if q in s.name.lower()
            or (s.address and q in s.address.lower())
            or (s.city and q in s.city.lower())
        ]

    # Limit to top results for Route calculation & AI enrichment
    target_stays = filtered_stays[:20]

    # 7. Compute Real Road Distance & Driving ETA via Google Routes API
    if target_stays and user_gps_lat is not None and user_gps_lon is not None:
        try:
            target_stays = await google_routes_service.compute_driving_matrix(
                origin_lat=user_gps_lat,
                origin_lon=user_gps_lon,
                stays=target_stays,
            )
        except Exception as e:
            logger.error(f"[Hotels] Google Routes Matrix error: {e}")

    # 8. Apply Strict Backend Sorting
    if sort_by == "nearest":
        target_stays.sort(
            key=lambda s: s.road_distance_km if s.road_distance_km is not None else (s.distance_km if s.distance_km is not None else 999999.0)
        )
    elif sort_by == "rating":
        target_stays.sort(key=lambda s: s.rating if s.rating is not None else -1.0, reverse=True)
    elif sort_by == "price_low_high":
        target_stays.sort(key=lambda s: s.price_per_night_pkr if s.price_per_night_pkr is not None else float("inf"))
    elif sort_by == "price_high_low":
        target_stays.sort(key=lambda s: s.price_per_night_pkr if s.price_per_night_pkr is not None else -1, reverse=True)

    # 9. Gemini Factual Enrichment (strictly grounded, no hallucinations)
    if target_stays and not is_fallback:
        try:
            target_stays = await hotel_enrichment_service.enrich_stays(
                stays=target_stays,
                center_label=location_name,
            )
        except Exception as e:
            logger.warning(f"[Hotels] Gemini enrichment skipped: {e}")

    # 10. Generate Map Pins for every returned stay (using exact coordinates)
    map_pins: List[MapPinItem] = []
    for s in target_stays:
        tag = format_price_tag(s.price_per_night_pkr)
        map_pins.append(
            MapPinItem(
                hotel_id=s.id,
                name=s.name,
                latitude=s.latitude,
                longitude=s.longitude,
                price_tag=tag,
                category=s.category,
            )
        )

    # Header status text
    header_status = f"{len(target_stays)} Stays Mapped • Tap pin for details"

    map_url = f"/api/v1/hotels/map.html?latitude={search_lat}&longitude={search_lon}&location_name={quote(location_name)}&radius_km={radius_km}&category={category}"

    return HotelSearchResponse(
        success=True,
        city=location_name,
        location_name=location_name,
        total_found=len(target_stays),
        header_status=header_status,
        center_latitude=search_lat,
        center_longitude=search_lon,
        radius_km=radius_km,
        map_pins=map_pins,
        stays=target_stays,
        map_url=map_url,
        is_fallback=is_fallback,
    )


@router.get(
    "/cities",
    response_model=CitiesResponse,
    status_code=status.HTTP_200_OK,
    summary="List Supported Destination Anchors",
    description="Returns list of popular anchor cities and destinations across Pakistan with their coordinates.",
)
async def get_cities():
    """Return supported Pakistani destination anchors."""
    cities = [
        CityItem(name=c["name"], latitude=c["latitude"], longitude=c["longitude"])
        for c in settings.SUPPORTED_CITIES
    ]
    return CitiesResponse(success=True, cities=cities)


@router.post(
    "/geocode",
    response_model=GeocodeResponse,
    status_code=status.HTTP_200_OK,
    summary="Geocode Custom Pakistani Destination",
    description="Resolves custom place name or landmark in Pakistan into latitude and longitude coordinates.",
)
async def geocode_location(req: HotelGeocodeRequest):
    """Geocode custom location search query dynamically."""
    q = req.query.strip()
    results: List[GeocodeResultItem] = []

    try:
        resolved = await location_resolution_service.resolve_destination(q)
        results.append(
            GeocodeResultItem(
                name=resolved.name,
                formatted_address=f"{resolved.name}, Pakistan",
                latitude=resolved.latitude,
                longitude=resolved.longitude,
                city=resolved.name,
            )
        )
    except Exception as e:
        logger.warning(f"[Hotels] Geocoding exception for '{q}': {e}")

    return GeocodeResponse(success=True, results=results)


@router.get(
    "/photos/{photo_name:path}",
    summary="Secure Proxy for Google Places Photo Media",
    description="Proxies Google Places photo media with caching headers without exposing API keys to public clients.",
)
async def get_photo_media(
    photo_name: str,
    max_height: int = Query(800, description="Max height px"),
    max_width: int = Query(1200, description="Max width px"),
):
    """Secure proxy for Google Places photos."""
    api_key = settings.GOOGLE_PLACES_API_KEY or settings.GEMINI_API_KEY
    if not api_key:
        return Response(status_code=status.HTTP_404_NOT_FOUND)

    google_photo_url = f"https://places.googleapis.com/v1/{photo_name}/media"
    params = {
        "maxHeightPx": max_height,
        "maxWidthPx": max_width,
        "key": api_key,
    }

    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            res = await client.get(google_photo_url, params=params)
            if res.status_code == 200:
                content_type = res.headers.get("content-type", "image/jpeg")
                return Response(
                    content=res.content,
                    media_type=content_type,
                    headers={"Cache-Control": "public, max-age=86400, immutable"},
                )
    except Exception as e:
        logger.warning(f"[Hotels] Error proxying Google Places photo '{photo_name}': {e}")

    return Response(status_code=status.HTTP_404_NOT_FOUND)


@router.get(
    "/tiles/{style}/{z}/{x}/{y}.png",
    response_class=Response,
    status_code=status.HTTP_200_OK,
    summary="Proxy Geoapify & OpenStreetMap Vector Map Tiles",
    description="Serves official Geoapify / OpenStreetMap map tiles with full street, road, and label details.",
)
async def get_map_tile(
    style: str,
    z: int,
    x: int,
    y: int,
):
    """Proxy official Geoapify map tiles (with streets & roads) or fallback to OpenStreetMap."""
    geoapify_key = settings.GEOAPIFY_API_KEY
    # Normalize requested style: osm-bright, osm-liberty, osm-carto
    tile_style = style if style in ["osm-bright", "osm-liberty", "osm-carto", "klokantech-basic"] else "osm-bright"

    try:
        async with httpx.AsyncClient(timeout=6.0) as client:
            if geoapify_key:
                tile_url = f"{settings.GEOAPIFY_TILES_BASE_URL}/{tile_style}/{z}/{x}/{y}.png?apiKey={geoapify_key}"
                res = await client.get(tile_url)
                if res.status_code == 200:
                    return Response(
                        content=res.content,
                        media_type="image/png",
                        headers={"Cache-Control": "public, max-age=86400, immutable"},
                    )

            # Fallback to standard OpenStreetMap
            osm_url = f"{settings.OPENSTREETMAP_TILES_URL}/{z}/{x}/{y}.png"
            res = await client.get(osm_url, headers={"User-Agent": "BonVoyagePakistan/1.0"})
            if res.status_code == 200:
                return Response(
                    content=res.content,
                    media_type="image/png",
                    headers={"Cache-Control": "public, max-age=86400, immutable"},
                )
    except Exception as e:
        logger.warning(f"[Hotels] Tile fetch error for {style}/{z}/{x}/{y}: {e}")

    return Response(status_code=status.HTTP_404_NOT_FOUND)


@router.get(
    "/tile-config",
    status_code=status.HTTP_200_OK,
    summary="Get Map Tile Service Config",
)
async def get_tile_config():
    """Return map tile template and attribution."""
    return {
        "success": True,
        "style_light": "osm-bright",
        "style_dark": "osm-bright",
        "attribution": "Powered by Geoapify | © OpenStreetMap contributors",
        "proxy_template": "/api/v1/hotels/tiles/{style}/{z}/{x}/{y}.png",
    }
