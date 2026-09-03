import asyncio
import io
import os
import sys
from PIL import Image, ImageDraw
import httpx
from fastapi.testclient import TestClient

# Add backend directory to sys.path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.main import app
from app.services.landmark_service import landmark_service


def create_dummy_image(color="green", text="Test") -> bytes:
    """Creates a small valid JPEG image in-memory."""
    img = Image.new("RGB", (300, 300), color=color)
    draw = ImageDraw.Draw(img)
    draw.text((30, 140), text, fill="white")
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


def test_health_check():
    print("\n--- TEST 0: Health Check & Gemini Configuration ---")
    client = TestClient(app)
    res = client.get("/health")
    assert res.status_code == 200
    data = res.json()
    print(f"Health check response: {data}")
    assert data["status"] == "ok"
    assert data["fastapi_running"] == "YES"
    assert data["gemini_api_key_configured"] == "YES"
    print("[OK] Health check passed: FastAPI running: YES, Gemini API key configured: YES")


def test_image_validation():
    print("\n--- TEST 1: Image Validation with Pillow ---")
    valid_bytes = create_dummy_image("blue", "Lahore Fort Simulation")
    processed_bytes, mime = landmark_service.validate_and_process_image(valid_bytes, "test.jpg")
    assert mime == "image/jpeg"
    assert len(processed_bytes) > 0
    print("[OK] Valid JPEG successfully verified and processed.")

    # Corrupted image test
    corrupted_bytes = b"not_an_image_file_at_all"
    try:
        landmark_service.validate_and_process_image(corrupted_bytes, "corrupt.jpg")
        print("[FAILED] Corrupted image should have been rejected.")
        assert False
    except ValueError as e:
        print(f"[OK] Corrupted image rejected as expected: {e}")

    # Empty bytes test
    try:
        landmark_service.validate_and_process_image(b"", "empty.jpg")
        print("[FAILED] Empty image should have been rejected.")
        assert False
    except ValueError as e:
        print(f"[OK] Empty image rejected as expected: {e}")


def test_fastapi_endpoint_validation():
    print("\n--- TEST 2: FastAPI Endpoint Image Validation ---")
    client = TestClient(app)

    # Missing file
    res = client.post("/api/v1/landmarks/scan")
    assert res.status_code == 422 or res.status_code == 400
    print("[OK] Missing image upload correctly returned 422/400.")

    # Corrupted file upload returns clean user-friendly response with success=False
    res = client.post(
        "/api/v1/landmarks/scan",
        files={"image": ("corrupted.jpg", b"garbage data", "image/jpeg")},
    )
    assert res.status_code == 200
    data = res.json()
    assert data["success"] is False
    assert data["identified"] is False
    assert "not a valid image" in data["message"].lower() or "corrupted" in data["message"].lower()
    print(f"[OK] Corrupted file upload gracefully handled: success=False, message='{data['message']}'")


async def test_gemini_vision_and_non_landmark():
    print("\n--- TEST 3: Gemini Vision Non-Landmark Anti-Hallucination ---")
    # A plain red image with text 'Random Coffee Cup' should NOT be identified as a Pakistani landmark
    non_landmark_img = create_dummy_image("red", "Random Coffee Cup")
    
    result = await landmark_service.identify_landmark(
        image_bytes=non_landmark_img,
        filename="coffee_cup.jpg",
        content_type="image/jpeg",
    )
    print(f"Non-landmark scan result: identified={result.identified}, confidence={result.confidence}, message='{result.message}'")
    assert result.success is True
    # System must NOT hallucinate a landmark from a plain red canvas
    assert result.identified is False
    assert result.confidence == 0.0 or result.confidence is None or result.confidence < 0.6
    print("[OK] Anti-hallucination verified: Non-landmark correctly not identified.")


async def test_fastapi_full_flow():
    print("\n--- TEST 4: FastAPI Full Flow with Real Image ---")
    client = TestClient(app)
    img_bytes = create_dummy_image("darkblue", "Test Scan")
    
    response = client.post(
        "/api/v1/landmarks/scan",
        files={"image": ("test_scan.jpg", img_bytes, "image/jpeg")},
    )
    assert response.status_code == 200
    data = response.json()
    print(f"API Full Flow response: {data}")
    assert "success" in data
    assert "identified" in data
    print("[OK] FastAPI landmark scan endpoint responded with valid structured JSON schema.")


async def test_real_pakistani_landmark_scan():
    print("\n--- TEST 5: Real Pakistani Landmark Image Recognition ---")
    landmark_file = os.path.join(os.path.dirname(__file__), "..", "testingFiles", "test_image_1.jfif")
    if os.path.exists(landmark_file):
        with open(landmark_file, "rb") as f:
            img_bytes = f.read()
        result = await landmark_service.identify_landmark(
            image_bytes=img_bytes,
            filename="test_image_1.jfif",
            content_type="image/jpeg",
        )
        print(f"Real landmark result: success={result.success}, identified={result.identified}, landmark='{result.landmark_name}', city='{result.city_or_region}', confidence={result.confidence}")
        assert result.success is True
        assert result.identified is True
        assert result.landmark_name is not None
        assert len(result.landmark_name) > 0
        assert result.confidence >= 0.70
        print(f"[OK] Real landmark recognition verified: Identified '{result.landmark_name}' ({result.city_or_region}) with confidence {result.confidence}")
    else:
        print("[INFO] Landmark test image not found, skipping real photo assertion.")


async def test_story_audio_synthesis():
    print("\n--- TEST 6: Landmark Story Audio Synthesis (TTS / Groq / Neural) ---")
    client = TestClient(app)
    story_payload = {
        "text": "The Badshahi Mosque in Lahore was built by Mughal Emperor Aurangzeb in 1673. It is renowned for its grand red sandstone facade and three majestic white marble domes.",
        "language": "en",
    }
    response = client.post("/api/v1/tts/story", json=story_payload)
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert "audio_base64" in data
    assert len(data["audio_base64"]) > 100
    print(f"[OK] Story audio successfully synthesized: format={data['format']}, base64_length={len(data['audio_base64'])}")

    # Also test /api/v1/landmarks/story-audio
    res2 = client.post("/api/v1/landmarks/story-audio", json=story_payload)
    assert res2.status_code == 200
    assert res2.json()["success"] is True
    print("[OK] Landmark story-audio endpoint alias verified successfully.")


if __name__ == "__main__":
    test_health_check()
    test_image_validation()
    test_fastapi_endpoint_validation()
    asyncio.run(test_gemini_vision_and_non_landmark())
    asyncio.run(test_fastapi_full_flow())
    asyncio.run(test_real_pakistani_landmark_scan())
    asyncio.run(test_story_audio_synthesis())
    print("\n==========================================")
    print("ALL LANDMARK SCAN & AUDIO TESTS PASSED SUCCESSFULLY!")
    print("==========================================\n")

