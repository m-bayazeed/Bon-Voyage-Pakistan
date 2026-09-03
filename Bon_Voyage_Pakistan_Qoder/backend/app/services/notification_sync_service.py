import asyncio
import logging
from datetime import datetime, timezone
from typing import Dict, List
from sqlalchemy.orm import Session

from app.db.database import SessionLocal, init_db
from app.models.notification import Notification
from app.services.weather_collector import weather_collector
from app.services.disaster_collector import disaster_collector
from app.services.advisory_collector import advisory_collector
from app.services.alert_enrichment_service import alert_enrichment_service

logger = logging.getLogger(__name__)


class NotificationSyncService:
    """Orchestrates ingestion, enrichment, and caching of real-time travel alerts into SQLite."""

    def __init__(self):
        self._sync_lock = asyncio.Lock()
        self._last_sync_time: datetime = None

    async def sync_all_alerts(self, enrich_with_gemini: bool = True) -> int:
        """
        Runs a complete sync cycle:
        1. Ingest live weather hazards from Open-Meteo.
        2. Ingest real earthquake/seismic events from USGS.
        3. Ingest curated mountain corridor advisories.
        4. Optionally enrich recommended actions via Gemini AI.
        5. Atomically update SQLite database cache and deactivate expired records.
        """
        if self._sync_lock.locked():
            logger.info("Notification sync already in progress, skipping duplicate invocation.")
            return 0

        async with self._sync_lock:
            logger.info("Starting comprehensive notification & travel advisory sync...")
            raw_alerts: List[Dict] = []

            # 1. Weather Hazards (Open-Meteo)
            try:
                weather_alerts = await weather_collector.collect_live_alerts()
                raw_alerts.extend(weather_alerts)
                logger.info(f"Ingested {len(weather_alerts)} weather alerts from Open-Meteo.")
            except Exception as e:
                logger.error(f"Weather alert ingestion failed: {e}")

            # 2. Disaster / Seismic Hazards (USGS)
            try:
                disaster_alerts = await disaster_collector.collect_live_disasters()
                raw_alerts.extend(disaster_alerts)
                logger.info(f"Ingested {len(disaster_alerts)} disaster alerts from USGS.")
            except Exception as e:
                logger.error(f"Disaster alert ingestion failed: {e}")

            # 3. Curated Mountain Corridors & Road Advisories
            try:
                advisories = advisory_collector.collect_advisories()
                raw_alerts.extend(advisories)
                logger.info(f"Loaded {len(advisories)} curated corridor advisories.")
            except Exception as e:
                logger.error(f"Advisory ingestion failed: {e}")

            # 4. Optional Gemini AI Enrichment
            if enrich_with_gemini:
                for alert in raw_alerts:
                    try:
                        # Only enrich high/critical alerts or advisories needing action guidance
                        if alert.get("severity") in ["critical", "high", "moderate"]:
                            enriched_action = await alert_enrichment_service.enrich_advisory(alert)
                            alert["recommended_action"] = enriched_action
                    except Exception as e:
                        logger.warning(f"Enrichment pass error for {alert.get('id')}: {e}")

            # 5. Database Transaction
            saved_count = 0
            now_utc = datetime.now(timezone.utc)
            db: Session = SessionLocal()
            try:
                for a in raw_alerts:
                    alert_id = a["id"]
                    existing: Notification = db.query(Notification).filter(Notification.id == alert_id).first()

                    if existing:
                        # Update existing alert (avoid duplicate rows)
                        existing.category = a.get("category", existing.category)
                        existing.severity = a.get("severity", existing.severity)
                        existing.title = a.get("title", existing.title)
                        existing.location = a.get("location", existing.location)
                        existing.city = a.get("city", existing.city)
                        existing.latitude = a.get("latitude", existing.latitude)
                        existing.longitude = a.get("longitude", existing.longitude)
                        existing.description = a.get("description", existing.description)
                        existing.recommended_action = a.get("recommended_action", existing.recommended_action)
                        existing.source = a.get("source", existing.source)
                        existing.expires_at = a.get("expires_at", existing.expires_at)
                        existing.is_active = True
                        existing.updated_at = now_utc
                        if a.get("raw_data"):
                            existing.raw_data = a["raw_data"]
                    else:
                        # Insert new alert record
                        new_record = Notification(
                            id=alert_id,
                            category=a["category"],
                            severity=a["severity"],
                            title=a["title"],
                            location=a["location"],
                            city=a["city"],
                            latitude=a.get("latitude"),
                            longitude=a.get("longitude"),
                            description=a["description"],
                            recommended_action=a.get("recommended_action"),
                            source=a["source"],
                            is_active=True,
                            created_at=a.get("created_at", now_utc),
                            expires_at=a.get("expires_at"),
                            updated_at=now_utc,
                            raw_data=a.get("raw_data"),
                        )
                        db.add(new_record)
                    saved_count += 1

                # Deactivate expired records
                expired_records = db.query(Notification).filter(
                    Notification.expires_at.isnot(None),
                    Notification.expires_at < now_utc,
                    Notification.is_active == True,  # noqa: E712
                ).all()
                for exp in expired_records:
                    exp.is_active = False
                    exp.updated_at = now_utc

                db.commit()
                self._last_sync_time = now_utc
                logger.info(f"Notification sync completed successfully: {saved_count} records processed, {len(expired_records)} expired deactivated.")
            except Exception as db_err:
                db.rollback()
                logger.error(f"Failed to commit alerts into SQLite: {db_err}")
                raise db_err
            finally:
                db.close()

            return saved_count


notification_sync_service = NotificationSyncService()
