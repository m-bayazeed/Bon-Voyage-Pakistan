---
kind: build_system
name: Flutter Multi-Platform + Flask Backend Build System
category: build_system
scope:
    - '**'
source_files:
    - pubspec.yaml
    - pubspec.lock
    - analysis_options.yaml
    - android/build.gradle.kts
    - android/app/build.gradle.kts
    - android/gradle.properties
    - ios/Flutter/Release.xcconfig
    - linux/CMakeLists.txt
    - windows/flutter/CMakeLists.txt
    - backend/requirements.txt
    - backend/.env
---

## Overview

This repository is a **Flutter multi-platform application** (Android, iOS, Linux, macOS, Windows, Web) paired with a standalone **Flask Python backend**. There are no custom Makefiles, Dockerfiles, or CI pipelines; the build system relies entirely on the standard toolchains of each platform plus the Flutter toolchain.

## Frontend (Flutter) Build

- **Dependency & version management**: `pubspec.yaml` declares SDK constraint (`^3.13.0`), app version (`1.0.0+1`), and all Dart dependencies (`http`, `flutter_secure_storage`, `shared_preferences`, `cupertino_icons`). Lockfile `pubspec.lock` pins exact versions. Dev-only dependency `flutter_lints` is used for static analysis via `analysis_options.yaml`.
- **Assets**: Static images under `assets/images/` are declared in `pubspec.yaml` under `flutter.assets` so they are bundled at build time.
- **Android**: Uses Gradle Kotlin DSL (`android/build.gradle.kts`, `android/app/build.gradle.kts`). The app module applies `com.android.application` and `dev.flutter.flutter-gradle-plugin`. Version code/name are sourced from `pubspec.yaml` (`flutter.versionCode`, `flutter.versionName`). Java/Kotlin target is set to JVM 17. Release signing currently falls back to debug keys (`signingConfigs.getByName("debug")`). Gradle JVM args in `android/gradle.properties` allocate up to 8 GB heap. Build output is redirected to the repo root `build/` directory via `rootProject.layout.buildDirectory`.
- **iOS**: Standard Xcode project under `ios/Runner.xcodeproj`. Build configs live in `ios/Flutter/*.xcconfig` (`Debug.xcconfig`, `Release.xcconfig`, `Generated.xcconfig`). No custom build scripts — builds are driven by `flutter build ios` / Xcode.
- **Linux & Windows**: CMake-based native runners (`linux/CMakeLists.txt`, `windows/flutter/CMakeLists.txt`) invoke the Flutter tool backend (`tool_backend.bat` / `tool_backend.sh`) to generate platform-specific artifacts. Linux sets `APPLICATION_ID com.example.bon_voyage_pakistan` and bundles GTK 3. Windows targets `windows-x64` by default and produces an AOT `.so` in `build/windows/app.so` for non-Debug builds.
- **Web**: Plain HTML/JS entry under `web/index.html` with icons in `web/icons/`; built via `flutter build web`.

## Backend (Flask) Build

- **Python environment**: Dependencies are pinned in `backend/requirements.txt` (`Flask==3.1.1`, `Flask-Cors==6.0.1`, `PyJWT==2.10.1`, `python-dotenv==1.1.1`, `Werkzeug==3.1.3`). A local virtual environment exists under `backend/venv/`.
- **Runtime config**: `backend/.env` holds runtime secrets consumed via `python-dotenv`.
- **Database**: SQLite file `backend/bon_voyage.db` is created at runtime by the app; it is committed to the repo (not ideal for production).
- **Testing**: A simple API test script exists at `backend/test_api.py`.

## Cross-Platform Conventions

- Single source of truth for app identity: `pubspec.yaml` name/version propagate to Android (`applicationId`, `versionCode`, `versionName`) and Linux (`APPLICATION_ID`, `BINARY_NAME`).
- All native build outputs are consolidated under the repo-root `build/` directory (Android explicitly redirects its Gradle output there).
- Debug vs Release profiles exist per platform (Android `buildTypes.release`, iOS `Release.xcconfig`, Linux/Windows CMake `Debug`/`Profile`/`Release` build types).

## What Is Missing

- No `Makefile`, shell build scripts, or wrapper scripts to orchestrate frontend + backend builds together.
- No `Dockerfile` or `docker-compose.yml` for containerized deployment.
- No CI/CD configuration (no `.github/workflows`, no Azure Pipelines, Jenkinsfile, etc.).
- No release packaging beyond `flutter build apk|aab|ios|web|linux|windows`.
- Android release signing is not configured (still uses debug keystore).

In short, this project uses the **default Flutter toolchain** for building every supported platform and the **standard Python/pip workflow** for the Flask backend, with no higher-level build orchestration.