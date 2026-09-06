import asyncio
import json
import logging
import re
from typing import Optional
from google import genai
from google.genai import types
from app.core.config import settings
from app.models.translator import TranslationEngineOutput

logger = logging.getLogger(__name__)


class GeminiService:
    """Service for Travel Translation using Google Gemini structured output with robust fallback."""

    def __init__(self):
        self._client: Optional[genai.Client] = None

    def _get_client(self) -> genai.Client:
        api_key = settings.GEMINI_API_KEY
        if not api_key:
            raise RuntimeError(
                "Gemini API Key is not configured. Please set GEMINI_API_KEY, GoogleAPI, or GOOGLE_API_KEY in backend/.env"
            )
        if self._client is None:
            self._client = genai.Client(api_key=api_key)
        return self._client

    def _generate_sync(self, prompt: str) -> TranslationEngineOutput:
        client = self._get_client()
        config = types.GenerateContentConfig(
            response_mime_type="application/json",
            response_schema=TranslationEngineOutput,
            temperature=0.1,
        )

        candidate_models = settings.GEMINI_FALLBACK_MODELS
        unique_models = [m for m in dict.fromkeys(candidate_models) if m]


        last_err = None
        for model_name in unique_models:
            try:
                response = client.models.generate_content(
                    model=model_name,
                    contents=prompt,
                    config=config,
                )
                raw_json = response.text
                if raw_json:
                    return TranslationEngineOutput.model_validate_json(raw_json)
            except Exception as e:
                logger.warning(f"Gemini model {model_name} failed: {e}")
                last_err = e

        if last_err:
            raise last_err
        raise ValueError("Gemini returned empty response across all models.")

    async def _fallback_groq_translate(
        self,
        text: str,
        source_display: str,
        target_name: str,
        target_language: str,
    ) -> TranslationEngineOutput:
        """Fallback to Groq AI when Gemini quota is exhausted."""
        from app.services.groq_service import groq_service
        groq_client = groq_service._get_client()

        sys_prompt = f"""You are a professional travel translator for tourists in Pakistan.
Translate the text from {source_display} to {target_name}.
Output MUST be a valid JSON object matching this schema:
{{
  "detected_source_language": "Detected language name (e.g. English, Urdu, etc)",
  "source_romanized_pronunciation": "Phonetic romanized pronunciation of original input text (e.g. 'Aap kaise hain?' if input is in Urdu or non-Latin script, or clean original text if Latin)",
  "translated_text": "Authentic Urdu script if target is Urdu, or clean English if target is English",
  "romanized_pronunciation": "Phonetic Roman Urdu or English pronunciation guide for translated text"
}}
Return ONLY valid JSON, no markdown blocks."""

        for groq_model in ["openai/gpt-oss-120b", "llama-3.1-8b-instant", "qwen/qwen3.6-27b"]:
            try:
                response = await groq_client.chat.completions.create(
                    model=groq_model,
                    messages=[
                        {"role": "system", "content": sys_prompt},
                        {"role": "user", "content": text},
                    ],
                    temperature=0.1,
                )
                content = response.choices[0].message.content or ""
                match = re.search(r"\{[\s\S]*?\}", content)
                if match:
                    json_str = match.group(0)
                    data = json.loads(json_str)
                    return TranslationEngineOutput.model_validate(data)
            except Exception as ge:
                logger.warning(f"Groq fallback model {groq_model} failed: {ge}")

        # Final local fallback
        fallback_lang = "Urdu" if any("\u0600" <= c <= "\u06FF" for c in text) else "English"
        return TranslationEngineOutput(
            detected_source_language=fallback_lang if source_display in ["auto", "auto-detected language"] else source_display,
            source_romanized_pronunciation=text,
            translated_text=text,
            romanized_pronunciation=text,
        )

    async def translate_text(
        self,
        text: str,
        source_language: str = "auto",
        target_language: str = "ur",
    ) -> TranslationEngineOutput:
        """Translates text to target language with travel context and phonetics."""
        target_name = "Urdu" if target_language == "ur" else "English"
        source_display = (
            settings.LANGUAGE_NAMES.get(source_language, source_language)
            if source_language != "auto"
            else "auto-detected language"
        )

        prompt = f"""
Translate the input text precisely from {source_display} to {target_name}.
Input Text:
"{text}"

Strict Instructions:
1. Translate the input text precisely from {source_display} to {target_name}.
2. Do NOT return the source language inside the translation field.
3. If target_language is 'ur' or 'Urdu', the 'translated_text' MUST be written in authentic Urdu script (اردو). Never return English or Roman Urdu in the 'translated_text' field.
4. If target_language is 'en' or 'English', the 'translated_text' MUST be written in natural, clear English.
5. In 'romanized_pronunciation', provide clear pronunciation guide for translated text:
   - For Urdu target, provide Roman Urdu (e.g. 'Aap kaise hain?', 'Yeh kitnay ka hai?').
   - For English target, provide plain phonetic/Roman text.
6. In 'source_romanized_pronunciation', provide phonetic romanized pronunciation of the input text:
   - If input is in Urdu or Arabic or other non-Latin script, provide Roman transliteration (e.g. 'Aap kaise hain?').
   - If input is already in Latin script (e.g. English, French), provide the original text or clear phonetic text.
7. Auto-detect the exact name of the source language (e.g., 'English', 'German', 'French', 'Arabic', 'Urdu') and put it in 'detected_source_language'.
8. Do NOT hallucinate pre-written phrases. Accurately translate the actual user input.
9. Strictly return only the requested JSON schema.
"""

        try:
            result = await asyncio.to_thread(self._generate_sync, prompt)
            return result
        except Exception as e:
            logger.warning(f"Gemini translation hit error/quota ({e}), falling back to Groq AI...")
            return await self._fallback_groq_translate(
                text=text,
                source_display=source_display,
                target_name=target_name,
                target_language=target_language,
            )


gemini_service = GeminiService()

