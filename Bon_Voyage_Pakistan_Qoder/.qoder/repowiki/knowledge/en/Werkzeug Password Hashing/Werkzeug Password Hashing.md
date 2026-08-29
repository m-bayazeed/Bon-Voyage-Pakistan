---
kind: external_dependency
name: Werkzeug Password Hashing
slug: werkzeug
category: external_dependency
category_hints:
    - framework_behavior
scope:
    - '**'
---

Password hashing is delegated to Werkzeug's `generate_password_hash` / `check_password_hash` (no salt or algorithm configured by the caller). New user passwords are hashed before insert; login compares against stored hashes. Do not replace this with plaintext comparison when extending the auth flow.