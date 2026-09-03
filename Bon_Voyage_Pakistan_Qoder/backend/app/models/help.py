from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field


class HelpMapPinItem(BaseModel):
    """Map Pin item for medical and emergency facility markers."""
    id: str = Field(..., description="Unique Facility ID")
    name: str = Field(..., description="Facility name")
    latitude: float = Field(..., description="Exact latitude")
    longitude: float = Field(..., description="Exact longitude")
    type: str = Field(default="primaryCare", description="Facility type key")
    is_emergency: bool = Field(default=False, description="Emergency facility indicator")
    phone: Optional[str] = Field(default=None, description="Phone contact")


class HelpFacilityItem(BaseModel):
    """Complete Medical & Emergency Facility Model matching Flutter contract."""
    id: str = Field(..., description="Unique identifier (Google Place ID or curated ID)")
    name: str = Field(..., description="Facility name")
    type: str = Field(default="primaryCare", description="Facility type matching FacilityType enum in Flutter")
    latitude: float = Field(..., description="Exact latitude from Google Places")
    longitude: float = Field(..., description="Exact longitude from Google Places")
    address: str = Field(default="", description="Full or short address")
    city: Optional[str] = Field(default=None, description="City or destination")
    landmarkNearby: Optional[str] = Field(default=None, description="Nearby landmark or area")
    
    # Distance & ETA fields (supports camelCase and snake_case for Flutter deserialization)
    distance: str = Field(default="Nearby", description="Human-readable driving distance")
    estimatedTravelTime: str = Field(default="5 mins", description="Human-readable driving travel time")
    distance_km: Optional[float] = Field(default=None, description="Numeric driving distance in km")
    eta_minutes: Optional[int] = Field(default=None, description="Numeric driving duration in minutes")
    
    # Emergency & Operating Status
    phone: str = Field(default="1122", description="Emergency / contact phone number")
    isEmergency: bool = Field(default=False, description="Emergency 24/7 capability")
    isOpen: bool = Field(default=True, description="Open status")
    operatingHours: str = Field(default="24/7 Open", description="Operating hours summary")
    emergencyBedStatus: str = Field(default="Available", description="Triage / bed status")
    
    # Rating & Reviews
    rating: float = Field(default=4.5, description="Google user rating")
    reviewCount: int = Field(default=100, description="Total review count")
    
    # Clinical Services & Specialties
    services: List[str] = Field(default_factory=list, description="Available healthcare services")
    
    # Navigation
    directions_url: str = Field(default="", description="Google Maps turn-by-turn driving URL")


class HelpSearchRequest(BaseModel):
    """Request model for medical & help facilities search endpoint."""
    city: Optional[str] = Field(default=None, description="Selected destination city")
    location_name: Optional[str] = Field(default=None, description="Display location label")
    user_latitude: Optional[float] = Field(default=None, description="User GPS latitude for driving distance & ETA")
    user_longitude: Optional[float] = Field(default=None, description="User GPS longitude for driving distance & ETA")
    latitude: Optional[float] = Field(default=None, description="Search center latitude")
    longitude: Optional[float] = Field(default=None, description="Search center longitude")
    radius_km: Optional[float] = Field(default=30.0, description="Search radius in km (default 30 km)")
    assistance_type: Optional[str] = Field(default=None, description="Assistance category / type")
    emergency_only: bool = Field(default=False, description="Filter for 24/7 emergency facilities only")
    sort_by: Optional[str] = Field(default="nearest", description="Sort option: nearest, rating, reviews")
    search_query: Optional[str] = Field(default=None, description="Keyword search query")


class HelpSearchResponse(BaseModel):
    """Response model for help facilities search endpoint."""
    success: bool = True
    city: str
    location_name: str
    total_found: int = 0
    header_status: str = ""
    center_latitude: float
    center_longitude: float
    radius_km: float = 30.0
    map_pins: List[HelpMapPinItem] = Field(default_factory=list)
    facilities: List[HelpFacilityItem] = Field(default_factory=list)
    is_fallback: bool = False
    error: Optional[str] = None
