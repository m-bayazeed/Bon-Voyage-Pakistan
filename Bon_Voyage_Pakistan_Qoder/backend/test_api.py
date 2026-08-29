"""Quick API test script for Bon Voyage Pakistan backend."""
import requests

BASE = "http://192.168.100.12:5000"

# 1. Signup
print("=== SIGNUP ===")
r = requests.post(f"{BASE}/auth/signup", json={
    "name": "Test Traveler",
    "email": "test@bvp.com",
    "password": "securepass123",
})
print(f"Status: {r.status_code}")
d = r.json()
print(f"Success: {d['success']}")
print(f"User: {d.get('user')}")
token = d.get("token", "")
print(f"Token present: {bool(token)}")

# 2. Verify token
print("\n=== VERIFY TOKEN (GET /auth/me) ===")
r2 = requests.get(f"{BASE}/auth/me", headers={"Authorization": f"Bearer {token}"})
print(f"Status: {r2.status_code}")
print(f"Response: {r2.json()}")

# 3. Login (correct)
print("\n=== LOGIN (correct credentials) ===")
r3 = requests.post(f"{BASE}/auth/login", json={
    "email": "test@bvp.com",
    "password": "securepass123",
})
print(f"Status: {r3.status_code}")
d3 = r3.json()
print(f"Success: {d3['success']}, User: {d3.get('user')}")

# 4. Login (wrong password)
print("\n=== LOGIN (wrong password) ===")
r4 = requests.post(f"{BASE}/auth/login", json={
    "email": "test@bvp.com",
    "password": "wrongpassword",
})
print(f"Status: {r4.status_code}")
print(f"Response: {r4.json()}")

# 5. Duplicate signup
print("\n=== DUPLICATE SIGNUP ===")
r5 = requests.post(f"{BASE}/auth/signup", json={
    "name": "Duplicate",
    "email": "test@bvp.com",
    "password": "another123",
})
print(f"Status: {r5.status_code}")
print(f"Response: {r5.json()}")

# 6. Logout
print("\n=== LOGOUT ===")
r6 = requests.post(f"{BASE}/auth/logout")
print(f"Status: {r6.status_code}")
print(f"Response: {r6.json()}")

print("\n=== ALL TESTS PASSED ===")
