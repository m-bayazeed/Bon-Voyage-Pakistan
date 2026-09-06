"""
Bon Voyage Pakistan - Flask Backend
Main application entry point with authentication routes.
"""

import os
import datetime
from functools import wraps

from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
from werkzeug.security import generate_password_hash, check_password_hash
import jwt

from database import init_db, create_user, find_user_by_email, find_user_by_id, update_user_name, update_user_password

# Load environment variables from .env file
load_dotenv()

app = Flask(__name__)
CORS(app)

# Configuration from environment variables
app.config["SECRET_KEY"] = os.getenv("SECRET_KEY", "fallback-dev-key-change-in-production")
app.config["JWT_EXPIRATION_HOURS"] = int(os.getenv("JWT_EXPIRATION_HOURS", "24"))


# ──────────────────────────────────────────────
# JWT Authentication Decorator
# ──────────────────────────────────────────────

def token_required(f):
    """Decorator that protects routes requiring a valid JWT.

    Extracts the Bearer token from the Authorization header, decodes it,
    looks up the user in the database, and injects `current_user` as the
    first positional argument into the wrapped route handler.
    """
    @wraps(f)
    def wrapper(*args, **kwargs):
        token = None

        # Extract token from "Authorization: Bearer <token>" header
        auth_header = request.headers.get("Authorization", "")
        if auth_header.startswith("Bearer "):
            token = auth_header.split(" ", 1)[1]

        if not token:
            return jsonify({"success": False, "message": "Token is missing"}), 401

        try:
            payload = jwt.decode(token, app.config["SECRET_KEY"], algorithms=["HS256"])
            current_user = find_user_by_id(payload["user_id"])
            if not current_user:
                return jsonify({"success": False, "message": "User not found"}), 401
        except jwt.ExpiredSignatureError:
            return jsonify({"success": False, "message": "Token has expired"}), 401
        except jwt.InvalidTokenError:
            return jsonify({"success": False, "message": "Invalid token"}), 401

        # Pass the resolved user as the first argument to the route handler
        return f(current_user, *args, **kwargs)

    return wrapper


# ──────────────────────────────────────────────
# Helper: Generate JWT Token
# ──────────────────────────────────────────────

def generate_token(user_id):
    """Generate a JWT token for the given user id."""
    expiration = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(
        hours=app.config["JWT_EXPIRATION_HOURS"]
    )
    payload = {
        "user_id": user_id,
        "exp": expiration,
        "iat": datetime.datetime.now(datetime.timezone.utc),
    }
    return jwt.encode(payload, app.config["SECRET_KEY"], algorithm="HS256")


def user_to_dict(user_row):
    """Convert a user database row to a safe dictionary (no password hash)."""
    return {
        "id": user_row["id"],
        "name": user_row["name"],
        "email": user_row["email"],
    }


# ──────────────────────────────────────────────
# Validation Helpers
# ──────────────────────────────────────────────

def is_valid_email(email):
    """Basic email format validation."""
    import re
    pattern = r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$"
    return re.match(pattern, email) is not None


# ──────────────────────────────────────────────
# AUTH ROUTES
# ──────────────────────────────────────────────

@app.route("/auth/signup", methods=["POST"])
def signup():
    """Register a new user account."""
    data = request.get_json()
    if not data:
        return jsonify({"success": False, "message": "Request body is required"}), 400

    name = (data.get("name") or "").strip()
    email = (data.get("email") or "").strip().lower()
    password = data.get("password") or ""

    # ── Validation ──
    errors = []
    if not name:
        errors.append("Full name is required")
    if not email:
        errors.append("Email is required")
    elif not is_valid_email(email):
        errors.append("Invalid email format")
    if not password:
        errors.append("Password is required")
    elif len(password) < 8:
        errors.append("Password must be at least 8 characters")

    if errors:
        return jsonify({"success": False, "message": errors[0], "errors": errors}), 400

    # ── Hash the password ──
    password_hash = generate_password_hash(password)

    # ── Insert user into database ──
    user_id = create_user(name, email, password_hash)
    if user_id is None:
        return jsonify({"success": False, "message": "An account with this email already exists"}), 409

    # ── Generate JWT ──
    token = generate_token(user_id)

    user = find_user_by_id(user_id)
    return jsonify({
        "success": True,
        "message": "Account created successfully",
        "user": user_to_dict(user),
        "token": token,
    }), 201


@app.route("/auth/login", methods=["POST"])
def login():
    """Authenticate an existing user."""
    data = request.get_json()
    if not data:
        return jsonify({"success": False, "message": "Request body is required"}), 400

    email = (data.get("email") or "").strip().lower()
    password = data.get("password") or ""

    # ── Validation ──
    if not email or not password:
        return jsonify({"success": False, "message": "Email and password are required"}), 400

    # ── Look up user (generic error to prevent enumeration) ──
    user = find_user_by_email(email)
    if not user or not check_password_hash(user["password_hash"], password):
        return jsonify({"success": False, "message": "Invalid email or password"}), 401

    # ── Generate JWT ──
    token = generate_token(user["id"])

    return jsonify({
        "success": True,
        "message": "Login successful",
        "user": user_to_dict(user),
        "token": token,
    }), 200


@app.route("/auth/me", methods=["GET"])
@token_required
def me(current_user):
    """Return the currently authenticated user's information."""
    return jsonify({
        "success": True,
        "user": user_to_dict(current_user),
    }), 200


@app.route("/auth/change-username", methods=["POST", "PUT"])
@token_required
def change_username(current_user):
    """Change the authenticated user's name."""
    data = request.get_json()
    if not data:
        return jsonify({"success": False, "message": "Request body is required"}), 400

    new_name = (data.get("name") or data.get("username") or "").strip()
    if not new_name:
        return jsonify({"success": False, "message": "Username cannot be empty"}), 400

    update_user_name(current_user["id"], new_name)
    updated_user = find_user_by_id(current_user["id"])

    return jsonify({
        "success": True,
        "message": "Username updated successfully",
        "user": user_to_dict(updated_user),
    }), 200


@app.route("/auth/change-password", methods=["POST"])
@token_required
def change_password(current_user):
    """Change the authenticated user's password after verifying current password."""
    data = request.get_json()
    if not data:
        return jsonify({"success": False, "message": "Request body is required"}), 400

    current_password = data.get("current_password") or ""
    new_password = data.get("new_password") or ""

    if not current_password:
        return jsonify({"success": False, "message": "Current password is required"}), 400
    if not new_password:
        return jsonify({"success": False, "message": "New password is required"}), 400
    if len(new_password) < 8:
        return jsonify({"success": False, "message": "New password must be at least 8 characters"}), 400

    # Verify current password
    if not check_password_hash(current_user["password_hash"], current_password):
        return jsonify({"success": False, "message": "Incorrect current password"}), 401

    # Hash new password and update
    new_password_hash = generate_password_hash(new_password)
    update_user_password(current_user["id"], new_password_hash)

    return jsonify({
        "success": True,
        "message": "Password changed successfully",
    }), 200


@app.route("/auth/logout", methods=["POST"])
def logout():
    """
    Logout endpoint.
    Since JWT is stateless, the actual token removal happens on the client.
    This endpoint exists for API completeness.
    """
    return jsonify({
        "success": True,
        "message": "Logged out successfully",
    }), 200


from trip_planner import generate_plan, chat_refinement


# ──────────────────────────────────────────────
# TRIP PLANNING ROUTES (GROQ AI)
# ──────────────────────────────────────────────

@app.route("/trip/generate-plan", methods=["POST"])
def api_generate_trip_plan():
    """
    Generate a full structured Pakistan tour plan using Groq AI.
    Accepts: departing, destination, days, interests, special_requirements
    """
    data = request.get_json() or {}

    departing = (data.get("departing") or data.get("departingCity") or "Islamabad").strip()
    destination = (data.get("destination") or data.get("destinationCity") or "Hunza Valley").strip()
    
    try:
        days = int(data.get("days", 5))
    except (ValueError, TypeError):
        days = 5

    interests = data.get("interests", [])
    if isinstance(interests, str):
        interests = [i.strip() for i in interests.split(",") if i.strip()]

    special_requirements = (data.get("special_requirements") or data.get("specialRequirements") or "").strip()

    try:
        result = generate_plan(
            departing=departing,
            destination=destination,
            days=days,
            interests=interests,
            special_requirements=special_requirements
        )

        if result.get("incompatible"):
            return jsonify({
                "success": False,
                "incompatible": True,
                "message": result["message"],
                "suggestedInterests": result.get("suggestedInterests", []),
                "suggestedDestinations": result.get("suggestedDestinations", [])
            }), 200

        return jsonify({
            "success": True,
            "message": "Tour plan generated successfully",
            "plan": result["plan"],
            "introMessage": result["introMessage"],
            "quickSuggestions": result["quickSuggestions"]
        }), 200
    except Exception as e:
        app.logger.error(f"Error generating trip plan: {e}")
        return jsonify({
            "success": False,
            "message": f"Failed to generate tour plan: {str(e)}"
        }), 500


@app.route("/trip/chat", methods=["POST"])
def api_chat_trip_plan():
    """
    Refine and customize the active tour plan via interactive Groq AI chat.
    Accepts: message, current_plan, chat_history
    """
    data = request.get_json() or {}
    message = (data.get("message") or "").strip()

    if not message:
        return jsonify({"success": False, "message": "Message is required"}), 400

    current_plan = data.get("current_plan") or data.get("currentPlan")
    chat_history = data.get("chat_history") or data.get("chatHistory")

    try:
        result = chat_refinement(
            message=message,
            current_plan=current_plan,
            chat_history=chat_history
        )
        return jsonify({
            "success": True,
            "message": result["message"],
            "updatedPlan": result.get("updatedPlan")
        }), 200
    except Exception as e:
        app.logger.error(f"Error refining trip chat: {e}")
        return jsonify({
            "success": False,
            "message": f"Failed to refine tour plan: {str(e)}"
        }), 500


# ──────────────────────────────────────────────
# Health & Translator Endpoints
# ──────────────────────────────────────────────

@app.route("/", methods=["GET"])
@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint."""
    return jsonify({"status": "ok", "service": "bon-voyage-translator", "app": "Bon Voyage Pakistan API"}), 200


@app.route("/api/v1/translate/text", methods=["POST"])
def translate_text_route():
    """Flask endpoint for text translation (compatible with FastAPI pipeline)."""
    import asyncio
    from app.services.translation_service import translation_pipeline

    data = request.get_json() or {}
    text = data.get("text", "")
    source_language = data.get("source_language", "auto")
    target_language = data.get("target_language", "ur")

    try:
        result = asyncio.run(
            translation_pipeline.translate_text(
                text=text,
                source_language=source_language,
                target_language=target_language,
            )
        )
        return jsonify(result.model_dump()), 200
    except Exception as e:
        app.logger.error(f"Translation error: {e}")
        status_code = getattr(e, "status_code", 500)
        detail = getattr(e, "detail", str(e))
        return jsonify({"success": False, "error": detail}), status_code


@app.route("/api/v1/translate/voice", methods=["POST"])
def translate_voice_route():
    """Flask endpoint for voice translation."""
    import asyncio
    from app.services.translation_service import translation_pipeline

    if "audio_file" not in request.files:
        return jsonify({"success": False, "error": "No audio_file provided in multipart request."}), 400

    audio_file = request.files["audio_file"]
    source_language = request.form.get("source_language", "auto")
    target_language = request.form.get("target_language", "ur")

    try:
        result = asyncio.run(
            translation_pipeline.translate_voice(
                audio_file=audio_file,
                source_language=source_language,
                target_language=target_language,
            )
        )
        return jsonify(result.model_dump()), 200
    except Exception as e:
        app.logger.error(f"Voice translation error: {e}")
        status_code = getattr(e, "status_code", 500)
        detail = getattr(e, "detail", str(e))
        return jsonify({"success": False, "error": detail}), status_code


@app.route("/api/v1/translate/synthesize", methods=["POST"])
def synthesize_route():
    """Flask endpoint for TTS synthesis."""
    import asyncio
    from app.services.translation_service import translation_pipeline

    data = request.get_json() or {}
    text = data.get("text", "")
    language = data.get("language", "ur")

    try:
        result = asyncio.run(
            translation_pipeline.synthesize(
                text=text,
                language=language,
            )
        )
        return jsonify(result.model_dump()), 200
    except Exception as e:
        app.logger.error(f"Synthesis error: {e}")
        status_code = getattr(e, "status_code", 500)
        detail = getattr(e, "detail", str(e))
        return jsonify({"success": False, "error": detail}), status_code


@app.route("/api/v1/hotels/cities", methods=["GET"])
def hotels_cities_route():
    """Flask endpoint for listing supported cities."""
    import asyncio
    from app.api.v1.hotels import get_cities

    try:
        result = asyncio.run(get_cities())
        return jsonify(result.model_dump()), 200
    except Exception as e:
        app.logger.error(f"Hotels cities error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/v1/hotels/search", methods=["GET", "POST"])
def hotels_search_route():
    """Flask endpoint for hotel search supporting GET and POST with query params."""
    import asyncio
    from app.models.hotel import HotelSearchRequest
    from app.api.v1.hotels import search_hotels

    if request.method == "GET":
        data = request.args.to_dict()
    else:
        data = request.get_json() or {}
        for k, v in request.args.items():
            if k not in data:
                data[k] = v

    # Parse numeric query params if present
    for num_field in ["latitude", "longitude", "user_latitude", "user_longitude", "radius_km"]:
        if num_field in data and data[num_field] is not None:
            try:
                data[num_field] = float(data[num_field])
            except (ValueError, TypeError):
                data[num_field] = None

    try:
        req = HotelSearchRequest(**data)
        result = asyncio.run(search_hotels(req))
        return jsonify(result.model_dump()), 200
    except Exception as e:
        app.logger.error(f"Hotels search error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/v1/hotels/geocode", methods=["POST"])
def hotels_geocode_route():
    """Flask endpoint for geocoding custom locations."""
    import asyncio
    from app.models.hotel import HotelGeocodeRequest
    from app.api.v1.hotels import geocode_location

    data = request.get_json() or {}
    try:
        req = HotelGeocodeRequest(**data)
        result = asyncio.run(geocode_location(req))
        return jsonify(result.model_dump()), 200
    except Exception as e:
        app.logger.error(f"Hotels geocode error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/v1/hotels/resolve-location", methods=["POST"])
def hotels_resolve_location_route():
    """Flask endpoint for resolving destination coordinates using Gemini."""
    import asyncio
    from app.models.hotel import LocationResolutionRequest
    from app.api.v1.hotels import resolve_location

    data = request.get_json() or {}
    try:
        req = LocationResolutionRequest(**data)
        result = asyncio.run(resolve_location(req))
        return jsonify(result.model_dump()), 200
    except Exception as e:
        app.logger.error(f"Hotels resolve location error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/v1/food/search", methods=["GET", "POST"])
def food_search_route():
    """Flask endpoint for live food & dining search via Google Places (New)."""
    import asyncio
    from app.models.food import FoodSearchRequest
    from app.api.v1.food import search_food

    # Combine query arguments and JSON body
    combined_data = dict(request.args)
    if request.is_json:
        body = request.get_json() or {}
        combined_data.update(body)

    cuisine_param = request.args.get("cuisine") or combined_data.get("cuisine")
    category_param = request.args.get("category") or combined_data.get("category")
    city_param = request.args.get("city") or combined_data.get("city")

    try:
        req = FoodSearchRequest(**combined_data)
        result = asyncio.run(search_food(req=req, cuisine=cuisine_param, category=category_param, city=city_param))
        return jsonify(result.model_dump()), 200
    except Exception as e:
        app.logger.error(f"Food search error: {e}")
        return jsonify({"success": False, "error": str(e), "places": []}), 500


@app.route("/api/v1/weather/current", methods=["GET"])
def weather_current_route():
    """Flask endpoint for live weather & situational road travel conditions via OpenWeatherMap."""
    import asyncio
    from app.services.weather_service import weather_service

    city = request.args.get("city")
    lat_str = request.args.get("lat") or request.args.get("latitude")
    lon_str = request.args.get("lon") or request.args.get("longitude")

    lat = float(lat_str) if lat_str else None
    lon = float(lon_str) if lon_str else None

    try:
        result = asyncio.run(weather_service.get_current_weather(city=city, lat=lat, lon=lon))
        return jsonify(result.model_dump()), 200
    except Exception as e:
        app.logger.error(f"Weather route error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/v1/help/search", methods=["POST"])
def help_search_route():
    """Flask endpoint for live medical & emergency facility search via Google Places (New)."""
    import asyncio
    from app.models.help import HelpSearchRequest
    from app.api.v1.help import search_help

    data = request.get_json() or {}
    try:
        req = HelpSearchRequest(**data)
        result = asyncio.run(search_help(req))
        return jsonify(result.model_dump()), 200
    except Exception as e:
        app.logger.error(f"Help search error: {e}")
        return jsonify({"success": False, "error": str(e), "facilities": []}), 500


@app.route("/api/v1/routes", methods=["POST"])
def routes_compute_route():
    """Flask endpoint for Google Routes matrix & driving ETA calculation."""
    import asyncio
    from app.api.v1.routes import compute_routes

    data = request.get_json() or {}
    try:
        result = asyncio.run(compute_routes(data))
        return jsonify(result), 200
    except Exception as e:
        app.logger.error(f"Routes error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/v1/landmarks/scan", methods=["POST"])
def landmarks_scan_route():
    """Flask endpoint for Gemini Multimodal Vision landmark identification."""
    import asyncio
    from app.services.landmark_service import landmark_service

    if "image" not in request.files:
        return jsonify({
            "success": False,
            "identified": False,
            "error": "Please select or capture an image first.",
        }), 400

    file = request.files["image"]
    if not file or not file.filename:
        return jsonify({
            "success": False,
            "identified": False,
            "error": "Please select or capture an image first.",
        }), 400

    lat_val = request.form.get("latitude")
    lon_val = request.form.get("longitude")
    latitude = float(lat_val) if lat_val else None
    longitude = float(lon_val) if lon_val else None

    try:
        app.logger.info(f"[SCAN] Source: CAMERA/GALLERY via Flask (port 5000), Filename='{file.filename}'")
        image_bytes = file.read()
        result = asyncio.run(
            landmark_service.identify_landmark(
                image_bytes=image_bytes,
                filename=file.filename,
                content_type=file.content_type,
                latitude=latitude,
                longitude=longitude,
            )
        )
        return jsonify(result.model_dump()), 200
    except ValueError as val_err:
        app.logger.warning(f"[SCAN] Landmark scan validation error: {val_err}")
        return jsonify({
            "success": False,
            "identified": False,
            "error": str(val_err),
        }), 400
    except Exception as e:
        app.logger.error(f"[SCAN] Landmarks scan error: {e}")
        return jsonify({
            "success": False,
            "identified": False,
            "error": f"Landmark identification error: {str(e)}",
        }), 500


@app.route("/api/v1/landmarks/story-audio", methods=["POST"])
@app.route("/api/v1/tts/story", methods=["POST"])
def landmarks_story_audio_route():
    """Flask endpoint for landmark story TTS synthesis."""
    import asyncio
    from app.services.landmark_service import landmark_service

    data = request.get_json() or {}
    text = data.get("text", "")
    language = data.get("language", "en")

    try:
        result = asyncio.run(landmark_service.synthesize_story_audio(text=text, language=language))
        return jsonify(result.model_dump()), 200
    except Exception as e:
        app.logger.error(f"[TTS] Story audio error: {e}")
        return jsonify({
            "success": False,
            "audio_base64": "",
            "error": "TTS_GENERATION_FAILED",
            "message": str(e),
        }), 500


# ──────────────────────────────────────────────
# Entry Point
# ──────────────────────────────────────────────

if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000, debug=True)

