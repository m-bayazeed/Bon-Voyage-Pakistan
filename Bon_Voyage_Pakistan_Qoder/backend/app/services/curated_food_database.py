from typing import List, Optional
from app.models.food import FoodPlaceItem


def get_curated_fallback_food(
    city_name: Optional[str] = None,
    category: Optional[str] = None,
    search_lat: Optional[float] = None,
    search_lon: Optional[float] = None,
    radius_km: float = 30.0,
) -> List[FoodPlaceItem]:
    """
    Dummy/placeholder data has been removed per architectural specifications.
    Only live Google Places API results are served to the user.
    """
    return []
