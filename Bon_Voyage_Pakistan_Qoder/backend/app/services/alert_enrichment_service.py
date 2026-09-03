import asyncio
import logging
import time
from typing import Dict, Optional
from google import genai
from app.core.config import settings

logger = logging.getLogger(__name__)


class AlertEnrichmentService:
    """Enriches real travel alerts with tourist-friendly practical guidance using Gemini AI and Groq fallback."""

    def __init__(self):
        self._client: Optional[genai.Client] = None
        self._quota_cooldown_until: float = 0.0

    def _get_client(self) -> Optional[genai.Client]:
        api_key = settings.GEMINI_API_KEY
        if not api_key:
            return None
        if self._client is None:
            try:
                self._client = genai.Client(api_key=api_key)
            except Exception as e:
                logger.warning(f"Failed to initialize Gemini client for AlertEnrichmentService: {e}")
                return None
        return self._client

    def _enrich_sync(self, alert_data: Dict) -> Optional[str]:
        """Synchronous generation using Gemini with quota awareness."""
        if time.time() < self._quota_cooldown_until:
            return None

        client = self._get_client()
        if not client:
            return None

        prompt = f"""You are a professional travel safety coordinator for tourists in Pakistan.
Review this REAL verified travel alert condition and provide a concise, actionable 1 to 2 sentence safety recommendation for domestic and international travelers:

Title: {alert_data.get('title')}
Category: {alert_data.get('category')}
Severity: {alert_data.get('severity')}
Location: {alert_data.get('location')} ({alert_data.get('city')})
Summary: {alert_data.get('description')}
Official Source: {alert_data.get('source')}

Strict Constraints:
1. ONLY elaborate on what travelers should do (e.g., equipment like snow chains, low gears, daylight travel only, helpline contacts, alternate corridors).
2. DO NOT invent or change any facts, weather numbers, locations, dates, or official source names.
3. Keep the advice concise, professional, and max 2 sentences.
4. Return ONLY plain text without quotation marks or markdown asterisks."""

        candidate_models = settings.GEMINI_FALLBACK_MODELS
        unique_models = [m for m in dict.fromkeys(candidate_models) if m]


        for model_name in unique_models:
            try:
                response = client.models.generate_content(
                    model=model_name,
                    contents=prompt,
                )
                text = (response.text or "").strip()
                if text:
                    return text.strip('"\'')
            except Exception as e:
                err_str = str(e)
                if "429" in err_str or "RESOURCE_EXHAUSTED" in err_str:
                    logger.info("Gemini quota rate limit hit, setting 60s cooldown and engaging Groq fallback.")
                    self._quota_cooldown_until = time.time() + 60.0
                    return None
                logger.debug(f"Gemini model {model_name} attempt note: {e}")

        return None

    async def _fallback_groq_enrich(self, alert_data: Dict) -> Optional[str]:
        """Fallback to Groq AI when Gemini quota is exhausted."""
        try:
            from app.services.groq_service import groq_service
            groq_client = groq_service._get_client()
            if not groq_client:
                return None

            prompt = f"""You are a travel safety coordinator for Pakistan.
Provide a concise 1-2 sentence travel safety recommendation for tourists based on this alert:
Condition: {alert_data.get('title')} at {alert_data.get('location')} ({alert_data.get('city')}).
Details: {alert_data.get('description')}
Source: {alert_data.get('source')}
Return ONLY the concise safety instruction (e.g., gear, daylight travel, contact helpline), no extra text."""

            response = await groq_client.chat.completions.create(
                model="llama-3.1-8b-instant",
                messages=[
                    {"role": "system", "content": "You are a concise travel safety advisor for tourists in Pakistan. Never invent facts."},
                    {"role": "user", "content": prompt},
                ],
                temperature=0.2,
                max_tokens=150,
            )
            content = (response.choices[0].message.content or "").strip()
            if content and len(content) > 10:
                return content.strip('"\'')
        except Exception as e:
            logger.debug(f"Groq fallback note: {e}")
        return None

    async def enrich_advisory(self, alert_data: Dict) -> str:
        """
        Enriches the alert's recommended action using Gemini or Groq fallback.
        If both are unavailable, returns the original recommended action safely.
        """
        original_action = alert_data.get("recommended_action") or "Exercise caution and follow local administration directives."

        # 1. Try Gemini
        try:
            enriched = await asyncio.to_thread(self._enrich_sync, alert_data)
            if enriched and len(enriched) > 10:
                return enriched
        except Exception as e:
            logger.debug(f"Gemini enrichment pass error: {e}")

        # 2. Try Groq AI Fallback
        try:
            groq_enriched = await self._fallback_groq_enrich(alert_data)
            if groq_enriched and len(groq_enriched) > 10:
                return groq_enriched
        except Exception as e:
            logger.debug(f"Groq enrichment pass error: {e}")

        # 3. Always return valid default original action
        return original_action


alert_enrichment_service = AlertEnrichmentService()
