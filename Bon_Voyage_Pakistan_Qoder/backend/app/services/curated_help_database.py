from typing import List, Optional
from app.models.help import HelpFacilityItem


def get_curated_fallback_help(
    city_name: Optional[str] = None,
    assistance_type: Optional[str] = None,
    emergency_only: bool = False,
    search_lat: Optional[float] = None,
    search_lon: Optional[float] = None,
    radius_km: float = 30.0,
) -> List[HelpFacilityItem]:
    """
    Dummy/placeholder data has been removed per architectural specifications.
    Only live Google Places API healthcare facilities are served to the user.
    """
    return []
