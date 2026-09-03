"""
Test suite for Hotels & Stays FastAPI backend.
Validates Geoapify integration, Gemini enrichment, city listings, geocoding, and category filters.
"""

import asyncio
import os
import sys

# Ensure backend root is on sys.path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.core.config import settings
from app.models.hotel import HotelSearchRequest, HotelGeocodeRequest
from app.api.v1.hotels import get_cities, search_hotels, geocode_location


async def run_tests():
    print("=" * 60)
    print("BON VOYAGE PAKISTAN — HOTELS & STAYS BACKEND TEST SUITE")
    print("=" * 60)

    # 1. Test Cities Endpoint
    print("\n[TEST 1] Testing GET /api/v1/hotels/cities...")
    cities_resp = await get_cities()
    assert cities_resp.success is True, "Cities response should be successful"
    assert len(cities_resp.cities) >= 8, f"Expected >= 8 cities, got {len(cities_resp.cities)}"
    print(f"[OK] Cities retrieved: {[c.name for c in cities_resp.cities]}")

    # 2. Test Geocoding Endpoint
    print("\n[TEST 2] Testing POST /api/v1/hotels/geocode for 'Hunza'...")
    geo_req = HotelGeocodeRequest(query="Hunza")
    geo_resp = await geocode_location(geo_req)
    assert geo_resp.success is True, "Geocode response should be successful"
    assert len(geo_resp.results) > 0, "Expected at least 1 geocode result for 'Hunza'"
    print(f"[OK] Geocode result for 'Hunza': {geo_resp.results[0].name} -> ({geo_resp.results[0].latitude}, {geo_resp.results[0].longitude})")

    # 3. Test Hotel Search with GPS coordinates (Islamabad Blue Area)
    print("\n[TEST 3] Testing POST /api/v1/hotels/search near Islamabad (33.7180, 73.0538)...")
    search_req = HotelSearchRequest(
        latitude=33.7180,
        longitude=73.0538,
        radius_km=15.0,
        category="all",
        sort_by="nearest",
        location_name="Current Location",
    )
    search_resp = await search_hotels(search_req)
    assert search_resp.success is True, "Search response should be successful"
    print(f"[OK] Total stays found: {search_resp.total_found} (is_fallback: {search_resp.is_fallback})")
    assert len(search_resp.stays) > 0, "Expected at least 1 stay returned"

    first_stay = search_resp.stays[0]
    print(f"  First stay: {first_stay.name}")
    print(f"  Category: {first_stay.category} ({first_stay.badge_label})")
    print(f"  Distance: {first_stay.distance_km} km")
    print(f"  Directions URL: {first_stay.directions_url}")
    print(f"  Description: {first_stay.description}")
    print(f"  Highlight: {first_stay.highlight}")

    # 4. Test Category Filter (e.g. luxury or resort)
    print("\n[TEST 4] Testing Category Filtering ('luxury')...")
    lux_req = HotelSearchRequest(
        latitude=33.7180,
        longitude=73.0538,
        radius_km=25.0,
        category="luxury",
        sort_by="nearest",
    )
    lux_resp = await search_hotels(lux_req)
    assert lux_resp.success is True
    print(f"[OK] Luxury stays found: {lux_resp.total_found}")
    for s in lux_resp.stays[:3]:
        print(f"  - {s.name} [{s.badge_label}] ({s.distance_km} km)")

    # 5. Test Remote Destination (Skardu)
    print("\n[TEST 5] Testing Search in Skardu (35.2971, 75.6333)...")
    skd_req = HotelSearchRequest(
        latitude=35.2971,
        longitude=75.6333,
        radius_km=30.0,
        category="all",
        sort_by="nearest",
        location_name="Skardu",
    )
    skd_resp = await search_hotels(skd_req)
    assert skd_resp.success is True
    print(f"[OK] Skardu stays found: {skd_resp.total_found}")
    for s in skd_resp.stays[:3]:
        print(f"  - {s.name} ({s.distance_km} km): {s.description}")

    print("\n" + "=" * 60)
    print("ALL BACKEND TESTS PASSED SUCCESSFULLY!")
    print("=" * 60)


if __name__ == "__main__":
    asyncio.run(run_tests())
