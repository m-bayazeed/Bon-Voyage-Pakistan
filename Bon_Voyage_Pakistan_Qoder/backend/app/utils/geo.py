import math
from typing import Tuple, Optional


def is_valid_coordinates(lat: Optional[float], lon: Optional[float]) -> bool:
    """Validate latitude and longitude ranges."""
    if lat is None or lon is None:
        return False
    if not isinstance(lat, (int, float)) or not isinstance(lon, (int, float)):
        return False
    if math.isnan(lat) or math.isnan(lon):
        return False
    return -90.0 <= lat <= 90.0 and -180.0 <= lon <= 180.0


def haversine_distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculate the great circle distance between two points in kilometers.
    Used strictly for geographic radius filtering and validation against search center.
    """
    earth_radius_km = 6371.0
    d_lat = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)
    a = (
        math.sin(d_lat / 2) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(d_lon / 2) ** 2
    )
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return earth_radius_km * c


def calculate_bounding_box(
    lat: float, lon: float, radius_km: float
) -> Tuple[float, float, float, float]:
    """
    Calculate bounding box coordinates (min_lat, min_lon, max_lat, max_lon)
    for a circular radius around center point.
    """
    # 1 deg latitude ~ 111.0 km
    lat_delta = radius_km / 111.0
    # 1 deg longitude ~ 111.0 km * cos(latitude)
    lon_delta = radius_km / (111.0 * max(0.1, math.cos(math.radians(lat))))

    min_lat = max(-90.0, lat - lat_delta)
    max_lat = min(90.0, lat + lat_delta)
    min_lon = max(-180.0, lon - lon_delta)
    max_lon = min(180.0, lon + lon_delta)

    return (min_lat, min_lon, max_lat, max_lon)


def format_distance_string(distance_km: Optional[float]) -> str:
    """Format distance into user-friendly string."""
    if distance_km is None:
        return "Distance unavailable"
    if distance_km < 1.0:
        meters = int(round(distance_km * 1000))
        return f"{meters} m away"
    return f"{distance_km:.1f} km away"


def format_eta_string(eta_minutes: Optional[int]) -> str:
    """Format ETA in minutes into user-friendly travel time string."""
    if eta_minutes is None:
        return "ETA unavailable"
    if eta_minutes < 1:
        return "< 1 min"
    if eta_minutes < 60:
        return f"~{eta_minutes} min"
    hours = eta_minutes // 60
    mins = eta_minutes % 60
    if mins == 0:
        return f"~{hours} hr"
    return f"~{hours} hr {mins} min"


def format_price_pkr(price: Optional[int]) -> Optional[str]:
    """Format integer PKR into comma separated string e.g. 'PKR 55,000'."""
    if price is None or price <= 0:
        return None
    return f"PKR {price:,}"


def format_price_tag(price: Optional[int]) -> str:
    """Format compact price tag for map pins e.g. 'PKR 55k'."""
    if price is None or price <= 0:
        return "PKR -"
    if price >= 1000:
        k_val = price / 1000.0
        if k_val.is_integer():
            return f"PKR {int(k_val)}k"
        return f"PKR {k_val:.1f}k"
    return f"PKR {price}"
