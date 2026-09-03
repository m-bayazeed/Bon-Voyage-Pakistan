import asyncio
import sys
from pathlib import Path

backend_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(backend_dir))

if sys.platform == 'win32':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

from app.models.hotel import HotelSearchRequest
from app.api.v1.hotels import search_hotels


async def run_critical_tests():
    print("=" * 80)
    print("CRITICAL VERIFICATION SUITE: City Coordinates & Map Pins Integrity")
    print("=" * 80)

    # ─────────────────────────────────────────────────────────────
    # Test 1: Current Location (GPS)
    # ─────────────────────────────────────────────────────────────
    print("\n--- TEST 1: Current Location (GPS) ---")
    gps_lat, gps_lon = 33.6844, 73.0479
    req_gps = HotelSearchRequest(
        location_name="Current Location (GPS)",
        latitude=gps_lat,
        longitude=gps_lon,
        category="all",
        sort_by="nearest",
    )
    res_gps = await search_hotels(req_gps)
    assert res_gps.center_latitude == gps_lat and res_gps.center_longitude == gps_lon
    assert res_gps.radius_km == 20.0, f"Expected 20.0 km for GPS, got {res_gps.radius_km}"
    print(f"[PASS] GPS Coordinates Verified: ({res_gps.center_latitude}, {res_gps.center_longitude}), Radius: {res_gps.radius_km}km, Found: {res_gps.total_found}")

    # ─────────────────────────────────────────────────────────────
    # Test 2: Islamabad
    # ─────────────────────────────────────────────────────────────
    print("\n--- TEST 2: Islamabad ---")
    isb_lat, isb_lon = 33.6844, 73.0479
    req_isb = HotelSearchRequest(
        location_name="Islamabad",
        latitude=isb_lat,
        longitude=isb_lon,
        category="all",
        sort_by="nearest",
    )
    res_isb = await search_hotels(req_isb)
    assert abs(res_isb.center_latitude - 33.6844) < 0.1
    print(f"[PASS] Islamabad Coordinates: ({res_isb.center_latitude}, {res_isb.center_longitude}), Radius: {res_isb.radius_km}km, Found: {res_isb.total_found}")

    # ─────────────────────────────────────────────────────────────
    # Test 3: Lahore (MUST NOT USE ISLAMABAD / GPS COORDINATES!)
    # ─────────────────────────────────────────────────────────────
    print("\n--- TEST 3: Lahore ---")
    lhr_lat, lhr_lon = 31.5204, 74.3587
    req_lhr = HotelSearchRequest(
        location_name="Lahore",
        latitude=lhr_lat,
        longitude=lhr_lon,
        category="all",
        sort_by="nearest",
    )
    res_lhr = await search_hotels(req_lhr)
    print(f"[CHECK] Requested: ({lhr_lat}, {lhr_lon}) -> Returned: ({res_lhr.center_latitude}, {res_lhr.center_longitude})")
    assert abs(res_lhr.center_latitude - 31.52) < 0.2, f"Lahore latitude must be ~31.52, but got {res_lhr.center_latitude}"
    assert abs(res_lhr.center_longitude - 74.35) < 0.2, f"Lahore longitude must be ~74.35, but got {res_lhr.center_longitude}"
    # Verify stay coordinates are actually in Lahore
    if res_lhr.stays:
        first_stay = res_lhr.stays[0]
        assert abs(first_stay.latitude - 31.52) < 0.8, f"Stay coordinate must be in Lahore, got {first_stay.latitude}"
        print(f"[PASS] First Stay in Lahore: '{first_stay.name}' at ({first_stay.latitude:.4f}, {first_stay.longitude:.4f})")

    # ─────────────────────────────────────────────────────────────
    # Test 4: Hunza Valley (MUST USE HUNZA NORTHERN COORDINATES ~36.3)
    # ─────────────────────────────────────────────────────────────
    print("\n--- TEST 4: Hunza ---")
    hnz_lat, hnz_lon = 36.3167, 74.6500
    req_hnz = HotelSearchRequest(
        location_name="Hunza",
        latitude=hnz_lat,
        longitude=hnz_lon,
        category="all",
        sort_by="nearest",
    )
    res_hnz = await search_hotels(req_hnz)
    print(f"[CHECK] Requested: ({hnz_lat}, {hnz_lon}) -> Returned: ({res_hnz.center_latitude}, {res_hnz.center_longitude})")
    assert abs(res_hnz.center_latitude - 36.3) < 0.3, f"Hunza latitude must be ~36.3, but got {res_hnz.center_latitude}"
    if res_hnz.stays:
        first_stay = res_hnz.stays[0]
        assert abs(first_stay.latitude - 36.3) < 0.8, f"Stay coordinate must be in Hunza, got {first_stay.latitude}"
        print(f"[PASS] First Stay in Hunza: '{first_stay.name}' at ({first_stay.latitude:.4f}, {first_stay.longitude:.4f})")

    # ─────────────────────────────────────────────────────────────
    # Test 5: Custom Location - Nathia Gali
    # ─────────────────────────────────────────────────────────────
    print("\n--- TEST 5: Custom Location: Nathia Gali ---")
    req_cust = HotelSearchRequest(
        location_name="Nathia Gali",
        category="all",
        sort_by="nearest",
    )
    res_cust = await search_hotels(req_cust)
    print(f"[PASS] Nathia Gali resolved center: ({res_cust.center_latitude}, {res_cust.center_longitude}), Stays: {res_cust.total_found}")
    assert abs(res_cust.center_latitude - 34.0) < 0.3, f"Nathia Gali latitude must be ~34.07, got {res_cust.center_latitude}"

    print("\n" + "=" * 80)
    print("ALL 5 CRITICAL LOCATION & MAP PIN TESTS PASSED WITH 100% ACCURACY!")
    print("=" * 80)


if __name__ == "__main__":
    asyncio.run(run_critical_tests())
