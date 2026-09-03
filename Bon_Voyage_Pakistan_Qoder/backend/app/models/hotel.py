from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field


class MapPinItem(BaseModel):
    """Map Pin model for interactive map markers."""
    hotel_id: str = Field(..., description="Unique Hotel Place ID")
    name: str = Field(..., description="Hotel property name")
    latitude: float = Field(..., description="Precise latitude")
    longitude: float = Field(..., description="Precise longitude")
    price_tag: str = Field(..., description="Compact price tag e.g. 'PKR 55k'")
    category: str = Field(default="all", description="Classification category")


class StayItem(BaseModel):
    """Complete Hotel & Stay Property Model."""
    id: str = Field(..., description="Unique identifier (Google Place ID or fallback ID)")
    name: str = Field(..., description="Hotel name")
    category: str = Field(default="all", description="Category: luxury, resort, boutique, budget, glamping, all")
    badge_label: str = Field(default="Hotel & Stay", description="Human-readable category badge")
    description: Optional[str] = Field(default=None, description="Factual property summary")
    
    # Location coordinates
    latitude: float = Field(..., description="Precise latitude from Google Places")
    longitude: float = Field(..., description="Precise longitude from Google Places")
    
    # Address representation
    short_address: Optional[str] = Field(default=None, description="Short address or neighborhood")
    full_address: Optional[str] = Field(default=None, description="Full formatted address")
    address: str = Field(default="", description="General address string")
    city: Optional[str] = Field(default=None, description="City or destination name")
    country: Optional[str] = Field(default="Pakistan", description="Country")
    
    # Google Routes Road Routing & ETA
    distance_km: Optional[float] = Field(default=None, description="Actual driving road distance in km")
    eta_minutes: Optional[int] = Field(default=None, description="Actual driving travel time in minutes")
    road_distance_km: Optional[float] = Field(default=None, description="Alias for road distance in km")
    driving_duration_min: Optional[int] = Field(default=None, description="Alias for driving duration in min")
    formatted_distance: Optional[str] = Field(default=None, description="User-friendly distance string")
    estimatedTravelTime: Optional[str] = Field(default=None, description="User-friendly ETA string")
    
    # Rating & Reviews
    rating: Optional[float] = Field(default=None, description="Google user rating (1.0 to 5.0)")
    reviews_count: Optional[int] = Field(default=None, description="Total Google user reviews count")
    
    # Pricing & Availability
    price_per_night_pkr: Optional[int] = Field(default=None, description="Price per night in PKR")
    price_formatted: Optional[str] = Field(default=None, description="Formatted price e.g. 'PKR 55,000'")
    is_available: bool = Field(default=True, description="Availability flag")
    
    # Media & Contact
    image_url: Optional[str] = Field(default=None, description="Primary photo URL")
    galleryImages: List[str] = Field(default_factory=list, description="Additional photo URLs")
    website: Optional[str] = Field(default=None, description="Official website or Google Maps link")
    phone: Optional[str] = Field(default=None, description="Phone contact")
    
    # Highlights & Amenities
    highlight: Optional[str] = Field(default=None, description="Short factual highlight tag")
    amenities: List[str] = Field(default_factory=list, description="Verified amenity list")
    
    # Navigation
    directions_url: str = Field(..., description="Google Maps turn-by-turn navigation URL")


class HotelSearchRequest(BaseModel):
    """Request model for hotel search endpoint."""
    city: Optional[str] = Field(default=None, description="Selected destination city name")
    user_latitude: Optional[float] = Field(default=None, description="Actual device GPS latitude of user for route distance & ETA")
    user_longitude: Optional[float] = Field(default=None, description="Actual device GPS longitude of user for route distance & ETA")
    latitude: Optional[float] = Field(default=None, description="Optional explicit search center latitude")
    longitude: Optional[float] = Field(default=None, description="Optional explicit search center longitude")
    radius_km: Optional[float] = Field(default=None, description="Search radius in km")
    category: Optional[str] = Field(default="all", description="Category filter: all, luxury, resort, boutique, budget, pods/glamping")
    sort_by: Optional[str] = Field(default="nearest", description="Sorting option: nearest, rating, price_low, price_high")
    location_name: Optional[str] = Field(default=None, description="Location display label")
    search_query: Optional[str] = Field(default=None, description="Optional text query filter")


class HotelSearchResponse(BaseModel):
    """Response model for hotel search endpoint."""
    success: bool = True
    city: Optional[str] = None
    location_name: Optional[str] = None
    total_found: int = 0
    header_status: str = ""
    center_latitude: float
    center_longitude: float
    radius_km: float = 20.0
    map_pins: List[MapPinItem] = Field(default_factory=list)
    stays: List[StayItem] = Field(default_factory=list)
    map_url: Optional[str] = None
    is_fallback: bool = False
    error: Optional[str] = None


class CityItem(BaseModel):
    """Supported Destination City Anchor."""
    name: str
    latitude: float
    longitude: float


class CitiesResponse(BaseModel):
    """List of supported destination cities."""
    success: bool = True
    cities: List[CityItem] = Field(default_factory=list)


class HotelGeocodeRequest(BaseModel):
    """Geocode search request."""
    query: str


class GeocodeResultItem(BaseModel):
    """Geocoded landmark or place result."""
    name: str
    formatted_address: str
    latitude: float
    longitude: float
    city: Optional[str] = None


class GeocodeResponse(BaseModel):
    """Geocoding response list."""
    success: bool = True
    results: List[GeocodeResultItem] = Field(default_factory=list)


class LocationResolutionRequest(BaseModel):
    """Location resolution request."""
    destination: str


class ResolvedLocationResponse(BaseModel):
    """Resolved location coordinates and recommended radius."""
    success: bool = True
    name: str
    country: str = "Pakistan"
    latitude: float
    longitude: float
    radius_km: float = 40.0
    is_ambiguous: bool = False
    error: Optional[str] = None
