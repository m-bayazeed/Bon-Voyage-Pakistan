from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from sqlalchemy import Boolean, Column, DateTime, Float, Index, String, Text
from pydantic import BaseModel, ConfigDict, Field
from app.db.database import Base


class Notification(Base):
    """SQLAlchemy Notification & Travel Advisory Record."""

    __tablename__ = "notifications"

    id = Column(String(100), primary_key=True, index=True)
    category = Column(String(50), nullable=False, index=True)  # weather, roadCondition, naturalDisaster, publicSafety, advisory
    severity = Column(String(30), nullable=False, index=True)  # critical, high, moderate, informational
    title = Column(String(255), nullable=False)
    location = Column(String(255), nullable=False)
    city = Column(String(100), nullable=False, index=True)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    description = Column(Text, nullable=False)
    recommended_action = Column(Text, nullable=True)
    source = Column(String(255), nullable=False)
    is_active = Column(Boolean, default=True, index=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    expires_at = Column(DateTime, nullable=True)
    updated_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    raw_data = Column(Text, nullable=True)

    __table_args__ = (
        Index("ix_city_category_active", "city", "category", "is_active"),
    )


# ── Pydantic Schemas for API Serialization ──

class NotificationResponse(BaseModel):
    """Notification Schema perfectly compatible with Flutter TravelAlert model and REST standards."""

    model_config = ConfigDict(populate_by_name=True, from_attributes=True)

    id: str
    type: str = Field(..., description="Alert Category matching Flutter Enum (weather, roadCondition, naturalDisaster, publicSafety, advisory)")
    category: str = Field(..., description="Category alias")
    severity: str = Field(..., description="Alert severity (critical, high, moderate, informational)")
    title: str
    description: str
    summary: str = Field(..., description="Summary alias for description")
    location: str
    city: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    createdAt: str = Field(..., description="ISO 8601 created date for Flutter")
    created_at: str = Field(..., description="ISO 8601 created date alias")
    expiresAt: Optional[str] = Field(None, description="ISO 8601 expires date")
    expires_at: Optional[str] = Field(None, description="ISO 8601 expires date alias")
    source: str
    recommendedAction: Optional[str] = Field(None, description="Recommended travel action for Flutter")
    recommended_action: Optional[str] = Field(None, description="Recommended travel action alias")
    detailed_advisory: Optional[str] = Field(None, description="Detailed advisory alias")
    isRead: bool = False
    is_active: bool = True
    details: Optional[Dict[str, Any]] = None

    @classmethod
    def from_orm_model(cls, n: Notification) -> "NotificationResponse":
        iso_created = n.created_at.isoformat() if n.created_at else datetime.now(timezone.utc).isoformat()
        iso_expires = n.expires_at.isoformat() if n.expires_at else None

        # Standard category mapping
        cat = n.category or "advisory"
        sev = n.severity or "moderate"

        return cls(
            id=n.id,
            type=cat,
            category=cat,
            severity=sev,
            title=n.title or "Travel Notice",
            description=n.description or "",
            summary=n.description or "",
            location=n.location or "Pakistan",
            city=n.city or "National",
            latitude=n.latitude,
            longitude=n.longitude,
            createdAt=iso_created,
            created_at=iso_created,
            expiresAt=iso_expires,
            expires_at=iso_expires,
            source=n.source or "National Travel Authority",
            recommendedAction=n.recommended_action,
            recommended_action=n.recommended_action,
            detailed_advisory=n.recommended_action,
            isRead=False,
            is_active=bool(n.is_active),
            details={
                "source_agency": n.source,
                "is_active": bool(n.is_active),
                "latitude": n.latitude,
                "longitude": n.longitude,
            },
        )


class NotificationListResponse(BaseModel):
    """Root response object returned to Flutter and API clients."""

    success: bool = True
    total: int
    selected_city: Optional[str] = None
    selected_category: Optional[str] = None
    alerts: List[NotificationResponse]
