import logging
from fastapi import APIRouter, status
from app.models.routes import RouteRequest, RouteResponse
from app.services.google_routes_service import google_routes_service
from app.utils.geo import is_valid_coordinates

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/routes", tags=["Routing & Distance"])


@router.post(
    "",
    response_model=RouteResponse,
    status_code=status.HTTP_200_OK,
    summary="Compute Real Driving Road Distance & ETA",
    description="Calculates exact driving road distance and travel duration between origin and destination via Google Routes API v2 / Geoapify matrix.",
)
async def compute_route(req: RouteRequest):
    """Compute driving distance and travel duration between origin and destination."""
    origin_lat = req.origin.latitude
    origin_lon = req.origin.longitude
    dest_lat = req.destination.latitude
    dest_lon = req.destination.longitude

    if not is_valid_coordinates(origin_lat, origin_lon) or not is_valid_coordinates(dest_lat, dest_lon):
        return RouteResponse(
            success=False,
            error="Invalid coordinates provided for origin or destination.",
            directions_url=google_routes_service.generate_directions_url(origin_lat, origin_lon, dest_lat, dest_lon),
        )

    try:
        route_data = await google_routes_service.compute_single_route(
            origin_lat=origin_lat,
            origin_lon=origin_lon,
            dest_lat=dest_lat,
            dest_lon=dest_lon,
            travel_mode=req.travel_mode or "DRIVE",
        )

        return RouteResponse(
            success=True,
            distance_meters=route_data.get("distance_meters"),
            duration_seconds=route_data.get("duration_seconds"),
            distance_km=route_data.get("distance_km"),
            eta_minutes=route_data.get("eta_minutes"),
            formatted_distance=route_data.get("formatted_distance"),
            formatted_eta=route_data.get("formatted_eta"),
            directions_url=route_data.get("directions_url"),
        )
    except Exception as e:
        logger.error(f"[RoutesAPI] Error computing route: {e}")
        return RouteResponse(
            success=False,
            error=str(e),
            directions_url=google_routes_service.generate_directions_url(origin_lat, origin_lon, dest_lat, dest_lon),
        )
