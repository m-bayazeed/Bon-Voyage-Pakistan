import os
from pathlib import Path
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session

# Data directory for SQLite alerts database
BACKEND_APP_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BACKEND_APP_DIR / "data"
DATA_DIR.mkdir(parents=True, exist_ok=True)

ALERTS_DB_PATH = DATA_DIR / "alerts.db"
SQLALCHEMY_DATABASE_URL = f"sqlite:///{ALERTS_DB_PATH}"

# SQLite requires check_same_thread=False for multi-threaded FastAPI / APScheduler requests
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    echo=False,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    """FastAPI Dependency for database session."""
    db: Session = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    """Create all database tables if they do not exist."""
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    Base.metadata.create_all(bind=engine)
