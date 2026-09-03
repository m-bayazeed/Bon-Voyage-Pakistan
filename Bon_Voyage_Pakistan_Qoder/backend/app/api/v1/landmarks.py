import logging
from typing import Optional
from fastapi import APIRouter, File, Form, HTTPException, UploadFile, status
from app.models.landmark import LandmarkResponse, StoryAudioRequest, StoryAudioResponse
from app.services.landmark_service import landmark_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/landmarks", tags=["Scan & Search Landmarks"])


@router.post(
    "/scan",
    response_model=LandmarkResponse,
    status_code=status.HTTP_200_OK,
    summary="Scan & Identify Pakistani Landmark with Gemini Multimodal Vision",
    description="Accepts an uploaded image of a landmark, validates it with Pillow, analyzes it with Gemini Multimodal Vision, and returns structured historical information.",
)
async def scan_landmark(
    image: UploadFile = File(..., description="Uploaded image file (JPEG, PNG, WEBP, JFIF, max 10MB)"),
    latitude: Optional[float] = Form(None, description="Optional device latitude context"),
    longitude: Optional[float] = Form(None, description="Optional device longitude context"),
):
    """
    Identifies a Pakistani landmark from an uploaded image.
    
    Pipeline:
    1. Multipart image upload
    2. Pillow format & corruption validation
    3. Gemini Multimodal Vision landmark identification
    4. Structured historical information extraction
    5. Clean JSON response
    """
    if not image or not image.filename:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please select or capture an image first.",
        )

    logger.info(f"[SCAN] Request received on /api/v1/landmarks/scan. Filename='{image.filename}', Content-Type='{image.content_type}'")

    try:
        image_bytes = await image.read()
    except Exception as e:
        logger.error(f"[SCAN] Failed to read uploaded image bytes: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to read the uploaded image file.",
        )

    if not image_bytes or len(image_bytes) == 0:
        logger.warning("[SCAN] Uploaded image is empty.")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please select or capture an image first.",
        )

    try:
        response = await landmark_service.identify_landmark(
            image_bytes=image_bytes,
            filename=image.filename,
            content_type=image.content_type,
            latitude=latitude,
            longitude=longitude,
        )
        logger.info(f"[SCAN] Sending response to client: success={response.success}, identified={response.identified}, landmark='{response.landmark_name}'")
        return response
    except ValueError as val_err:
        logger.warning(f"[SCAN] Landmark scan validation error: {val_err}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(val_err),
        )
    except Exception as exc:
        logger.exception(f"[SCAN] Unhandled technical error during landmark identification: {exc}")
        return LandmarkResponse(
            success=False,
            identified=False,
            confidence=0.0,
            message="Unable to analyze this image right now. Please try again.",
        )



@router.post(
    "/story-audio",
    response_model=StoryAudioResponse,
    status_code=status.HTTP_200_OK,
    summary="Synthesize Landmark Audio Story via Groq/Neural TTS",
    description="Generates spoken narration audio for the AI landmark story using Groq / Neural TTS.",
)
async def story_audio_endpoint(request: StoryAudioRequest) -> StoryAudioResponse:
    """Endpoint for landmark story speech synthesis."""
    from app.models.landmark import StoryAudioResponse
    return await landmark_service.synthesize_story_audio(
        text=request.text,
        language=request.language or "en",
    )
