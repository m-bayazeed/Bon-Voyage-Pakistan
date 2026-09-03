from typing import Optional
from pydantic import BaseModel, Field


class RoutePoint(BaseModel):
    """Geographic point with latitude and longitude."""
    latitude: float = Field(..., description="Latitude coordinate")
    longitude: float = Field(..., description="Longitude coordinate")


class RouteRequest(BaseModel):
    """Request to compute driving distance and duration."""
    origin: RoutePoint = Field(..., description="Starting GPS waypoint")
    destination: RoutePoint = Field(..., description="Destination GPS waypoint")
    travel_mode: str = Field(default="DRIVE", description="Travel mode e.g. DRIVE, WALK, BICYCLE")


class RouteResponse(BaseModel):
    """Calculated driving distance and travel duration."""
    success: bool = True
    distance_meters: Optional[int] = Field(default=None, description="Driving distance in meters")
    duration_seconds: Optional[int] = Field(default=None, description="Driving duration in seconds")
    distance_km: Optional[float] = Field(default=None, description="Distance in kilometers")
    eta_minutes: Optional[int] = Field(default=None, description="Estimated travel time in minutes")
    formatted_distance: Optional[str] = Field(default=None, description="Human-readable distance (e.g. '4.7 km')")
    formatted_eta: Optional[str] = Field(default=None, description="Human-readable ETA (e.g. '12 mins')")
    directions_url: Optional[str] = Field(default=None, description="Direct Google Maps turn-by-turn navigation URL")
    error: Optional[str] = None
