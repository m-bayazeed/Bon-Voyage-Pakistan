import logging
import math
from typing import List, Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.notification import Notification, NotificationListResponse, NotificationResponse
from app.services.notification_sync_service import notification_sync_service
from app.services.disaster_collector import haversine_km

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/notifications", tags=["Notifications & Advisories"])

# Category normalizer mapping various query formats to standard database category keys
CATEGORY_MAPPING = {
    "all": "all",
    "weather": "weather",
    "wx": "weather",
    "roadcondition": "roadCondition",
    "road_condition": "roadCondition",
    "roads_passes": "roadCondition",
    "roads": "roadCondition",
    "road": "roadCondition",
    "naturaldisaster": "naturalDisaster",
    "natural_disaster": "naturalDisaster",
    "disaster": "naturalDisaster",
    "disasters": "naturalDisaster",
    "publicsafety": "publicSafety",
    "public_safety": "publicSafety",
    "safety": "publicSafety",
    "advisory": "advisory",
    "travel_advisory": "advisory",
    "travel_advisories": "advisory",
    "advisories": "advisory",
}

SEVERITY_ORDER = {
    "critical": 0,
    "high": 1,
    "moderate": 2,
    "informational": 3,
    "info": 3,
}


@router.get(
    "",
    response_model=NotificationListResponse,
    summary="Get Travel Alerts & Notifications Feed",
    description="Returns real-time weather warnings, seismic events, and highway advisories cached in SQLite.",
)
async def get_notifications(
    city: Optional[str] = Query(None, description="City or region name filter (e.g. 'Hunza Valley', 'Islamabad', 'All Pakistan')"),
    lat: Optional[float] = Query(None, description="Device GPS latitude for proximity filtering"),
    latitude: Optional[float] = Query(None, description="Alternative alias for lat"),
    lon: Optional[float] = Query(None, description="Device GPS longitude for proximity filtering"),
    lng: Optional[float] = Query(None, description="Alternative alias for lon"),
    longitude: Optional[float] = Query(None, description="Alternative alias for lon"),
    category: Optional[str] = Query("all", description="Category filter (weather, roadCondition, naturalDisaster, publicSafety, advisory, all)"),
    severity: Optional[str] = Query(None, description="Severity filter (critical, high, moderate, informational)"),
    db: Session = Depends(get_db),
):
    """Serve cached travel alerts directly from SQLite database."""
    # Resolve coordinate aliases
    user_lat = lat if lat is not None else latitude
    user_lon = lon if lon is not None else (lng if lng is not None else longitude)

    # Base query for active notifications
    query = db.query(Notification).filter(Notification.is_active == True)  # noqa: E712

    # 1. Category Filtering
    raw_cat = (category or "all").lower().strip().replace("-", "_")
    mapped_cat = CATEGORY_MAPPING.get(raw_cat, raw_cat)
    if mapped_cat and mapped_cat != "all":
        query = query.filter(Notification.category == mapped_cat)

    # 2. Severity Filtering
    if severity and severity.lower() != "all":
        query = query.filter(Notification.severity == severity.lower())

    records: List[Notification] = query.all()

    # 3. Location Filtering
    filtered_records: List[Notification] = []

    if user_lat is not None and user_lon is not None:
        # Filter by GPS Proximity: return alerts within 250 km or national alerts
        for r in records:
            if r.latitude is not None and r.longitude is not None:
                dist = haversine_km(user_lat, user_lon, r.latitude, r.longitude)
                if dist <= 250.0:
                    filtered_records.append(r)
                    continue
            # Also include national bulletins
            if r.city.lower() in ["all pakistan", "national", "all"]:
                filtered_records.append(r)
    elif city and city.strip() and city.lower() not in ["all pakistan", "all", "national"]:
        norm_city = city.lower().strip()
        for r in records:
            r_city = r.city.lower()
            r_loc = r.location.lower()
            if (
                norm_city in r_city
                or r_city in norm_city
                or norm_city in r_loc
                or r_city in ["all pakistan", "national", "all"]
            ):
                filtered_records.append(r)
    else:
        # Return all active alerts
        filtered_records = records

    # 4. Sort by severity (critical first) and newest created_at
    filtered_records.sort(
        key=lambda n: (
            SEVERITY_ORDER.get((n.severity or "").lower(), 99),
            -(n.created_at.timestamp() if n.created_at else 0),
        )
    )

    alert_responses = [NotificationResponse.from_orm_model(r) for r in filtered_records]

    return NotificationListResponse(
        success=True,
        total=len(alert_responses),
        selected_city=city or ("GPS Location" if user_lat is not None else "All Pakistan"),
        selected_category=mapped_cat,
        alerts=alert_responses,
    )


@router.post(
    "/sync",
    summary="Trigger On-Demand Alert Synchronization",
    description="Forces immediate refresh of weather, seismic, and corridor advisory cache.",
)
async def trigger_sync():
    """Trigger on-demand sync cycle."""
    count = await notification_sync_service.sync_all_alerts(enrich_with_gemini=True)
    return {"success": True, "message": f"Sync completed. Processed {count} records."}


@router.get(
    "/cities",
    summary="Get List of Monitored Pakistani Regions & Cities",
)
async def get_monitored_cities():
    """Return supported cities list for UI selector."""
    return {
        "cities": [
            "All Pakistan",
            "Hunza Valley",
            "Naran & Kaghan",
            "Skardu & Baltistan",
            "Swat & Kalam",
            "Murree & Galiyat",
            "Islamabad",
            "Lahore",
            "Karachi",
            "Peshawar",
            "Quetta & Ziarat",
        ]
    }

