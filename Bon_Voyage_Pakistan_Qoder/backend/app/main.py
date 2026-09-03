import asyncio
import logging
from typing import Optional
from fastapi import FastAPI, HTTPException, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from apscheduler.schedulers.asyncio import AsyncIOScheduler

from app.api.v1.translator import router as translator_router
from app.api.v1.hotels import router as hotels_router
from app.api.v1.food import router as food_router
from app.api.v1.help import router as help_router
from app.api.v1.routes import router as routes_router
from app.api.v1.landmarks import router as landmarks_router
from app.api.v1.notifications import router as notifications_router
from app.core.config import settings
from app.db.database import init_db
from app.services.notification_sync_service import notification_sync_service

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

# Background Scheduler for 30-minute Periodic Notifications & Advisories Synchronization
scheduler: Optional[AsyncIOScheduler] = None

# Initialize FastAPI Application
app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="Production-ready FastAPI backend for Bon Voyage Pakistan with Gemini, Live Weather, USGS Seismic Alerts, Groq Whisper, and Edge-TTS.",
    docs_url="/docs",
    redoc_url="/redoc",
)

# Configure CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Custom Exception Handlers ──

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    """Format HTTPExceptions into standard error JSON."""
    return JSONResponse(
        status_code=exc.status_code,
        content={"success": False, "error": exc.detail},
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """Format Pydantic validation errors cleanly."""
    errors = []
    for err in exc.errors():
        field = " -> ".join([str(loc) for loc in err.get("loc", []) if loc != "body"])
        msg = err.get("msg", "Invalid value")
        errors.append(f"{field}: {msg}" if field else msg)

    error_message = "; ".join(errors) if errors else "Invalid request data."
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={"success": False, "error": error_message},
    )


@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    """Catch-all for unexpected internal server errors."""
    logger.exception(f"Unhandled exception during request processing: {exc}")
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"success": False, "error": "An unexpected server error occurred. Please try again later."},
    )


# ── Startup & Shutdown Lifecycle Events ──

async def _run_periodic_alert_sync():
    """Periodic job triggered every 30 minutes by APScheduler."""
    try:
        logger.info("Executing scheduled 30-minute notification & travel advisory refresh...")
        count = await notification_sync_service.sync_all_alerts(enrich_with_gemini=True)
        logger.info(f"Scheduled 30-minute sync finished: {count} records cached.")
    except Exception as e:
        logger.error(f"Scheduled 30-minute alert sync encountered error: {e}")


@app.on_event("startup")
async def startup_event():
    global scheduler
    gemini_configured = bool(settings.GEMINI_API_KEY)
    logger.info("=" * 55)
    logger.info("BON VOYAGE PAKISTAN BACKEND STARTUP")
    logger.info("FastAPI running: YES")
    logger.info(f"Gemini API key configured: {'YES' if gemini_configured else 'NO'}")
    logger.info("=" * 55)

    # 1. Initialize SQLite Database Schema
    try:
        init_db()
        logger.info("SQLite Alerts database initialized successfully.")
    except Exception as e:
        logger.error(f"Failed to initialize SQLite alerts database: {e}")

    # 2. Trigger Initial Alert Synchronization
    asyncio.create_task(notification_sync_service.sync_all_alerts(enrich_with_gemini=True))

    # 3. Start 30-minute APScheduler
    try:
        if scheduler is None or not scheduler.running:
            scheduler = AsyncIOScheduler()
            scheduler.add_job(
                _run_periodic_alert_sync,
                "interval",
                minutes=30,
                id="periodic_alerts_sync_job",
                replace_existing=True,
            )
            scheduler.start()
            logger.info("APScheduler initialized: Periodic 30-minute alert sync active.")
    except Exception as e:
        logger.error(f"Failed to start APScheduler: {e}")


@app.on_event("shutdown")
async def shutdown_event():
    global scheduler
    if scheduler and scheduler.running:
        logger.info("Shutting down APScheduler...")
        scheduler.shutdown(wait=False)
        logger.info("APScheduler shutdown complete.")


# ── Health Check Endpoint ──

@app.get(
    "/health",
    tags=["System"],
    summary="Service Health Check",
    description="Returns the operational status and Gemini configuration of the backend.",
)
async def health_check():
    """Health check endpoint."""
    gemini_configured = bool(settings.GEMINI_API_KEY)
    return {
        "status": "ok",
        "service": "bon-voyage-backend",
        "fastapi_running": "YES",
        "gemini_api_key_configured": "YES" if gemini_configured else "NO",
        "scheduler_running": "YES" if (scheduler and scheduler.running) else "NO",
    }


# ── Include API Routers ──
app.include_router(translator_router, prefix=settings.API_V1_STR)
app.include_router(hotels_router, prefix=settings.API_V1_STR)
app.include_router(food_router, prefix=settings.API_V1_STR)
app.include_router(help_router, prefix=settings.API_V1_STR)
app.include_router(routes_router, prefix=settings.API_V1_STR)
app.include_router(landmarks_router, prefix=settings.API_V1_STR)
app.include_router(notifications_router, prefix=settings.API_V1_STR)


@app.post(
    "/api/v1/tts/story",
    tags=["TTS"],
    summary="Synthesize Story Audio Endpoint",
    description="Synthesizes AI landmark story text using Groq / Neural TTS.",
)
async def tts_story_direct(request: dict):
    from app.services.landmark_service import landmark_service
    text = request.get("text", "")
    language = request.get("language", "en")
    result = await landmark_service.synthesize_story_audio(text=text, language=language)
    return result.model_dump()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)

