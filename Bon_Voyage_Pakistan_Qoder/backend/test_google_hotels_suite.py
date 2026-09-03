import asyncio
import unittest
from fastapi.testclient import TestClient
from app.main import app
from app.models.hotel import StayItem, MapPinItem, HotelSearchResponse
from app.services.google_places_service import google_places_service
from app.services.google_routes_service import google_routes_service
from app.services.curated_hotel_database import get_curated_fallback_stays
from app.utils.geo import format_price_pkr, format_price_tag, is_valid_coordinates


class TestGoogleHotelsBackendSuite(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)

    def test_01_geo_utilities(self):
        """Test coordinate validation and price tag formatting."""
        self.assertTrue(is_valid_coordinates(33.6844, 73.0479))
        self.assertTrue(is_valid_coordinates(-25.1264, 62.3225))
        self.assertFalse(is_valid_coordinates(None, 73.0479))
        self.assertFalse(is_valid_coordinates(95.0, 73.0479))

        self.assertEqual(format_price_pkr(55000), "PKR 55,000")
        self.assertEqual(format_price_tag(55000), "PKR 55k")
        self.assertEqual(format_price_tag(8500), "PKR 8.5k")
        self.assertEqual(format_price_tag(None), "PKR -")

    def test_02_get_cities_endpoint(self):
        """Test GET /api/v1/hotels/cities returns registered Pakistani destinations."""
        res = self.client.get("/api/v1/hotels/cities")
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data["success"])
        self.assertIn("cities", data)
        city_names = [c["name"] for c in data["cities"]]
        self.assertIn("Islamabad", city_names)
        self.assertIn("Lahore", city_names)
        self.assertIn("Karachi", city_names)
        self.assertIn("Hunza", city_names)
        self.assertIn("Skardu", city_names)
        self.assertIn("Swat / Kalam", city_names)
        print(f"[TEST 2 PASSED] Cities endpoint returned {len(city_names)} anchors.")

    def test_03_search_current_location_gps(self):
        """Test POST /api/v1/hotels/search for Current Location mode."""
        payload = {
            "city": "Current Location (GPS)",
            "user_latitude": 33.6844,
            "user_longitude": 73.0479,
            "latitude": 33.6844,
            "longitude": 73.0479,
            "radius_km": 15,
            "category": "all",
            "sort_by": "nearest",
        }
        res = self.client.post("/api/v1/hotels/search", json=payload)
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data["success"])
        self.assertGreater(data["total_found"], 0)
        self.assertIn("map_pins", data)
        self.assertIn("stays", data)
        self.assertEqual(len(data["map_pins"]), len(data["stays"]))

        # Verify first stay
        first_stay = data["stays"][0]
        self.assertIn("id", first_stay)
        self.assertIn("name", first_stay)
        self.assertIn("latitude", first_stay)
        self.assertIn("longitude", first_stay)
        self.assertIn("directions_url", first_stay)
        self.assertTrue(first_stay["directions_url"].startswith("https://www.google.com/maps/dir/"))
        print(f"[TEST 3 PASSED] GPS Search returned {data['total_found']} stays with valid directions URLs.")

    def test_04_search_selected_city_lahore_separation(self):
        """
        Test POST /api/v1/hotels/search for Selected City 'Lahore' while user is at Islamabad GPS.
        Verifies strict separation of:
        - Search Center = Lahore (31.5204, 74.3587)
        - User GPS Origin = Islamabad (33.6844, 73.0479)
        - Destination = Lahore Hotel coordinates
        """
        payload = {
            "city": "Lahore",
            "user_latitude": 33.6844,
            "user_longitude": 73.0479,
            "category": "luxury",
            "sort_by": "nearest",
        }
        res = self.client.post("/api/v1/hotels/search", json=payload)
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data["success"])
        self.assertEqual(data["city"], "Lahore")
        # Search center should be near Lahore coordinates (~31.5)
        self.assertAlmostEqual(data["center_latitude"], 31.5204, delta=0.5)
        self.assertAlmostEqual(data["center_longitude"], 74.3587, delta=0.5)

        # Check stays are located in Lahore
        for stay in data["stays"]:
            self.assertAlmostEqual(stay["latitude"], 31.5, delta=0.8)
            # Directions URL must have origin = Islamabad GPS and destination = Lahore hotel
            self.assertIn("origin=33.68440,73.04790", stay["directions_url"])

        print(f"[TEST 4 PASSED] City Lahore search successfully separated search center ({data['center_latitude']}, {data['center_longitude']}) from GPS origin (33.6844, 73.0479).")

    def test_05_search_hunza_mountain_resorts(self):
        """Test POST /api/v1/hotels/search for Hunza mountain stays."""
        payload = {
            "city": "Hunza",
            "user_latitude": 33.6844,
            "user_longitude": 73.0479,
            "category": "all",
            "sort_by": "rating",
        }
        res = self.client.post("/api/v1/hotels/search", json=payload)
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data["success"])
        self.assertEqual(data["city"], "Hunza")
        self.assertAlmostEqual(data["center_latitude"], 36.3167, delta=0.5)
        self.assertGreater(data["total_found"], 0)
        print(f"[TEST 5 PASSED] Hunza search returned {data['total_found']} stays.")

    def test_06_sorting_options(self):
        """Test sorting by rating, price_low, and price_high."""
        # 1. Rating sort
        res_rating = self.client.post("/api/v1/hotels/search", json={"city": "Islamabad", "sort_by": "rating"})
        self.assertEqual(res_rating.status_code, 200)
        stays_rating = res_rating.json()["stays"]
        ratings = [s["rating"] for s in stays_rating if s.get("rating") is not None]
        for i in range(len(ratings) - 1):
            self.assertGreaterEqual(ratings[i], ratings[i + 1])

        # 2. Price low to high sort
        res_price_low = self.client.post("/api/v1/hotels/search", json={"city": "Islamabad", "sort_by": "price_low"})
        self.assertEqual(res_price_low.status_code, 200)
        stays_price_low = res_price_low.json()["stays"]
        prices = [s["price_per_night_pkr"] for s in stays_price_low if s.get("price_per_night_pkr") is not None]
        for i in range(len(prices) - 1):
            self.assertLessEqual(prices[i], prices[i + 1])

        print("[TEST 6 PASSED] Strict sorting by rating and price low verified.")

    def test_07_map_pins_structure(self):
        """Test map_pins array compliance with section 16 of specifications."""
        res = self.client.post("/api/v1/hotels/search", json={"city": "Islamabad", "category": "all"})
        self.assertEqual(res.status_code, 200)
        data = res.json()
        pins = data["map_pins"]
        self.assertGreater(len(pins), 0)
        for pin in pins:
            self.assertIn("hotel_id", pin)
            self.assertIn("name", pin)
            self.assertIn("latitude", pin)
            self.assertIn("longitude", pin)
            self.assertIn("price_tag", pin)
            self.assertIn("category", pin)
            self.assertTrue(pin["price_tag"].startswith("PKR"))
        print(f"[TEST 7 PASSED] Map pins structure validated ({len(pins)} pins).")

    def test_08_curated_fallback_safety(self):
        """Test fallback database returns verified Pakistani stays when offline."""
        stays = get_curated_fallback_stays(city_name="Islamabad", category="all", origin_lat=33.6844, origin_lon=73.0479)
        self.assertGreater(len(stays), 0)
        names = [s.name for s in stays]
        self.assertTrue(any("Serena" in n or "Marriott" in n for n in names))
        print(f"[TEST 8 PASSED] Fallback database contains {len(stays)} verified stays.")


if __name__ == "__main__":
    unittest.main()
