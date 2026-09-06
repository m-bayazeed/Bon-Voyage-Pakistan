import asyncio
import json
import logging
import re
from typing import Any, Dict, List, Optional
from google import genai
from google.genai import types
from app.core.config import settings
from app.models.hotel import StayItem

logger = logging.getLogger(__name__)


class HotelEnrichmentService:
    """Service to enrich hotel stay items using Google Gemini with strict factual guardrails."""

    def __init__(self):
        self._client: Optional[genai.Client] = None
        # Cache for enriched descriptions by place ID
        self._cache: Dict[str, Dict[str, Any]] = {}

    def _get_client(self) -> Optional[genai.Client]:
        api_key = settings.GEMINI_API_KEY
        if not api_key:
            return None
        if self._client is None:
            self._client = genai.Client(api_key=api_key)
        return self._client

    async def enrich_stays(
        self, stays: List[StayItem], center_label: Optional[str] = None
    ) -> List[StayItem]:
        """
        Enrich a batch of stays with Gemini-generated descriptions, highlights, and verified amenities.
        Uses in-memory caching to avoid duplicate requests.
        """
        if not stays:
            return []

        # Find items that need enrichment
        to_enrich_indices: List[int] = []
        for i, s in enumerate(stays):
            if s.id in self._cache:
                cached = self._cache[s.id]
                s.description = cached.get("description") or s.description
                s.highlight = cached.get("highlight") or s.highlight
                if cached.get("amenities"):
                    s.amenities = cached["amenities"]
                if cached.get("badge_label"):
                    s.badge_label = cached["badge_label"]
            else:
                to_enrich_indices.append(i)

        if not to_enrich_indices:
            return stays

        # Limit batch size to top 15 for fast response
        target_indices = to_enrich_indices[:15]
        target_stays = [stays[idx] for idx in target_indices]

        # Prepare factual data payload for Gemini
        places_input = []
        for s in target_stays:
            places_input.append({
                "id": s.id,
                "name": s.name,
                "address": s.full_address or s.address,
                "city": s.city,
                "category": s.category,
                "badge_label": s.badge_label,
                "website": s.website,
                "phone": s.phone,
            })

        prompt = f"""You are a travel information assistant for tourists exploring Pakistan.
Enrich the following factual accommodations near {center_label or 'the destination'}.

Input Stays Data:
{json.dumps(places_input, indent=2)}

STRICT RULES:
1. Use ONLY information provided in the input data. Do NOT invent prices, ratings, review counts, coordinates, availability, or unverified amenities.
2. For each stay, provide:
   - "description": A concise, natural, 1-2 sentence travel-friendly summary based strictly on the property name, location, and category.
   - "highlight": A short 3-6 word factual feature or location tag (e.g. "Centrally located stay", "Scenic mountain setting", "Riverside lodge").
   - "amenities": A list of amenities evident from property type/category (e.g. "Free Wi-Fi", "Free Parking", "Room Service", "Mountain View" if resort).
3. Return ONLY a valid JSON list of objects matching this schema:
[
  {{
    "id": "place-id",
    "description": "Concise natural description.",
    "highlight": "Short highlight",
    "amenities": ["Amenity 1", "Amenity 2"]
  }}
]
Do NOT include markdown fences, code blocks, or extra text."""

        enriched_data: List[Dict[str, Any]] = []
        client = self._get_client()

        if client:
            candidate_models = settings.GEMINI_FALLBACK_MODELS
            unique_models = [m for m in dict.fromkeys(candidate_models) if m]


            config = types.GenerateContentConfig(
                temperature=0.2,
            )
            for model_name in unique_models:
                try:
                    logger.info(f"[HotelEnrichment] Requesting Gemini enrichment with {model_name}...")
                    response = await asyncio.wait_for(
                        client.aio.models.generate_content(
                            model=model_name,
                            contents=prompt,
                            config=config,
                        ),
                        timeout=3.5,
                    )

                    if response.text:
                        clean_text = response.text.strip()
                        if clean_text.startswith("```"):
                            clean_text = re.sub(r"^```(?:json)?\s*", "", clean_text)
                            clean_text = re.sub(r"\s*```$", "", clean_text)

                        parsed = json.loads(clean_text)
                        if isinstance(parsed, list):
                            enriched_data = parsed
                            break
                except Exception as e:
                    logger.warning(f"[HotelEnrichment] Gemini model {model_name} error/timeout: {e}")
                    if "RESOURCE_EXHAUSTED" in str(e) or "429" in str(e) or "Quota exceeded" in str(e):
                        logger.info("[HotelEnrichment] Gemini quota exhausted, skipping to fallback.")
                        break

        # Fallback to Groq if Gemini failed
        if not enriched_data:
            try:
                from app.services.groq_service import groq_service
                groq_client = groq_service._get_client()
                if groq_client:
                    logger.info("[HotelEnrichment] Falling back to Groq for enrichment...")
                    chat_completion = await asyncio.wait_for(
                        groq_client.chat.completions.create(
                            messages=[
                                {"role": "system", "content": "You are a concise travel assistant. Return only valid JSON."},
                                {"role": "user", "content": prompt},
                            ],
                            model="llama-3.3-70b-versatile",
                            temperature=0.2,
                        ),
                        timeout=4.0,
                    )
                    content = chat_completion.choices[0].message.content
                    if content:
                        clean_text = content.strip()
                        if clean_text.startswith("```"):
                            clean_text = re.sub(r"^```(?:json)?\s*", "", clean_text)
                            clean_text = re.sub(r"\s*```$", "", clean_text)
                        parsed = json.loads(clean_text)
                        if isinstance(parsed, list):
                            enriched_data = parsed
            except Exception as e:
                logger.warning(f"[HotelEnrichment] Groq fallback error: {e}")

        # Map enrichment data back to stays
        enrichment_map = {item.get("id"): item for item in enriched_data if isinstance(item, dict) and item.get("id")}

        for stay in target_stays:
            enriched_item = enrichment_map.get(stay.id)
            if enriched_item:
                desc = enriched_item.get("description")
                highlight = enriched_item.get("highlight")
                amenities = enriched_item.get("amenities")

                if desc and isinstance(desc, str):
                    stay.description = desc.strip()
                if highlight and isinstance(highlight, str):
                    stay.highlight = highlight.strip()
                if amenities and isinstance(amenities, list):
                    stay.amenities = [str(a).strip() for a in amenities if a]

                self._cache[stay.id] = {
                    "description": stay.description,
                    "highlight": stay.highlight,
                    "amenities": stay.amenities,
                    "badge_label": stay.badge_label,
                }
            else:
                # Safe deterministic enrichment if AI was unreachable
                if not stay.description or "located at" in stay.description:
                    stay.description = f"{stay.name} offers comfortable {stay.badge_label.lower()} accommodation in {stay.city or 'Pakistan'}."
                if not stay.highlight:
                    stay.highlight = f"Verified {stay.badge_label}"

                self._cache[stay.id] = {
                    "description": stay.description,
                    "highlight": stay.highlight,
                    "amenities": stay.amenities,
                    "badge_label": stay.badge_label,
                }

        return stays


hotel_enrichment_service = HotelEnrichmentService()
