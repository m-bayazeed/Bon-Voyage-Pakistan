from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field


class FoodMapPinItem(BaseModel):
    """Map Pin model for interactive food map markers."""
    id: str = Field(..., description="Unique Food Place ID")
    name: str = Field(..., description="Restaurant name")
    latitude: float = Field(..., description="Exact latitude")
    longitude: float = Field(..., description="Exact longitude")
    category: str = Field(default="desiPakistani", description="Food category key")
    rating: Optional[float] = Field(default=None, description="Rating")
    cuisine: Optional[str] = Field(default=None, description="Cuisine description")


class FoodPlaceItem(BaseModel):
    """Complete Food Place & Dining Model matching Flutter contract."""
    id: str = Field(..., description="Unique identifier (Google Place ID or curated ID)")
    name: str = Field(..., description="Restaurant / food place name")
    category: str = Field(default="desiPakistani", description="Category matching FoodCategory enum in Flutter")
    cuisine: str = Field(default="Desi / Pakistani", description="Cuisine summary")
    latitude: float = Field(..., description="Exact latitude from Google Places")
    longitude: float = Field(..., description="Exact longitude from Google Places")
    city: str = Field(default="Pakistan", description="City or destination name")
    address: str = Field(default="", description="Full or short address")
    
    # Distance & ETA fields (supports both camelCase and snake_case for Flutter deserialization)
    distance: str = Field(default="Nearby", description="Human-readable distance (e.g. '4.2 km')")
    distanceKm: float = Field(default=1.0, description="Numeric distance in km")
    distance_km: Optional[float] = Field(default=None, description="Driving distance in km")
    estimatedTravelTime: str = Field(default="10 mins", description="Human-readable travel duration")
    eta_minutes: Optional[int] = Field(default=None, description="Driving duration in minutes")
    
    # Ratings & Reviews
    rating: float = Field(default=4.5, description="Google user rating")
    reviewCount: int = Field(default=100, description="Total review count")
    
    # Pricing & Hours
    priceTier: str = Field(default="moderate", description="Price tier: budget, moderate, expensive, fineDining")
    avgCostPerPersonPkr: int = Field(default=1500, description="Estimated average cost per person in PKR")
    isOpen: bool = Field(default=True, description="Open status")
    openingHours: str = Field(default="11:00 AM - 12:00 AM", description="Operating hours")
    phone: str = Field(default="+92-51-111-111-111", description="Phone contact")
    
    # Media
    imageUrl: str = Field(default="", description="Primary photo URL")
    galleryImages: List[str] = Field(default_factory=list, description="Additional photos")
    
    # Gastronomy details
    specialties: List[str] = Field(default_factory=list, description="Signature dishes and specialties")
    description: Optional[str] = Field(default="", description="Factual description")
    popularReview: Optional[str] = Field(default=None, description="Review highlight snippet")
    landmarkNearby: str = Field(default="", description="Nearby landmark or area")
    
    # Service options
    hasDineIn: bool = Field(default=True, description="Dine-in available")
    hasTakeaway: bool = Field(default=True, description="Takeaway available")
    hasDelivery: bool = Field(default=False, description="Delivery available")
    
    # Navigation
    directions_url: str = Field(default="", description="Google Maps turn-by-turn driving URL")


class FoodSearchRequest(BaseModel):
    """Request model for food search endpoint."""
    city: Optional[str] = Field(default=None, description="Selected city name")
    location_name: Optional[str] = Field(default=None, description="Display location label")
    user_latitude: Optional[float] = Field(default=None, description="User GPS latitude for driving distance & ETA")
    user_longitude: Optional[float] = Field(default=None, description="User GPS longitude for driving distance & ETA")
    latitude: Optional[float] = Field(default=None, description="Search center latitude")
    longitude: Optional[float] = Field(default=None, description="Search center longitude")
    radius_km: Optional[float] = Field(default=30.0, description="Search radius in km (default 30 km)")
    category: Optional[str] = Field(default="all", description="Category filter (all, desiPakistani, bbq, etc.)")
    cuisine: Optional[str] = Field(default=None, description="Cuisine query filter")
    sort_by: Optional[str] = Field(default="rating", description="Sort option: nearest, rating, reviews, price_low, price_high")
    search_query: Optional[str] = Field(default=None, description="Text keyword search")


class FoodSearchResponse(BaseModel):
    """Response model for food search endpoint."""
    success: bool = True
    city: str
    location_name: str
    total_found: int = 0
    header_status: str = ""
    center_latitude: float
    center_longitude: float
    radius_km: float = 30.0
    map_pins: List[FoodMapPinItem] = Field(default_factory=list)
    places: List[FoodPlaceItem] = Field(default_factory=list)
    is_fallback: bool = False
    error: Optional[str] = None
