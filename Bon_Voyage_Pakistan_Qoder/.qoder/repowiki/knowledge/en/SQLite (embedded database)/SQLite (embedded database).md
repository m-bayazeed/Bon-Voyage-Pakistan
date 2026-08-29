---
kind: external_dependency
name: SQLite (embedded database)
slug: sqlite
category: external_dependency
category_hints:
    - client_constraint
scope:
    - '**'
---

Embedded file-based relational database used as the sole data store. The database file `bon_voyage.db` lives next to `database.py` inside `backend/`. A single `users` table holds `id`, `name`, `email` (unique), `password_hash`, and `created_at`. There is no connection pooling — each query opens and closes its own connection. This makes the backend unsuitable for concurrent write workloads without migration to a server-process DB.