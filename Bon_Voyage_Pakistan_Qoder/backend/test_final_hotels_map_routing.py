import asyncio
import os
import sys

# Ensure backend path is on sys.path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.core.config import settings
from app.models.hotel import HotelSearchRequest
from app.services.geoapify_service import geoapify_service
from app.services.location_resolution_service import location_resolution_service


async def run_final_tests():
    print("=" * 80)
    print("FINAL VERIFICATION: Geoapify Places, Route Matrix & Google Maps Directions")
    print("=" * 80)

    user_gps_lat = 33.6844
    user_gps_lon = 73.0479

    # --- TEST 1: Current Location (GPS) ---
    print("\n--- TEST 1: Current Location (GPS Mode) ---")
    places_gps = await geoapify_service.search_nearby_stays(
        latitude=user_gps_lat,
        longitude=user_gps_lon,
        radius_km=20.0,
        limit=10,
        origin_lat=user_gps_lat,
        origin_lon=user_gps_lon,
    )
    assert len(places_gps) > 0, "Failed to find stays near GPS location"
    
    # Route Matrix from GPS origin
    routed_gps = await geoapify_service.compute_route_matrix(
        origin_lat=user_gps_lat,
        origin_lon=user_gps_lon,
        stays=places_gps[:5],
    )
    first_gps_stay = routed_gps[0]
    print(f"[PASS] Found {len(places_gps)} stays near GPS ({user_gps_lat}, {user_gps_lon})")
    print(f"       First stay: '{first_gps_stay.name}' at ({first_gps_stay.latitude}, {first_gps_stay.longitude})")
    print(f"       Road Distance: {first_gps_stay.road_distance_km} km, Duration: {first_gps_stay.driving_duration_min} min")
    print(f"       Formatted: {first_gps_stay.formatted_distance}")
    print(f"       Directions URL: {first_gps_stay.directions_url}")
    assert first_gps_stay.directions_url.startswith("https://www.google.com/maps/dir/?api=1&origin=33.6844,73.0479"), "Invalid directions URL origin"

    # --- TEST 2: Islamabad Search ---
    print("\n--- TEST 2: Islamabad City Search ---")
    isb_pt = await location_resolution_service.resolve_destination("Islamabad")
    places_isb = await geoapify_service.search_nearby_stays(
        latitude=isb_pt.latitude,
        longitude=isb_pt.longitude,
        radius_km=45.0,
        limit=10,
        origin_lat=user_gps_lat,
        origin_lon=user_gps_lon,
    )
    assert len(places_isb) > 0
    print(f"[PASS] Islamabad Search Center: ({isb_pt.latitude}, {isb_pt.longitude}) -> Found {len(places_isb)} stays")

    # --- TEST 3: Lahore Search (Origin is GPS in Islamabad, Search is Lahore) ---
    print("\n--- TEST 3: Lahore City Search with Origin=GPS (Islamabad) ---")
    lhr_pt = await location_resolution_service.resolve_destination("Lahore")
    assert abs(lhr_pt.latitude - 31.5204) < 0.1, f"Unexpected Lahore lat: {lhr_pt.latitude}"
    
    places_lhr = await geoapify_service.search_nearby_stays(
        latitude=lhr_pt.latitude,
        longitude=lhr_pt.longitude,
        radius_km=45.0,
        limit=10,
        origin_lat=user_gps_lat,
        origin_lon=user_gps_lon,
    )
    assert len(places_lhr) > 0
    
    routed_lhr = await geoapify_service.compute_route_matrix(
        origin_lat=user_gps_lat,
        origin_lon=user_gps_lon,
        stays=places_lhr[:5],
    )
    first_lhr_stay = routed_lhr[0]
    print(f"[PASS] Lahore Search Center: ({lhr_pt.latitude}, {lhr_pt.longitude}) -> Found {len(places_lhr)} stays")
    print(f"       First stay in Lahore: '{first_lhr_stay.name}' at ({first_lhr_stay.latitude}, {first_lhr_stay.longitude})")
    print(f"       Road Distance from GPS (Islamabad): {first_lhr_stay.road_distance_km} km (~{first_lhr_stay.driving_duration_min} min)")
    print(f"       Directions URL: {first_lhr_stay.directions_url}")
    assert f"origin={user_gps_lat},{user_gps_lon}" in first_lhr_stay.directions_url
    assert f"destination={first_lhr_stay.latitude},{first_lhr_stay.longitude}" in first_lhr_stay.directions_url

    # --- TEST 4: Hunza Search ---
    print("\n--- TEST 4: Hunza Search with Origin=GPS (Islamabad) ---")
    hunza_pt = await location_resolution_service.resolve_destination("Hunza")
    places_hunza = await geoapify_service.search_nearby_stays(
        latitude=hunza_pt.latitude,
        longitude=hunza_pt.longitude,
        radius_km=45.0,
        limit=10,
        origin_lat=user_gps_lat,
        origin_lon=user_gps_lon,
    )
    assert len(places_hunza) > 0
    first_hunza_stay = places_hunza[0]
    print(f"[PASS] Hunza Search Center: ({hunza_pt.latitude}, {hunza_pt.longitude}) -> Found {len(places_hunza)} stays")
    print(f"       First stay in Hunza: '{first_hunza_stay.name}' at ({first_hunza_stay.latitude}, {first_hunza_stay.longitude})")

    print("\n" + "=" * 80)
    print("ALL ROUTING, MAP DATA & DIRECTIONS TESTS COMPLETED SUCCESSFULLY!")
    print("=" * 80)


if __name__ == "__main__":
    asyncio.run(run_final_tests())
