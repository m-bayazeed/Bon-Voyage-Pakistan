"""
Bon Voyage Pakistan - Backend Database Module
Handles SQLite database connection and user table creation.
"""

import sqlite3
import os

# Database file path - stored in the backend directory
DATABASE_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bon_voyage.db")


def get_connection():
    """Create and return a database connection."""
    conn = sqlite3.connect(DATABASE_PATH)
    conn.row_factory = sqlite3.Row  # Return rows as dictionaries
    return conn


def init_db():
    """Initialize the database and create the users table if it doesn't exist."""
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)

    conn.commit()
    conn.close()


def create_user(name, email, password_hash):
    """Insert a new user into the database. Returns the new user's id or None on failure."""
    try:
        conn = get_connection()
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO users (name, email, password_hash) VALUES (?, ?, ?)",
            (name, email, password_hash),
        )
        conn.commit()
        user_id = cursor.lastrowid
        conn.close()
        return user_id
    except sqlite3.IntegrityError:
        # Email already exists
        return None


def find_user_by_email(email):
    """Find a user by email address. Returns the user row or None."""
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE email = ?", (email,))
    user = cursor.fetchone()
    conn.close()
    return user


def find_user_by_id(user_id):
    """Find a user by id. Returns the user row or None."""
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,))
    user = cursor.fetchone()
    conn.close()
    return user


def update_user_name(user_id, new_name):
    """Update a user's display name by id."""
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("UPDATE users SET name = ? WHERE id = ?", (new_name, user_id))
    conn.commit()
    conn.close()
    return True


def update_user_password(user_id, new_password_hash):
    """Update a user's password hash by id."""
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("UPDATE users SET password_hash = ? WHERE id = ?", (new_password_hash, user_id))
    conn.commit()
    conn.close()
    return True

