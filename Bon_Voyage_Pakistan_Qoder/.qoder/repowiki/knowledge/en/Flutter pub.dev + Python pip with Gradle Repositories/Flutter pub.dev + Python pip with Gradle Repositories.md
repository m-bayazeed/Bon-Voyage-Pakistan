---
kind: dependency_management
name: Flutter pub.dev + Python pip with Gradle Repositories
category: dependency_management
scope:
    - '**'
source_files:
    - pubspec.yaml
    - pubspec.lock
    - backend/requirements.txt
    - android/build.gradle.kts
    - android/app/build.gradle.kts
---

## Dependency Management in Bon Voyage Pakistan

This repository is a multi-language project combining a Flutter mobile client and a Flask backend. Each language uses its native package manager; there is no unified dependency tool across the two stacks.

### Flutter (pub.dev)
- **Manifest**: `pubspec.yaml` declares direct dependencies under `dependencies:` (`http`, `flutter_secure_storage`, `shared_preferences`, `cupertino_icons`) and dev-only dependencies under `dev_dependencies:` (`flutter_test`, `flutter_lints`). The SDK constraint is pinned to `^3.13.0` via the `environment:` block, ensuring reproducible Dart SDK resolution.
- **Lockfile**: `pubspec.lock` is committed alongside the manifest. It records exact resolved versions and SHA-256 hashes for every transitive dependency fetched from `https://pub.dev` (all entries show `source: hosted` with that URL). This makes builds deterministic across machines.
- **Repository source**: No custom `pubspec.yaml` `dependency_overrides` or global `~/.pub-cache` overrides are present; all packages resolve against the public pub.dev registry. There is no private registry or vendored `packages/` directory — Flutter's standard hosted-source model is used.
- **Platform-specific plugins** (`flutter_secure_storage_linux/macos/web/windows`) are pulled transitively by `flutter_secure_storage`; they appear only as transitive entries in `pubspec.lock`.

### Android (Gradle / Kotlin DSL)
- **Repositories**: `android/build.gradle.kts` configures `google()` and `mavenCentral()` as the only repositories for all subprojects. No private Maven repos or local file-based repos are declared.
- **Plugin management**: Uses the Flutter Gradle plugin (`id("dev.flutter.flutter-gradle-plugin")`) applied after the Android application plugin in `android/app/build.gradle.kts`. Compile/target Java/Kotlin versions are set to 17.
- **No lockfile**: Gradle does not use a checked-in dependency lockfile here; resolutions happen at build time from Google/Maven Central.

### iOS (Xcode / CocoaPods)
- No `Podfile` or `Package.swift` is present in the `ios/` tree. Flutter's iOS target relies on the Flutter SDK's bundled frameworks and generated plugin code under `ios/Flutter/ephemeral/` (e.g., `GeneratedPluginRegistrant.m/h`). Third-party iOS dependencies are therefore managed indirectly through Flutter plugins rather than a separate CocoaPods manifest in this repo.

### Backend (Python / pip)
- **Manifest**: `backend/requirements.txt` pins every dependency to an exact version using `==`: `Flask==3.1.1`, `Flask-Cors==6.0.1`, `PyJWT==2.10.1`, `python-dotenv==1.1.1`, `Werkzeug==3.1.3`. This is a strict pinning strategy intended to guarantee identical installs.
- **Virtual environment**: A `backend/venv/` directory exists, indicating an isolated Python virtual environment is used locally. The venv contents are excluded from version control via `backend/.gitignore`.
- **No lockfile**: There is no `poetry.lock`, `Pipfile.lock`, or `uv.lock`; `requirements.txt` itself serves as the single source of truth.
- **Registry**: No custom index URL (`--index-url`, `--extra-index-url`) or private registry configuration is present; pip resolves against PyPI by default.

### Conventions Observed
- Direct dependencies are declared explicitly in each language's manifest; transitive dependencies are left to the resolver and recorded in the lockfile (`pubspec.lock`) or inferred at install time (`requirements.txt`).
- Version pinning style differs between stacks: Flutter uses caret ranges (`^1.0.8`, `^9.2.4`) in `pubspec.yaml` while the Python backend pins exact versions (`==`) in `requirements.txt`.
- No vendoring of third-party source code is used anywhere in the repo — all dependencies are fetched remotely at build/install time.
- Secrets and runtime-only artifacts (`.env`, `bon_voyage.db`, `venv/`) are gitignored and not treated as dependencies.