---
kind: external_dependency
name: PyJWT (JSON Web Tokens)
slug: pyjwt
category: external_dependency
category_hints:
    - auth_protocol
scope:
    - '**'
---

Used for stateless JWT-based authentication. Tokens are HS256-encoded with a payload containing `user_id`, `exp`, and `iat`; expiration hours come from the `JWT_EXPIRATION_HOURS` env var. Clients must send tokens in the `Authorization: Bearer <token>` header on protected routes. The signing secret is read from the `SECRET_KEY` environment variable (see `backend/.env`). Logout is client-side only since tokens are stateless.