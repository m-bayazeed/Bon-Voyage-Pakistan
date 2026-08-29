---
kind: error_handling
name: Flask Route-Level Errors + Flutter Service Error Wrappers for Auth Flow
category: error_handling
scope:
    - '**'
source_files:
    - backend/app.py
    - backend/database.py
    - lib/services/auth_service.dart
    - lib/screens/login_screen.dart
    - lib/screens/signup_screen.dart
    - lib/config/api_config.dart
---

## Overview

The Bon Voyage Pakistan app uses a simple, request-scoped error-handling pattern split across two layers: the Flask backend returns structured JSON responses with `success`/`message`/`errors` fields and HTTP status codes, and the Flutter client wraps every network call in try/catch blocks that translate exceptions into the same `{ success: false, message: ... }` shape. There is no centralized exception class hierarchy, no global error middleware, and no panic/recover usage.

## Backend (Flask) — route-level validation and decorator-based auth errors

- **Authentication decorator** (`backend/app.py`, `token_required`): Extracts the `Authorization: Bearer <token>` header; if missing, expired, or invalid it immediately returns `jsonify({"success": False, "message": ...}), 401`. Specific `jwt.ExpiredSignatureError` and `jwt.InvalidTokenError` are caught and mapped to user-friendly messages.
- **Route handlers** (`signup`, `login`, `me`, `logout`): All input validation is done inline with an `errors = []` list; when non-empty the handler returns `jsonify({"success": False, "message": errors[0], "errors": errors}), 400`. Duplicate-email inserts return `409 Conflict` via `create_user` returning `None` on `sqlite3.IntegrityError`.
- **Database layer** (`backend/database.py`): Exceptions are swallowed at the lowest level — `create_user` catches `sqlite3.IntegrityError` and returns `None`; query helpers return `None` on not-found instead of raising. This keeps callers free to branch on `None` rather than handle DB exceptions.
- **No global error handlers**: There are no `@app.errorhandler(...)` registrations; unhandled exceptions would fall through to Flask's default 500 response.
- **Security note**: Login deliberately returns a single generic `"Invalid email or password"` message regardless of whether the user exists or the password is wrong, avoiding user enumeration.

## Frontend (Flutter) — service-layer error wrapping with typed catch blocks

- **Centralized service** (`lib/services/auth_service.dart`): Every public method (`signup`, `login`, `verifyToken`) wraps its HTTP call in a `try / on TimeoutException / on http.ClientException / catch (e)` block. Each branch logs via `dart:developer` and returns a uniform `Map<String, dynamic>` with `success: false` plus a human-readable `message`:
  - `_timeoutError()` — server did not respond within the 15-second per-request timeout.
  - `_connectionError()` — device cannot reach the backend (e.g., wrong Wi-Fi).
  - `_genericError(Object)` — catch-all for JSON parse failures and other unexpected errors.
- **Token verification special case**: Network timeouts during `verifyToken` intentionally keep the stored token so the user can retry later; only a successful response clears state, while an invalid/expired token triggers `clearAll()`.
- **Logout best-effort**: The logout call is wrapped in a bare `try/catch` that ignores any failure because local state is cleared regardless.
- **Screens consume the contract uniformly**: `LoginScreen` and `SignupScreen` check `result['success'] == true` to navigate forward; otherwise they set a local `_errorMessage` field and render it via a shared `_buildErrorBanner()` widget (a bordered container using `AppTheme.error`).
- **Local form validation**: Screens also perform pre-flight validation via `FormState.validator` (email regex, password length, confirm-password match) before calling the service, so many errors never leave the UI layer.

## Conventions and constraints observed

| Area | Convention | Evidence |
|---|---|---|
| Response envelope | Backend always returns `{ success: bool, message: string, ... }`; screens treat `success == true` as the success path. | `app.py` routes; `auth_service.dart` branches on `data['success']`; login/signup screens branch on `result['success']`. |
| HTTP status codes | 200/201 for success, 400 for bad input, 401 for missing/expired/invalid token, 409 for duplicate email. | `app.py` route returns. |
| Validation location | Input validation happens twice: client-side in screen validators (fast UX feedback) and server-side in Flask routes (security boundary). | `login_screen.dart` / `signup_screen.dart` validators + `app.py` validation blocks. |
| Exception propagation | Backend swallows DB exceptions and returns sentinel values (`None`); frontend swallows network exceptions and maps them to typed helper methods. | `database.py` `IntegrityError` catch; `auth_service.dart` `on TimeoutException` / `on ClientException`. |
| Token lifecycle | Missing/expired/invalid tokens are treated as 401 by the decorator; on the client, `verifyToken` clears local storage on failure but preserves it on transient network errors. | `token_required` decorator; `verifyToken` catch blocks. |
| Logging | Backend uses no logging framework; frontend uses `dart:developer.log` with a `name: 'AuthService'` tag for all error paths. | `auth_service.dart` log calls. |
| No global error handling | No `@app.errorhandler`, no Flutter `ErrorWidget.builder`, no custom `HttpInterceptor`. Errors are handled inline at each call site. | Absence of such code in scanned files. |

## Key files

- `backend/app.py` — Flask routes, `token_required` decorator, validation, JWT error mapping.
- `backend/database.py` — SQLite helpers; `IntegrityError` → `None` sentinel.
- `lib/services/auth_service.dart` — Central HTTP client wrapper; timeout/connection/generic error builders; secure token storage.
- `lib/screens/login_screen.dart` — Consumes service result, renders `_buildErrorBanner`.
- `lib/screens/signup_screen.dart` — Same pattern with richer password requirement UI.
- `lib/config/api_config.dart` — Centralizes base URL used by all requests.