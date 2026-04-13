import pytest
import requests
import os
import time

# Read from frontend .env or use environment variable
def get_base_url():
    # Try environment first
    if 'EXPO_PUBLIC_BACKEND_URL' in os.environ:
        return os.environ['EXPO_PUBLIC_BACKEND_URL'].rstrip('/')
    # Try reading from frontend .env
    try:
        with open('/app/frontend/.env', 'r') as f:
            for line in f:
                if line.startswith('EXPO_PUBLIC_BACKEND_URL='):
                    return line.split('=', 1)[1].strip().rstrip('/')
    except:
        pass
    raise ValueError("EXPO_PUBLIC_BACKEND_URL not found in environment or /app/frontend/.env")

BASE_URL = get_base_url()

class TestAuth:
    """Authentication endpoint tests"""

    def test_register_new_user(self, api_client):
        """Test user registration"""
        timestamp = int(time.time())
        payload = {
            "email": f"TEST_user_{timestamp}@example.com",
            "password": "test123",
            "name": f"Test User {timestamp}"
        }
        response = api_client.post(f"{BASE_URL}/api/auth/register", json=payload)
        print(f"Register response status: {response.status_code}")
        assert response.status_code == 200, f"Expected 200, got {response.status_code}: {response.text}"

        data = response.json()
        assert "user" in data, "Response missing 'user' field"
        assert "access_token" in data, "Response missing 'access_token' field"
        assert data["user"]["email"] == payload["email"].lower()
        assert data["user"]["name"] == payload["name"]
        assert "id" in data["user"]
        print(f"✓ User registered successfully: {data['user']['email']}")

    def test_register_duplicate_email(self, api_client):
        """Test registration with existing email fails"""
        response = api_client.post(f"{BASE_URL}/api/auth/register", json={
            "email": "admin@example.com",
            "password": "test123",
            "name": "Duplicate"
        })
        print(f"Duplicate register status: {response.status_code}")
        assert response.status_code == 400, f"Expected 400, got {response.status_code}"
        print("✓ Duplicate email rejected correctly")

    def test_login_success(self, api_client):
        """Test login with valid credentials"""
        response = api_client.post(f"{BASE_URL}/api/auth/login", json={
            "email": "admin@example.com",
            "password": "admin123"
        })
        print(f"Login response status: {response.status_code}")
        assert response.status_code == 200, f"Expected 200, got {response.status_code}: {response.text}"

        data = response.json()
        assert "user" in data
        assert "access_token" in data
        assert data["user"]["email"] == "admin@example.com"
        print(f"✓ Login successful for {data['user']['email']}")

    def test_login_invalid_credentials(self, api_client):
        """Test login with wrong password"""
        response = api_client.post(f"{BASE_URL}/api/auth/login", json={
            "email": "admin@example.com",
            "password": "wrongpassword"
        })
        print(f"Invalid login status: {response.status_code}")
        assert response.status_code == 401, f"Expected 401, got {response.status_code}"
        print("✓ Invalid credentials rejected")

    def test_get_me_authenticated(self, api_client):
        """Test /auth/me with valid token"""
        # Login first
        login_res = api_client.post(f"{BASE_URL}/api/auth/login", json={
            "email": "admin@example.com",
            "password": "admin123"
        })
        token = login_res.json()["access_token"]

        # Get user info
        response = api_client.get(
            f"{BASE_URL}/api/auth/me",
            headers={"Authorization": f"Bearer {token}"}
        )
        print(f"Get me status: {response.status_code}")
        assert response.status_code == 200, f"Expected 200, got {response.status_code}: {response.text}"

        data = response.json()
        assert data["email"] == "admin@example.com"
        assert "id" in data
        assert "name" in data
        print(f"✓ /auth/me returned user: {data['email']}")

    def test_get_me_unauthenticated(self, api_client):
        """Test /auth/me without token"""
        response = api_client.get(f"{BASE_URL}/api/auth/me")
        print(f"Unauthenticated /auth/me status: {response.status_code}")
        assert response.status_code == 401, f"Expected 401, got {response.status_code}"
        print("✓ Unauthenticated request rejected")


class TestPairing:
    """Pairing flow tests"""

    def test_create_invite_unpaired_user(self, api_client):
        """Test creating invite code"""
        # Register new user
        timestamp = int(time.time())
        reg_res = api_client.post(f"{BASE_URL}/api/auth/register", json={
            "email": f"TEST_inviter_{timestamp}@example.com",
            "password": "test123",
            "name": "Inviter"
        })
        token = reg_res.json()["access_token"]

        # Create invite
        response = api_client.post(
            f"{BASE_URL}/api/pairs/create-invite",
            headers={"Authorization": f"Bearer {token}"}
        )
        print(f"Create invite status: {response.status_code}")
        assert response.status_code == 200, f"Expected 200, got {response.status_code}: {response.text}"

        data = response.json()
        assert "invite_code" in data
        assert len(data["invite_code"]) == 6
        print(f"✓ Invite code created: {data['invite_code']}")

    def test_accept_invite_and_pair(self, api_client):
        """Test full pairing flow: create invite → accept → verify"""
        timestamp = int(time.time())

        # Register user 1 (inviter)
        user1_res = api_client.post(f"{BASE_URL}/api/auth/register", json={
            "email": f"TEST_pair1_{timestamp}@example.com",
            "password": "test123",
            "name": "Pair User 1"
        })
        token1 = user1_res.json()["access_token"]

        # Create invite
        invite_res = api_client.post(
            f"{BASE_URL}/api/pairs/create-invite",
            headers={"Authorization": f"Bearer {token1}"}
        )
        invite_code = invite_res.json()["invite_code"]
        print(f"Invite code: {invite_code}")

        # Register user 2 (accepter)
        user2_res = api_client.post(f"{BASE_URL}/api/auth/register", json={
            "email": f"TEST_pair2_{timestamp}@example.com",
            "password": "test123",
            "name": "Pair User 2"
        })
        token2 = user2_res.json()["access_token"]

        # Accept invite
        accept_res = api_client.post(
            f"{BASE_URL}/api/pairs/accept-invite",
            json={"invite_code": invite_code},
            headers={"Authorization": f"Bearer {token2}"}
        )
        print(f"Accept invite status: {accept_res.status_code}")
        assert accept_res.status_code == 200, f"Expected 200, got {accept_res.status_code}: {accept_res.text}"

        accept_data = accept_res.json()
        assert "pair_id" in accept_data
        assert "partner_name" in accept_data
        print(f"✓ Pairing successful, pair_id: {accept_data['pair_id']}")

        # Verify pairing status for user 1
        status1_res = api_client.get(
            f"{BASE_URL}/api/pairs/status",
            headers={"Authorization": f"Bearer {token1}"}
        )
        assert status1_res.status_code == 200
        status1 = status1_res.json()
        assert status1["status"] == "paired"
        assert status1["partner_name"] == "Pair User 2"
        print(f"✓ User 1 pair status verified: {status1['status']}")

        # Verify pairing status for user 2
        status2_res = api_client.get(
            f"{BASE_URL}/api/pairs/status",
            headers={"Authorization": f"Bearer {token2}"}
        )
        assert status2_res.status_code == 200
        status2 = status2_res.json()
        assert status2["status"] == "paired"
        assert status2["partner_name"] == "Pair User 1"
        print(f"✓ User 2 pair status verified: {status2['status']}")

    def test_get_pair_status_unpaired(self, api_client):
        """Test pair status for unpaired user"""
        timestamp = int(time.time())
        reg_res = api_client.post(f"{BASE_URL}/api/auth/register", json={
            "email": f"TEST_unpaired_{timestamp}@example.com",
            "password": "test123",
            "name": "Unpaired User"
        })
        token = reg_res.json()["access_token"]

        response = api_client.get(
            f"{BASE_URL}/api/pairs/status",
            headers={"Authorization": f"Bearer {token}"}
        )
        print(f"Pair status (unpaired) status: {response.status_code}")
        assert response.status_code == 200

        data = response.json()
        assert data["status"] == "unpaired"
        print(f"✓ Unpaired status correct: {data['status']}")


class TestCards:
    """Card creation and retrieval tests"""

    def test_create_card_paired_users(self, api_client):
        """Test card creation between paired users"""
        timestamp = int(time.time())

        # Create and pair two users
        user1_res = api_client.post(f"{BASE_URL}/api/auth/register", json={
            "email": f"TEST_card1_{timestamp}@example.com",
            "password": "test123",
            "name": "Card Sender"
        })
        token1 = user1_res.json()["access_token"]

        invite_res = api_client.post(
            f"{BASE_URL}/api/pairs/create-invite",
            headers={"Authorization": f"Bearer {token1}"}
        )
        invite_code = invite_res.json()["invite_code"]

        user2_res = api_client.post(f"{BASE_URL}/api/auth/register", json={
            "email": f"TEST_card2_{timestamp}@example.com",
            "password": "test123",
            "name": "Card Receiver"
        })
        token2 = user2_res.json()["access_token"]

        api_client.post(
            f"{BASE_URL}/api/pairs/accept-invite",
            json={"invite_code": invite_code},
            headers={"Authorization": f"Bearer {token2}"}
        )

        # Create card
        card_payload = {
            "background": "#E8D5F2",
            "elements": [
                {
                    "id": "1",
                    "type": "text",
                    "content": "Merhaba!",
                    "x": 50,
                    "y": 100,
                    "fontSize": 24,
                    "color": "#333333"
                },
                {
                    "id": "2",
                    "type": "sticker",
                    "content": "❤️",
                    "x": 150,
                    "y": 150,
                    "size": 40
                }
            ]
        }
        response = api_client.post(
            f"{BASE_URL}/api/cards/create",
            json=card_payload,
            headers={"Authorization": f"Bearer {token1}"}
        )
        print(f"Create card status: {response.status_code}")
        assert response.status_code == 200, f"Expected 200, got {response.status_code}: {response.text}"

        data = response.json()
        assert "id" in data
        assert data["background"] == card_payload["background"]
        assert len(data["elements"]) == 2
        assert data["sender_name"] == "Card Sender"
        print(f"✓ Card created successfully, id: {data['id']}")

        # Verify receiver can get the card
        get_res = api_client.get(
            f"{BASE_URL}/api/cards/latest",
            headers={"Authorization": f"Bearer {token2}"}
        )
        assert get_res.status_code == 200
        card_data = get_res.json()
        assert card_data["card"] is not None
        assert card_data["card"]["sender_name"] == "Card Sender"
        assert card_data["card"]["background"] == "#E8D5F2"
        print(f"✓ Receiver retrieved card successfully")

    def test_create_card_unpaired_user_fails(self, api_client):
        """Test card creation fails for unpaired user"""
        timestamp = int(time.time())
        reg_res = api_client.post(f"{BASE_URL}/api/auth/register", json={
            "email": f"TEST_unpaired_card_{timestamp}@example.com",
            "password": "test123",
            "name": "Unpaired"
        })
        token = reg_res.json()["access_token"]

        response = api_client.post(
            f"{BASE_URL}/api/cards/create",
            json={
                "background": "#E8D5F2",
                "elements": [{"id": "1", "type": "text", "content": "Test", "x": 50, "y": 50}]
            },
            headers={"Authorization": f"Bearer {token}"}
        )
        print(f"Create card (unpaired) status: {response.status_code}")
        assert response.status_code == 400, f"Expected 400, got {response.status_code}"
        print("✓ Unpaired user cannot create card")

    def test_get_latest_card_no_cards(self, api_client):
        """Test getting latest card when none exist"""
        timestamp = int(time.time())
        reg_res = api_client.post(f"{BASE_URL}/api/auth/register", json={
            "email": f"TEST_nocard_{timestamp}@example.com",
            "password": "test123",
            "name": "No Cards"
        })
        token = reg_res.json()["access_token"]

        response = api_client.get(
            f"{BASE_URL}/api/cards/latest",
            headers={"Authorization": f"Bearer {token}"}
        )
        print(f"Get latest card (none) status: {response.status_code}")
        assert response.status_code == 200
        data = response.json()
        assert data["card"] is None
        print("✓ No cards returned correctly")


class TestLimits:
    """Daily limit tests"""

    def test_get_limit_status(self, api_client):
        """Test getting daily limit status"""
        timestamp = int(time.time())
        reg_res = api_client.post(f"{BASE_URL}/api/auth/register", json={
            "email": f"TEST_limit_{timestamp}@example.com",
            "password": "test123",
            "name": "Limit User"
        })
        token = reg_res.json()["access_token"]

        response = api_client.get(
            f"{BASE_URL}/api/limits/status",
            headers={"Authorization": f"Bearer {token}"}
        )
        print(f"Get limit status: {response.status_code}")
        assert response.status_code == 200, f"Expected 200, got {response.status_code}: {response.text}"

        data = response.json()
        assert "used" in data
        assert "limit" in data
        assert "remaining" in data
        assert data["limit"] == 2
        assert data["used"] == 0
        assert data["remaining"] == 2
        print(f"✓ Limit status: {data['used']}/{data['limit']} used")

    def test_daily_limit_enforcement(self, api_client):
        """Test that daily limit (2 cards) is enforced"""
        timestamp = int(time.time())

        # Create and pair two users
        user1_res = api_client.post(f"{BASE_URL}/api/auth/register", json={
            "email": f"TEST_limit1_{timestamp}@example.com",
            "password": "test123",
            "name": "Limit Sender"
        })
        token1 = user1_res.json()["access_token"]

        invite_res = api_client.post(
            f"{BASE_URL}/api/pairs/create-invite",
            headers={"Authorization": f"Bearer {token1}"}
        )
        invite_code = invite_res.json()["invite_code"]

        user2_res = api_client.post(f"{BASE_URL}/api/auth/register", json={
            "email": f"TEST_limit2_{timestamp}@example.com",
            "password": "test123",
            "name": "Limit Receiver"
        })
        token2 = user2_res.json()["access_token"]

        api_client.post(
            f"{BASE_URL}/api/pairs/accept-invite",
            json={"invite_code": invite_code},
            headers={"Authorization": f"Bearer {token2}"}
        )

        card_payload = {
            "background": "#E8D5F2",
            "elements": [{"id": "1", "type": "text", "content": "Test", "x": 50, "y": 50}]
        }

        # Send first card
        res1 = api_client.post(
            f"{BASE_URL}/api/cards/create",
            json=card_payload,
            headers={"Authorization": f"Bearer {token1}"}
        )
        assert res1.status_code == 200
        print("✓ First card sent")

        # Send second card
        res2 = api_client.post(
            f"{BASE_URL}/api/cards/create",
            json=card_payload,
            headers={"Authorization": f"Bearer {token1}"}
        )
        assert res2.status_code == 200
        print("✓ Second card sent")

        # Try to send third card (should fail)
        res3 = api_client.post(
            f"{BASE_URL}/api/cards/create",
            json=card_payload,
            headers={"Authorization": f"Bearer {token1}"}
        )
        print(f"Third card attempt status: {res3.status_code}")
        assert res3.status_code == 429, f"Expected 429, got {res3.status_code}"
        print("✓ Daily limit enforced (2/2)")

        # Check limit status
        limit_res = api_client.get(
            f"{BASE_URL}/api/limits/status",
            headers={"Authorization": f"Bearer {token1}"}
        )
        limit_data = limit_res.json()
        assert limit_data["used"] == 2
        assert limit_data["remaining"] == 0
        print(f"✓ Limit status correct: {limit_data['used']}/{limit_data['limit']}")
