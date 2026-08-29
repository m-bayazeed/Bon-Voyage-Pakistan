import asyncio
import base64
import os
import sys
from pathlib import Path
from starlette.testclient import TestClient

# Ensure UTF-8 output on Windows consoles
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

# Add backend directory to sys.path
sys.path.insert(0, str(Path(__file__).resolve().parent))

from app.main import app
from app.core.config import settings

client = TestClient(app)

def run_tests():
    print("=" * 70)
    print("       BON VOYAGE PAKISTAN - TRANSLATOR VERIFICATION SUITE             ")
    print("=" * 70)
    
    passed = 0
    failed = 0

    # ──────────────────────────────────────────────
    # 1. Health Check Test
    # ──────────────────────────────────────────────
    print("\n[TEST 1] Testing GET /health...")
    resp = client.get("/health")
    if resp.status_code == 200 and resp.json() == {"status": "ok", "service": "bon-voyage-translator"}:
        print("[PASS] /health returned status 200 and correct JSON.")
        passed += 1
    else:
        print(f"[FAIL] /health failed with {resp.status_code}: {resp.text}")
        failed += 1

    # ──────────────────────────────────────────────
    # 2. TTS Synthesis Test (Urdu & English)
    # ──────────────────────────────────────────────
    print("\n[TEST 2] Testing POST /api/v1/translate/synthesize (Urdu)...")
    resp_tts_ur = client.post(
        "/api/v1/translate/synthesize",
        json={"text": "صبح بخیر", "language": "ur"},
    )
    if resp_tts_ur.status_code == 200 and resp_tts_ur.json().get("success"):
        b64 = resp_tts_ur.json().get("audio_base64")
        decoded = base64.b64decode(b64)
        # Check MP3 magic bytes / size
        if len(decoded) > 500:
            print(f"[PASS] Synthesized Urdu TTS successfully ({len(decoded)} bytes MP3).")
            passed += 1
        else:
            print("[FAIL] Urdu TTS audio bytes too short.")
            failed += 1
    else:
        print(f"[FAIL] Synthesize Urdu failed: {resp_tts_ur.status_code} {resp_tts_ur.text}")
        failed += 1

    print("\n[TEST 3] Testing POST /api/v1/translate/synthesize (English)...")
    resp_tts_en = client.post(
        "/api/v1/translate/synthesize",
        json={"text": "Good morning, welcome to Pakistan!", "language": "en"},
    )
    if resp_tts_en.status_code == 200 and resp_tts_en.json().get("success"):
        b64 = resp_tts_en.json().get("audio_base64")
        decoded = base64.b64decode(b64)
        if len(decoded) > 500:
            print(f"[PASS] Synthesized English TTS successfully ({len(decoded)} bytes MP3).")
            passed += 1
        else:
            print("[FAIL] English TTS audio bytes too short.")
            failed += 1
    else:
        print(f"[FAIL] Synthesize English failed: {resp_tts_en.status_code} {resp_tts_en.text}")
        failed += 1

    # ──────────────────────────────────────────────
    # 3. Real Text Translation: "How much does this cost?" -> Urdu
    # ──────────────────────────────────────────────
    print("\n[TEST 4] Testing POST /api/v1/translate/text ('How much does this cost?' -> Urdu)...")
    try:
        resp_cost = client.post(
            "/api/v1/translate/text",
            json={
                "text": "How much does this cost?",
                "source_language": "auto",
                "target_language": "ur",
            },
        )
        if resp_cost.status_code == 200:
            data = resp_cost.json()
            assert data["success"] is True
            assert "ai_alternatives" not in data, "ai_alternatives should be completely removed!"
            assert "translated_text" in data
            urdu_text = data["translated_text"]
            # Ensure it contains authentic Urdu characters and not English words
            assert any(ord(c) >= 0x0600 and ord(c) <= 0x06FF for c in urdu_text), "Urdu text must contain Arabic/Urdu unicode script!"
            assert "cost" not in urdu_text.lower(), "Urdu field must not return untranslated English words!"
            
            # Verify Base64 MP3
            audio_bytes = base64.b64decode(data["audio_base64"])
            assert len(audio_bytes) > 500, "Base64 audio is missing or invalid."

            print(f"[PASS] Real English -> Urdu Translation:")
            print(f"   Original:       {data['original_text']}")
            print(f"   Detected Lang:  {data['detected_source_language']}")
            print(f"   Translated:     {data['translated_text']}")
            print(f"   Phonetics:      {data['romanized_pronunciation']}")
            print(f"   Audio size:     {len(audio_bytes)} bytes MP3")
            print(f"   ai_alternatives removed: True")
            passed += 1
        else:
            print(f"[FAIL] Translation failed: {resp_cost.status_code} {resp_cost.text}")
            failed += 1
    except Exception as e:
        print(f"[FAIL] Exception in test 4: {e}")
        failed += 1

    # ──────────────────────────────────────────────
    # 4. Real Text Translation: "Where is the nearest hospital?" -> Urdu
    # ──────────────────────────────────────────────
    print("\n[TEST 5] Testing POST /api/v1/translate/text ('Where is the nearest hospital?' -> Urdu)...")
    try:
        resp_hosp = client.post(
            "/api/v1/translate/text",
            json={
                "text": "Where is the nearest hospital?",
                "source_language": "auto",
                "target_language": "ur",
            },
        )
        if resp_hosp.status_code == 200:
            data = resp_hosp.json()
            assert data["success"] is True
            assert "ai_alternatives" not in data
            assert any(ord(c) >= 0x0600 and ord(c) <= 0x06FF for c in data["translated_text"])
            print(f"[PASS] Hospital Query Translation:")
            print(f"   Original:       {data['original_text']}")
            print(f"   Translated:     {data['translated_text']}")
            print(f"   Phonetics:      {data['romanized_pronunciation']}")
            passed += 1
        else:
            print(f"[FAIL] Translation failed: {resp_hosp.status_code} {resp_hosp.text}")
            failed += 1
    except Exception as e:
        print(f"[FAIL] Exception in test 5: {e}")
        failed += 1

    # ──────────────────────────────────────────────
    # 5. Real Voice Translation Pipeline (Groq Whisper -> Gemini -> Edge TTS)
    # ──────────────────────────────────────────────
    audio_test_file = Path(__file__).resolve().parent.parent / "testingFiles" / "classroom-german.mp3"
    if not audio_test_file.exists():
        audio_test_file = Path(__file__).resolve().parent.parent / "testingFiles" / "clinstructions.mp3"

    if audio_test_file.exists():
        print(f"\n[TEST 6] Testing POST /api/v1/translate/voice with real audio '{audio_test_file.name}'...")
        try:
            with open(audio_test_file, "rb") as f:
                resp_voice = client.post(
                    "/api/v1/translate/voice",
                    files={"audio_file": (audio_test_file.name, f, "audio/mpeg")},
                    data={"source_language": "auto", "target_language": "ur"},
                )
            if resp_voice.status_code == 200:
                data = resp_voice.json()
                assert data["success"] is True
                assert "ai_alternatives" not in data
                assert "transcript" in data and len(data["transcript"].strip()) > 0
                assert "translated_text" in data and len(data["translated_text"].strip()) > 0
                assert any(ord(c) >= 0x0600 and ord(c) <= 0x06FF for c in data["translated_text"])
                audio_bytes = base64.b64decode(data["audio_base64"])
                assert len(audio_bytes) > 500

                print(f"[PASS] Voice Translation Complete Pipeline:")
                print(f"   Spoken Audio Transcript: {data['transcript']}")
                print(f"   Detected Lang:           {data['detected_source_language']}")
                print(f"   Translated Urdu Script:  {data['translated_text']}")
                print(f"   Phonetics (Roman Urdu):  {data['romanized_pronunciation']}")
                print(f"   Decoded MP3 size:        {len(audio_bytes)} bytes")
                passed += 1
            else:
                print(f"[FAIL] Voice translation returned {resp_voice.status_code}: {resp_voice.text}")
                failed += 1
        except Exception as e:
            print(f"[FAIL] Voice translation error: {e}")
            failed += 1
    else:
        print("\n[TEST 6] SKIPPED: No audio test file found.")

    # ──────────────────────────────────────────────
    # 6. Validation: Empty Speech, Bad Extension, Empty File
    # ──────────────────────────────────────────────
    print("\n[TEST 7] Testing Validation: Unsupported extension (.txt)...")
    resp_bad_ext = client.post(
        "/api/v1/translate/voice",
        files={"audio_file": ("sample.txt", b"random non-audio text", "text/plain")},
        data={"source_language": "auto", "target_language": "ur"},
    )
    if resp_bad_ext.status_code in (400, 422) and resp_bad_ext.json().get("success") is False:
        print(f"[PASS] Unsupported file extension properly rejected ({resp_bad_ext.status_code}).")
        passed += 1
    else:
        print(f"[FAIL] Unsupported extension not rejected: {resp_bad_ext.status_code}")
        failed += 1

    print("\n[TEST 8] Testing Validation: Empty audio file (0 bytes)...")
    resp_empty_audio = client.post(
        "/api/v1/translate/voice",
        files={"audio_file": ("empty.wav", b"", "audio/wav")},
        data={"source_language": "auto", "target_language": "ur"},
    )
    if resp_empty_audio.status_code in (400, 422) and resp_empty_audio.json().get("success") is False:
        print(f"[PASS] Empty audio file properly rejected ({resp_empty_audio.status_code}).")
        passed += 1
    else:
        print(f"[FAIL] Empty audio file not rejected: {resp_empty_audio.status_code}")
        failed += 1

    print("\n[TEST 9] Testing Validation: Empty text input...")
    resp_empty_text = client.post(
        "/api/v1/translate/text",
        json={"text": "   ", "source_language": "auto", "target_language": "ur"},
    )
    if resp_empty_text.status_code in (400, 422) and resp_empty_text.json().get("success") is False:
        print(f"[PASS] Empty text properly rejected ({resp_empty_text.status_code}).")
        passed += 1
    else:
        print(f"[FAIL] Empty text not rejected: {resp_empty_text.status_code}")
        failed += 1

    print("\n" + "=" * 70)
    print(f"VERIFICATION COMPLETED: {passed} PASSED, {failed} FAILED")
    print("=" * 70)
    return failed == 0


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
