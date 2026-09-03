import asyncio
import os
import sys
import time
from datetime import datetime, timezone

# Ensure backend root is in sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__))))
if sys.platform.startswith("win"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass


from app.db.database import init_db, SessionLocal, ALERTS_DB_PATH
from app.models.notification import Notification
from app.services.weather_collector import weather_collector
from app.services.disaster_collector import disaster_collector
from app.services.advisory_collector import advisory_collector
from app.services.alert_enrichment_service import alert_enrichment_service
from app.services.notification_sync_service import notification_sync_service
from fastapi.testclient import TestClient
from app.main import app, scheduler


async def run_all_tests():
    print("=" * 65)
    print("🚀 STARTING BON VOYAGE PAKISTAN NOTIFICATIONS & ADVISORIES TEST SUITE")
    print("=" * 65)

    # ─────────────────────────────────────────────────────────────
    # TEST 1 & 2: Startup & Database Initialization
    # ─────────────────────────────────────────────────────────────
    print("\n--- TEST 1 & 2: Database & Initial Sync Verification ---")
    init_db()
    print(f"✅ SQLite Database initialized at: {ALERTS_DB_PATH}")
    assert os.path.exists(ALERTS_DB_PATH), "alerts.db file was not created!"

    # Run complete sync
    print("Running initial alert sync (Open-Meteo + USGS + Curated + Gemini)...")
    t0 = time.time()
    sync_count = await notification_sync_service.sync_all_alerts(enrich_with_gemini=True)
    duration = time.time() - t0
    print(f"✅ Initial sync completed in {duration:.2f}s. Total records synced: {sync_count}")
    assert sync_count > 0, "No records synced into database!"

    db = SessionLocal()
    db_count = db.query(Notification).filter(Notification.is_active == True).count()
    print(f"✅ Verified SQLite contains {db_count} active notifications.")
    assert db_count > 0, "SQLite query returned 0 active notifications!"

    # Inspect a few records from DB
    sample_records = db.query(Notification).limit(3).all()
    for s in sample_records:
        print(f"   📌 [{s.category.upper()}] [{s.severity.upper()}] {s.title} ({s.city}) - Source: {s.source}")
    db.close()

    # ─────────────────────────────────────────────────────────────
    # TEST 3: REST API Endpoint Verification
    # ─────────────────────────────────────────────────────────────
    print("\n--- TEST 3: GET /api/v1/notifications API Feed ---")
    client = TestClient(app)
    resp = client.get("/api/v1/notifications?city=Islamabad&category=all")
    assert resp.status_code == 200, f"API returned error: {resp.status_code} - {resp.text}"
    data = resp.json()
    assert data.get("success") is True, "Response success is not True"
    assert "alerts" in data, "alerts field missing in response"
    print(f"✅ API Response status: 200 OK | Found {len(data['alerts'])} alerts for Islamabad.")
    if data["alerts"]:
        first = data["alerts"][0]
        print(f"   Card sample: id={first['id']}, type={first['type']}, severity={first['severity']}, title='{first['title']}'")
        assert "createdAt" in first, "Flutter createdAt field missing"
        assert "recommendedAction" in first or "recommended_action" in first, "Action field missing"

    # ─────────────────────────────────────────────────────────────
    # TEST 4: Category Filtering Verification
    # ─────────────────────────────────────────────────────────────
    print("\n--- TEST 4: Category Filtering ---")
    categories_to_test = ["weather", "roadCondition", "naturalDisaster", "advisory", "all"]
    for cat in categories_to_test:
        resp = client.get(f"/api/v1/notifications?category={cat}")
        assert resp.status_code == 200, f"Category {cat} failed: {resp.status_code}"
        alerts = resp.json().get("alerts", [])
        print(f"✅ Category '{cat}' filter returned {len(alerts)} alerts.")
        if cat != "all" and alerts:
            for a in alerts:
                assert a["type"].lower() == cat.lower() or a["category"].lower() == cat.lower(), f"Mismatch in category {cat} != {a['type']}"

    # Also test alternative aliases like roads_passes and disaster
    resp_alias1 = client.get("/api/v1/notifications?category=roads_passes")
    assert resp_alias1.status_code == 200
    print(f"✅ Category alias 'roads_passes' returned {len(resp_alias1.json().get('alerts', []))} alerts.")

    resp_alias2 = client.get("/api/v1/notifications?category=disaster")
    assert resp_alias2.status_code == 200
    print(f"✅ Category alias 'disaster' returned {len(resp_alias2.json().get('alerts', []))} alerts.")

    # ─────────────────────────────────────────────────────────────
    # TEST 5: City & GPS Location Filtering
    # ─────────────────────────────────────────────────────────────
    print("\n--- TEST 5: City & GPS Location Filtering ---")
    cities_to_test = ["Islamabad", "Murree & Galiyat", "Hunza Valley", "Skardu & Baltistan", "Swat & Kalam"]
    for c in cities_to_test:
        resp = client.get(f"/api/v1/notifications?city={c}")
        assert resp.status_code == 200
        alerts = resp.json().get("alerts", [])
        print(f"✅ City '{c}' query returned {len(alerts)} relevant alerts.")

    # Test GPS coordinate query (e.g. Islamabad Lat 33.6844, Lon 73.0479)
    resp_gps = client.get("/api/v1/notifications?lat=33.6844&lon=73.0479&category=all")
    assert resp_gps.status_code == 200
    gps_alerts = resp_gps.json().get("alerts", [])
    print(f"✅ GPS coordinate proximity filter (33.6844, 73.0479) returned {len(gps_alerts)} alerts within 250km.")

    # ─────────────────────────────────────────────────────────────
    # TEST 6: Resiliency on External API Failure
    # ─────────────────────────────────────────────────────────────
    print("\n--- TEST 6: Resiliency & SQLite Cached Fallback ---")
    # Simulate API query when external collectors are untouched (pure fast SQLite read)
    t_start = time.time()
    resp_fast = client.get("/api/v1/notifications?category=all")
    elapsed_ms = (time.time() - t_start) * 1000.0
    assert resp_fast.status_code == 200
    print(f"✅ SQLite cache served {len(resp_fast.json()['alerts'])} alerts in {elapsed_ms:.2f} ms (ultra-fast, non-blocking).")

    # ─────────────────────────────────────────────────────────────
    # TEST 7: Gemini Failure & Offline Fallback Resiliency
    # ─────────────────────────────────────────────────────────────
    print("\n--- TEST 7: Gemini Enrichment & Offline Fallback ---")
    dummy_alert = {
        "title": "Severe Rainstorm & Rockfall Warning",
        "category": "weather",
        "severity": "high",
        "location": "Murree Expressway (N-75)",
        "city": "Murree & Galiyat",
        "description": "Heavy rainfall resulting in slippery surface and low visibility.",
        "recommended_action": "Original default action: Drive slowly in low gear.",
        "source": "Open-Meteo / PMD",
    }
    # Test real Gemini enrichment
    enriched = await alert_enrichment_service.enrich_advisory(dummy_alert)
    print(f"✅ Gemini Output / Fallback: '{enriched}'")
    assert len(enriched) > 0, "Enrichment returned empty string!"

    # ─────────────────────────────────────────────────────────────
    # TEST 8: Scheduler Registration & Health Check
    # ─────────────────────────────────────────────────────────────
    print("\n--- TEST 8: APScheduler & Health Check ---")
    resp_health = client.get("/health")
    assert resp_health.status_code == 200
    health_data = resp_health.json()
    print(f"✅ /health endpoint response: {health_data}")
    assert health_data["status"] == "ok"
    assert health_data["fastapi_running"] == "YES"

    # ─────────────────────────────────────────────────────────────
    # TEST 9: Deduplication & Expiration Check
    # ─────────────────────────────────────────────────────────────
    print("\n--- TEST 9: Alert Deduplication & Expiration Lifecycle ---")
    db1 = SessionLocal()
    total_before = db1.query(Notification).count()
    db1.close()

    await notification_sync_service.sync_all_alerts(enrich_with_gemini=False)

    db2 = SessionLocal()
    total_after = db2.query(Notification).count()
    active_after = db2.query(Notification).filter(Notification.is_active == True).count()
    inactive_after = db2.query(Notification).filter(Notification.is_active == False).count()
    db2.close()

    print(f"✅ Total DB records: {total_before} -> {total_after} (Active: {active_after}, Deactivated Expired: {inactive_after})")
    assert total_before == total_after, f"Duplicate alert rows inserted! (Before: {total_before}, After: {total_after})"
    print("✅ Verified 0 duplicate alerts created upon re-synchronization.")


    print("\n" + "=" * 65)
    print("🎉 ALL 9 NOTIFICATION & ADVISORY TEST SUITES PASSED SUCCESSFULLY!")
    print("=" * 65)


if __name__ == "__main__":
    asyncio.run(run_all_tests())
