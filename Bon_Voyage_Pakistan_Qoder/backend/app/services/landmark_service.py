import asyncio
import io
import json
import logging
import re
from typing import Optional, Tuple
from PIL import Image, UnidentifiedImageError
from google import genai
from google.genai import types

from app.core.config import settings
from app.models.landmark import LandmarkResponse

logger = logging.getLogger(__name__)

# Max upload size: 10 MB
MAX_IMAGE_SIZE_BYTES = 10 * 1024 * 1024

SUPPORTED_IMAGE_MIMES = {
    "image/jpeg": "image/jpeg",
    "image/jpg": "image/jpeg",
    "image/png": "image/png",
    "image/webp": "image/webp",
    "image/jfif": "image/jpeg",
}

SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".jfif"}


class LandmarkService:
    """Production service for AI Landmark Identification using Gemini Multimodal Vision."""

    def __init__(self):
        self._client: Optional[genai.Client] = None

    def _get_client(self) -> genai.Client:
        api_key = settings.GEMINI_API_KEY
        if not api_key:
            logger.error("[SCAN] Gemini API key configured: NO")
            raise RuntimeError(
                "Gemini API Key is not configured. Please set GEMINI_API_KEY in backend/.env"
            )
        if self._client is None:
            logger.info("[SCAN] Gemini API key configured: YES")
            self._client = genai.Client(
                api_key=api_key,
                http_options={"timeout": 120000},
            )
        return self._client

    def validate_and_process_image(
        self,
        image_bytes: bytes,
        filename: Optional[str] = None,
        content_type: Optional[str] = None,
    ) -> Tuple[bytes, str]:
        """
        Validates the uploaded image using Pillow.
        Checks size, format, and corruption. Returns sanitized image bytes and MIME type.
        """
        size_kb = len(image_bytes) / 1024.0 if image_bytes else 0.0
        logger.info(f"[SCAN] Image received: Filename='{filename or 'unknown'}', Content-Type='{content_type or 'unknown'}', Size={size_kb:.1f} KB")

        if not image_bytes or len(image_bytes) == 0:
            logger.warning("[SCAN] Image validation failed: Empty upload.")
            raise ValueError("Please select or capture an image first.")

        if len(image_bytes) > MAX_IMAGE_SIZE_BYTES:
            logger.warning(f"[SCAN] Image validation failed: Exceeds 10MB ({size_kb:.1f} KB).")
            raise ValueError("Uploaded image exceeds the 10 MB maximum limit.")

        try:
            # Validate with Pillow
            with Image.open(io.BytesIO(image_bytes)) as pil_img:
                pil_format = (pil_img.format or "").upper()
                if pil_format not in ["JPEG", "JPG", "PNG", "WEBP"]:
                    logger.warning(f"[SCAN] Unsupported format: {pil_format}")
                    raise ValueError(
                        f"Unsupported image format ({pil_format}). Supported formats: JPEG, JPG, PNG, WEBP, JFIF."
                    )

                # Determine clean MIME type
                if pil_format in ["JPEG", "JPG"]:
                    mime_type = "image/jpeg"
                elif pil_format == "PNG":
                    mime_type = "image/png"
                elif pil_format == "WEBP":
                    mime_type = "image/webp"
                else:
                    mime_type = "image/jpeg"

                # Verify image can be decoded and loaded
                pil_img.load()
                logger.info(f"[SCAN] Image validated successfully with Pillow (Format={pil_format}, MIME={mime_type}, Dimensions={pil_img.width}x{pil_img.height})")

                # If image is excessively large in dimension, optimize slightly without losing quality
                max_dimension = 2048
                if pil_img.width > max_dimension or pil_img.height > max_dimension:
                    pil_img.thumbnail((max_dimension, max_dimension), Image.Resampling.LANCZOS)
                    out_buffer = io.BytesIO()
                    save_format = "PNG" if pil_format == "PNG" else "JPEG"
                    if save_format == "JPEG" and pil_img.mode in ("RGBA", "P"):
                        pil_img = pil_img.convert("RGB")
                    pil_img.save(out_buffer, format=save_format, quality=92)
                    return out_buffer.getvalue(), mime_type

                return image_bytes, mime_type

        except UnidentifiedImageError:
            raise ValueError("The selected file is not a valid image or is corrupted.")
        except Exception as e:
            if "Unsupported image format" in str(e) or "exceeds" in str(e) or "Please select" in str(e):
                raise
            logger.warning(f"Pillow image validation warning: {e}")
            raise ValueError(f"The selected file is not a valid image: {e}")

    def _extract_json_from_text(self, text: str) -> dict:
        """Robustly extracts and parses JSON from Gemini output with markdown fence stripping."""
        cleaned = text.strip()
        # Strip ```json ... ``` or ``` ... ```
        if cleaned.startswith("```"):
            cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
            cleaned = re.sub(r"\s*```$", "", cleaned)
            cleaned = cleaned.strip()

        # Try direct parse
        try:
            return json.loads(cleaned)
        except json.JSONDecodeError:
            pass

        # Try finding JSON object substring
        match = re.search(r"\{[\s\S]*\}", cleaned)
        if match:
            try:
                return json.loads(match.group(0))
            except json.JSONDecodeError as err:
                logger.error(f"Failed to parse matched JSON substring: {err}")

        raise ValueError("Could not parse a valid JSON response from the AI model.")

    async def _optional_places_verification(
        self,
        landmark_name: str,
        city_or_region: Optional[str] = None,
    ) -> Optional[dict]:
        """
        Optional enrichment/verification layer using Google Places Text Search.
        Strictly used to verify landmark existence and normalize city name.
        Does NOT return map coordinates or directions.
        """
        try:
            from app.services.google_places_service import google_places_service
            if not settings.GOOGLE_PLACES_API_KEY:
                return None

            query = f"{landmark_name}, {city_or_region or 'Pakistan'}"
            places = await google_places_service.search_text(
                text_query=query,
                max_results=3,
            )
            if places and len(places) > 0:
                first_place = places[0]
                return {
                    "verified_name": first_place.name or landmark_name,
                    "formatted_address": first_place.formatted_address,
                }
        except Exception as e:
            logger.info(f"Optional Google Places verification skipped: {e}")
        return None

    def _call_gemini_vision(
        self,
        image_bytes: bytes,
        mime_type: str,
        latitude: Optional[float] = None,
        longitude: Optional[float] = None,
    ) -> LandmarkResponse:
        """Synchronous Gemini Multimodal Vision call with multi-model fallback."""
        client = self._get_client()

        gps_context = ""
        if latitude is not None and longitude is not None:
            gps_context = f"\nUser Location Context: Latitude {latitude:.4f}, Longitude {longitude:.4f} (use only as subtle context, do not force a match)."

        prompt = f"""You are an expert architectural historian and cultural heritage specialist for Pakistan.
Analyze the provided image to determine whether it depicts a recognizable Pakistani landmark, historical monument, heritage site, or iconic architectural structure.{gps_context}

Pakistani landmarks include (but are not limited to):
- Lahore Fort (Shahi Qila), Badshahi Mosque, Minar-e-Pakistan, Shalimar Gardens, Wazir Khan Mosque, Chauburji, Jahangir's Tomb
- Rohtas Fort (Jhelum), Mohenjo-daro (Larkana), Taxila / Dharmarajika Stupa, Pakistan Monument (Islamabad), Faisal Mosque (Islamabad)
- Baltit Fort (Hunza), Altit Fort (Hunza), Derawar Fort (Bahawalpur), Makli Necropolis (Thatta), Katas Raj Temples (Chakwal)
- Tomb of Shah Rukn-e-Alam (Multan), Noor Mahal (Bahawalpur), Hiran Minar (Sheikhupura), Ranikot Fort (Jamshoro), etc.

STRICT INSTRUCTIONS - DO NOT GUESS:
1. Examine the visual characteristics: architectural period, monument shape, minarets, domes, masonry, arches, tilework, fortress walls, landscape context.
2. If the image clearly shows a recognizable Pakistani landmark with sufficient confidence (confidence >= 0.65), set "identified": true.
3. If the image is unclear, blurry, shows an ordinary non-landmark building, personal portrait, random object, animal, food, or non-Pakistani landmark, you MUST set "identified": false, "landmark_name": null, "confidence": 0.0, and "message": "The landmark could not be identified reliably from this image."
4. DO NOT fabricate or invent landmark names, dates, historical events, rulers, or facts. Provide only authentic, verified historical and architectural information.
5. 'things_to_do' MUST strictly be actionable visitor activities, tourist experiences, exploration highlights, and practical things to do (e.g. 'Explore the grand prayer hall', 'Photograph the minarets at sunset', 'Visit the heritage museum', 'Sample street food at the nearby food street'). DO NOT put historical milestones, construction dates, rulers, or past history in 'things_to_do'.
6. Return ONLY a valid JSON object matching the following schema:

{{
  "identified": true or false,
  "confidence": 0.95 (float from 0.0 to 1.0),
  "landmark_name": "Exact Name of Landmark in English (e.g. Badshahi Mosque)" or null,
  "city_or_region": "City/Region, Province (e.g. Lahore, Punjab)" or null,
  "historical_era": "Historical Era (e.g. Mughal Era - 17th Century)" or null,
  "history_overview": "Concise 2-3 sentence historical background" or null,
  "historical_events": [
    "Key historical milestone or date 1",
    "Key historical milestone or date 2"
  ],
  "things_to_do": [
    "Engaging visitor activity 1 (e.g. Explore the grand courtyard and red sandstone arches)",
    "Engaging visitor activity 2 (e.g. Photograph the marble domes at golden hour)",
    "Engaging visitor activity 3 (e.g. Visit the on-site historical museum)",
    "Engaging visitor activity 4 (e.g. Stroll through the adjoining gardens at dusk)"
  ],
  "interesting_facts": [
    "Fascinating fact 1",
    "Fascinating fact 2",
    "Fascinating fact 3"
  ],
  "architectural_significance": "Key architectural highlights (e.g. red sandstone, white marble domes, fresco art)" or null,
  "travel_tip": "Practical visitor advice (e.g. Best visited during early morning or sunset for photography and moderate temperatures)" or null,
  "message": "Landmark identified successfully." (or descriptive reason if not identified)
}}"""

        image_part = types.Part.from_bytes(
            data=image_bytes,
            mime_type=mime_type,
        )

        candidate_models = settings.GEMINI_FALLBACK_MODELS
        unique_models = [m for m in dict.fromkeys(candidate_models) if m]

        last_err = None
        for model_name in unique_models:
            try:
                logger.info(f"[SCAN] Calling Gemini vision model: {model_name}...")
                response = client.models.generate_content(
                    model=model_name,
                    contents=[image_part, prompt],
                    config=types.GenerateContentConfig(
                        temperature=0.1,
                        response_mime_type="application/json",
                    ),
                )

                raw_text = response.text or ""
                logger.info(f"[SCAN] Gemini response received from {model_name} (length: {len(raw_text)} chars)")
                if not raw_text.strip():
                    continue

                logger.info("[SCAN] Parsing Gemini response...")
                parsed = self._extract_json_from_text(raw_text)

                identified = bool(parsed.get("identified", False))
                confidence = float(parsed.get("confidence", 0.0) or 0.0)
                landmark_name = parsed.get("landmark_name")

                logger.info(f"[SCAN] Returning real result: identified={identified}, landmark='{landmark_name}', confidence={confidence}")

                # Confidence threshold check
                if identified and confidence >= 0.60 and landmark_name:
                    city_reg = parsed.get("city_or_region") or "Pakistan"
                    raw_things = parsed.get("things_to_do") or []
                    if not raw_things:
                        raw_things = [
                            f"Explore the iconic architecture and courtyards of {landmark_name}.",
                            f"Capture panoramic photos of {landmark_name} during morning or sunset golden hour.",
                            "Discover the heritage exhibits and cultural displays on site.",
                            f"Stroll through the surrounding areas and local traditional bazaars in {city_reg}.",
                        ]
                    return LandmarkResponse(
                        success=True,
                        identified=True,
                        landmark_name=landmark_name,
                        city_or_region=city_reg,
                        historical_era=parsed.get("historical_era") or "Pakistani Heritage Site",
                        history_overview=parsed.get("history_overview") or "",
                        historical_events=parsed.get("historical_events") or [],
                        things_to_do=raw_things,
                        interesting_facts=parsed.get("interesting_facts") or [],
                        architectural_significance=parsed.get("architectural_significance") or "",
                        travel_tip=parsed.get("travel_tip") or "Open all year round for visitors.",
                        confidence=confidence,
                        message=parsed.get("message") or "Landmark identified successfully.",
                    )
                else:
                    return LandmarkResponse(
                        success=True,
                        identified=False,
                        landmark_name=None,
                        city_or_region=None,
                        historical_era=None,
                        history_overview=None,
                        historical_events=[],
                        things_to_do=[],
                        interesting_facts=[],
                        architectural_significance=None,
                        travel_tip=None,
                        confidence=0.0,
                        message=parsed.get("message") or "The landmark could not be identified reliably from this image.",
                    )

            except Exception as e:
                err_str = str(e)
                logger.warning(f"[SCAN] Gemini model {model_name} error: {err_str[:120]}")
                last_err = e
                # If authentication error, stop iterating
                if "401" in err_str or "403" in err_str or "API_KEY_INVALID" in err_str:
                    logger.error(f"[SCAN] Authentication error with Gemini API key: {e}")
                    break
                # For 404 (model not found) or 429 (quota), continue to next fallback model immediately
                continue

        if last_err:
            raise last_err
        raise ValueError("Failed to analyze image across available AI vision models.")

    async def identify_landmark(
        self,
        image_bytes: bytes,
        filename: Optional[str] = None,
        content_type: Optional[str] = None,
        latitude: Optional[float] = None,
        longitude: Optional[float] = None,
    ) -> LandmarkResponse:
        """
        Public asynchronous method to process an image and identify a Pakistani landmark.
        """
        # 1. Validate and sanitize image with Pillow
        try:
            sanitized_bytes, mime_type = self.validate_and_process_image(
                image_bytes=image_bytes,
                filename=filename,
                content_type=content_type,
            )
        except ValueError as val_err:
            logger.warning(f"[SCAN] Image validation error: {val_err}")
            return LandmarkResponse(
                success=False,
                identified=False,
                landmark_name=None,
                confidence=0.0,
                message=str(val_err),
            )

        # 2. Multimodal Vision Analysis
        try:
            result = await asyncio.to_thread(
                self._call_gemini_vision,
                sanitized_bytes,
                mime_type,
                latitude,
                longitude,
            )
        except Exception as e:
            logger.error(f"[SCAN] Landmark AI identification technical error: {e}")
            # Return clean user-facing message instead of raw Google/Gemini exception
            return LandmarkResponse(
                success=False,
                identified=False,
                landmark_name=None,
                confidence=0.0,
                message="Unable to analyze this image right now. Please check your network and try again.",
            )

        # 3. Optional Verification / Normalization with Google Places
        if result.identified and result.landmark_name and settings.GOOGLE_PLACES_API_KEY:
            try:
                verification = await self._optional_places_verification(
                    landmark_name=result.landmark_name,
                    city_or_region=result.city_or_region,
                )
                if verification and verification.get("verified_name"):
                    logger.info(f"[SCAN] Verified landmark name with Google Places: {verification['verified_name']}")
            except Exception as ve:
                logger.info(f"[SCAN] Places verification non-blocking notice: {ve}")

        return result


    async def synthesize_story_audio(
        self,
        text: str,
        language: str = "en",
    ) -> "StoryAudioResponse":
        """
        Synthesizes an AI landmark audio story using Groq / Neural TTS.
        Uses GROQ_API_KEY from environment with graceful neural TTS synthesis.
        """
        from app.models.landmark import StoryAudioResponse
        from app.services.tts_service import tts_service

        clean_text = text.strip()
        if not clean_text:
            logger.warning("[TTS] Audio synthesis requested with empty text.")
            return StoryAudioResponse(
                success=False,
                audio_base64="",
                error="INVALID_TEXT",
                message="Story text cannot be empty.",
            )

        logger.info(f"[TTS] Synthesizing landmark story audio ({len(clean_text)} chars, lang: {language})")

        # 1. Try Groq Speech if configured and supported
        groq_key = settings.GROQ_API_KEY
        if groq_key:
            try:
                from groq import AsyncGroq
                groq_client = AsyncGroq(api_key=groq_key)
                response = await groq_client.audio.speech.create(
                    model="canopylabs/orpheus-v1-english" if language.lower() == "en" else "canopylabs/orpheus-arabic-saudi",
                    voice="autumn" if language.lower() == "en" else "sulaiman",
                    input=clean_text,
                    response_format="mp3",
                )
                audio_content = response.content if hasattr(response, "content") else response.read()
                import base64
                b64 = base64.b64encode(audio_content).decode("utf-8")
                logger.info(f"[TTS] Synthesized {len(audio_content)} bytes via Groq TTS")
                return StoryAudioResponse(
                    success=True,
                    audio_base64=b64,
                    format="mp3",
                    message="Generated audio story via Groq TTS.",
                )
            except Exception as groq_err:
                logger.info(f"[TTS] Groq speech synthesis notice (falling back to Neural TTS): {groq_err}")

        # 2. Fallback to high-quality Neural TTS
        try:
            b64_audio = await tts_service.synthesize_to_base64(clean_text, language=language)
            if b64_audio:
                logger.info(f"[TTS] Synthesized audio story successfully via Neural TTS ({len(b64_audio)} chars b64)")
                return StoryAudioResponse(
                    success=True,
                    audio_base64=b64_audio,
                    format="mp3",
                    message="Generated audio story successfully.",
                )
            else:
                logger.error("[TTS] Neural TTS synthesis returned empty audio")
                return StoryAudioResponse(
                    success=False,
                    audio_base64="",
                    error="TTS_GENERATION_FAILED",
                    message="Failed to generate audio story.",
                )
        except Exception as tts_err:
            logger.error(f"[TTS] Audio story synthesis error: {tts_err}")
            return StoryAudioResponse(
                success=False,
                audio_base64="",
                error="TTS_GENERATION_FAILED",
                message=f"TTS Generation error: {str(tts_err)}",
            )


landmark_service = LandmarkService()
