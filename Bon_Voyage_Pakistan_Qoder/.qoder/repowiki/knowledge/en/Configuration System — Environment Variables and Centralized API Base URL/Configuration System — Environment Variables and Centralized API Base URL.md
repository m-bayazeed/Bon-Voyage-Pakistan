---
kind: configuration_system
name: Configuration System — Environment Variables and Centralized API Base URL
category: configuration_system
scope:
    - '**'
source_files:
    - backend/.env
    - backend/app.py
    - backend/database.py
    - lib/config/api_config.dart
    - pubspec.yaml
---

## Overview

The Bon Voyage Pakistan repository uses a minimal, two-part configuration system split between the Flutter client and the Flask backend. There is no centralized configuration framework; instead, each side loads its own runtime settings from environment variables or hard-coded constants.

## Backend (Flask) Configuration

- **Environment file**: `backend/.env` holds secrets and runtime toggles:
  - `SECRET_KEY` — JWT signing key (with a comment instructing to change it for production).
  - `JWT_EXPIRATION_HOURS` — token lifetime in hours.
- **Loading mechanism**: `backend/app.py` calls `dotenv.load_dotenv()` at module import time (line 19), then reads values via `os.getenv(...)` with defaults into `app.config` (lines 25–26). This means missing env vars fall back to safe defaults (`"fallback-dev-key-change-in-production"` and `24`).
- **Database path** is resolved relative to the module location in `backend/database.py` (`bon_voyage.db` next to the code); it is not configurable via env vars.
- **Server binding** is hardcoded in `app.py` under `__main__`: `host="0.0.0.0", port=5000, debug=True`.

## Frontend (Flutter) Configuration

- **Central API config**: `lib/config/api_config.dart` defines a singleton-like class `ApiConfig` with a private constructor (`ApiConfig._()`) and `static const` members:
  - `baseUrl = 'http://192.168.100.12:5000'` — the only mutable piece of configuration.
  - Derived endpoint constants: `signup`, `login`, `me`, `logout` built by string interpolation against `baseUrl`.
- The file's docstring documents the intended usage pattern: change `baseUrl` per deployment (Android Emulator → `10.0.2.2`, physical device → LAN IP, production → HTTPS domain).
- No `.env` or `flutter_native_settings`/`flutter_config` package is used on the client; there is no runtime loading of environment variables. All URLs are compile-time constants.
- Dependencies relevant to configuration: `http` for network calls, `flutter_secure_storage` for storing the JWT token returned by the backend, and `shared_preferences` for local app state.

## Platform Build Configs

- iOS/macOS use Xcode `xcconfig` files under `ios/Runner/Configs/` and `macos/Runner/Configs/` (`AppInfo.xcconfig`, `Debug.xcconfig`, `Release.xcconfig`, `Warnings.xcconfig`) for build-time settings.
- Android uses standard Gradle properties in `android/gradle.properties` and `local.properties`.
- These are platform-level build configurations, not application runtime configuration.

## Conventions Observed

1. **Secrets live only in the backend `.env`**; the Flutter client contains no secrets — only the base URL.
2. **Backend env vars have documented defaults**: every `os.getenv` call supplies a fallback so the app starts without a `.env` present.
3. **Frontend endpoints are derived, not duplicated**: changing `baseUrl` automatically updates all four endpoint strings.
4. **No feature flags or per-environment config files** exist in this repo; environment switching is done by editing `ApiConfig.baseUrl` and/or the backend `.env`.
5. **Database location is fixed** relative to the Python source directory — there is no database URI env var.