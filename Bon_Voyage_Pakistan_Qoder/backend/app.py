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
# Health Check
# ──────────────────────────────────────────────

@app.route("/", methods=["GET"])
def health():
    """Health check endpoint."""
    return jsonify({"status": "ok", "app": "Bon Voyage Pakistan API"}), 200



# ──────────────────────────────────────────────
# Entry Point
# ──────────────────────────────────────────────

if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000, debug=True)
