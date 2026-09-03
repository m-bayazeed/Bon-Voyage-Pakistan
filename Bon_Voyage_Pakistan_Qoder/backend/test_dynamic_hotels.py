import asyncio
import os
import sys
from pathlib import Path

# Add backend directory to sys.path
backend_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(backend_dir))

# Configure stdout for utf-8
if sys.platform == 'win32':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

from app.models.hotel import HotelSearchRequest, LocationResolutionRequest
from app.services.location_resolution_service import location_resolution_service
from app.api.v1.hotels import search_hotels, resolve_location


async def run_tests():
    print("=" * 70)
    print("TEST 1: Dynamic Gemini Location Resolution")
    print("=" * 70)

    test_cities = ["Islamabad", "Lahore", "Hunza", "Skardu", "Passu", "Katas Raj"]
    for city in test_cities:
        res = await location_resolution_service.resolve_destination(city)
        print(f"  [OK] '{city}' -> ({res.latitude:.4f}, {res.longitude:.4f}), Country: {res.country}")

    print("\n" + "=" * 70)
    print("TEST 2: Dynamic Geoapify Search for Islamabad (Radius: 40km)")
    print("=" * 70)

    req_isb = HotelSearchRequest(
        location_name="Islamabad",
        latitude=33.6844,
        longitude=73.0479,
        radius_km=40.0,
        category="all",
        sort_by="nearest",
    )
    res_isb = await search_hotels(req_isb)
    print(f"  -> Total Found: {res_isb.total_found}, Is Fallback: {res_isb.is_fallback}")
    for i, s in enumerate(res_isb.stays[:5], 1):
        print(f"     {i}. {s.name} [{s.badge_label}] - {s.distance_km}km ({s.city}) | Highlight: {s.highlight}")

    print("\n" + "=" * 70)
    print("TEST 3: Dynamic Geoapify Search for Lahore (Radius: 40km)")
    print("=" * 70)

    req_lhr = HotelSearchRequest(
        location_name="Lahore",
        latitude=31.5204,
        longitude=74.3587,
        radius_km=40.0,
        category="all",
        sort_by="nearest",
    )
    res_lhr = await search_hotels(req_lhr)
    print(f"  -> Total Found: {res_lhr.total_found}, Is Fallback: {res_lhr.is_fallback}")
    for i, s in enumerate(res_lhr.stays[:5], 1):
        print(f"     {i}. {s.name} [{s.badge_label}] - {s.distance_km}km ({s.city}) | Highlight: {s.highlight}")

    print("\n" + "=" * 70)
    print("TEST 4: Dynamic Geoapify Search for Hunza (Radius: 40km)")
    print("=" * 70)

    hunza_loc = await location_resolution_service.resolve_destination("Hunza")
    req_hunza = HotelSearchRequest(
        location_name="Hunza",
        latitude=hunza_loc.latitude,
        longitude=hunza_loc.longitude,
        radius_km=40.0,
        category="all",
        sort_by="nearest",
    )
    res_hunza = await search_hotels(req_hunza)
    print(f"  -> Total Found: {res_hunza.total_found}, Is Fallback: {res_hunza.is_fallback}")
    for i, s in enumerate(res_hunza.stays[:5], 1):
        print(f"     {i}. {s.name} [{s.badge_label}] - {s.distance_km}km ({s.city}) | Highlight: {s.highlight}")

    print("\n" + "=" * 70)
    print("TEST 5: Dynamic Geoapify Search for Custom Location: Passu (Radius: 40km)")
    print("=" * 70)

    passu_loc = await location_resolution_service.resolve_destination("Passu")
    req_passu = HotelSearchRequest(
        location_name="Passu",
        latitude=passu_loc.latitude,
        longitude=passu_loc.longitude,
        radius_km=40.0,
        category="all",
        sort_by="nearest",
    )
    res_passu = await search_hotels(req_passu)
    print(f"  -> Total Found: {res_passu.total_found}, Is Fallback: {res_passu.is_fallback}")
    for i, s in enumerate(res_passu.stays[:5], 1):
        print(f"     {i}. {s.name} [{s.badge_label}] - {s.distance_km}km ({s.city}) | Highlight: {s.highlight}")

    print("\n" + "=" * 70)
    print("TEST 6: Category Filter Tests for Islamabad (luxury, budget, resort)")
    print("=" * 70)

    for cat in ["luxury", "budget", "resort", "glamping"]:
        req_cat = HotelSearchRequest(
            location_name="Islamabad",
            latitude=33.6844,
            longitude=73.0479,
            radius_km=40.0,
            category=cat,
            sort_by="nearest",
        )
        res_cat = await search_hotels(req_cat)
        print(f"  -> Category '{cat}': {res_cat.total_found} properties returned")
        for j, s in enumerate(res_cat.stays[:3], 1):
            print(f"     {j}. {s.name} [{s.badge_label}] - {s.distance_km}km")

    print("\nALL DYNAMIC TESTS COMPLETED SUCCESSFULLY!")


if __name__ == "__main__":
    asyncio.run(run_tests())
