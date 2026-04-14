from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI, APIRouter, HTTPException, Request, Depends
from starlette.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
import os
import logging
import bcrypt
import jwt
from jwt.algorithms import RSAAlgorithm
import secrets
import string
import httpx
from pydantic import BaseModel, Field, EmailStr
from typing import List, Optional
from datetime import datetime, timezone, timedelta
from bson import ObjectId

# MongoDB connection
mongo_url = os.environ['MONGO_URL']
client = AsyncIOMotorClient(mongo_url)
db = client[os.environ.get('DB_NAME', 'surprise_card_app')]

app = FastAPI()
api_router = APIRouter(prefix="/api")

JWT_ALGORITHM = "HS256"

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


# --- Pydantic Models ---
class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    name: str

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class UserResponse(BaseModel):
    id: str
    email: str
    name: str
    pair_ids: List[str] = []

class TokenResponse(BaseModel):
    user: UserResponse
    access_token: str

class InviteResponse(BaseModel):
    invite_code: str

class AcceptInviteRequest(BaseModel):
    invite_code: str
    partner_nickname: Optional[str] = None
    relationship: Optional[str] = None

class FriendResponse(BaseModel):
    pair_id: str
    partner_id: str
    partner_name: str
    partner_nickname: Optional[str] = None
    relationship: Optional[str] = None
    invite_code: Optional[str] = None  # only when status is "pending"
    status: str  # "paired" | "pending"

class PairStatusResponse(BaseModel):
    status: str  # "unpaired" | "pending" | "paired" (backward compat: first friend)
    partner_name: Optional[str] = None
    partner_nickname: Optional[str] = None
    pair_id: Optional[str] = None
    invite_code: Optional[str] = None
    friends: List[FriendResponse] = []  # all friends

class UnpairRequest(BaseModel):
    pair_id: str

class CardElement(BaseModel):
    id: str
    type: str
    content: str
    x: float
    y: float
    fontSize: Optional[float] = None
    color: Optional[str] = None
    size: Optional[float] = None
    fontFamily: Optional[str] = None
    rotation: Optional[float] = None

class CreateCardRequest(BaseModel):
    pair_id: str  # which friend to send to
    background: str
    elements: List[CardElement]

class CardResponse(BaseModel):
    id: str
    pair_id: str
    sender_id: str
    sender_name: str
    background: str
    elements: List[dict]
    created_at: str

class LimitResponse(BaseModel):
    used: int
    limit: int
    remaining: int

class DeviceRegisterRequest(BaseModel):
    device_token: str
    platform: str = "ios"


# --- Auth Helpers ---
def get_jwt_secret() -> str:
    return os.environ.get("JWT_SECRET", "default-secret-change-me")

def hash_password(password: str) -> str:
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(password.encode("utf-8"), salt).decode("utf-8")

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return bcrypt.checkpw(plain_password.encode("utf-8"), hashed_password.encode("utf-8"))

def create_access_token(user_id: str, email: str) -> str:
    payload = {
        "sub": user_id,
        "email": email,
        "exp": datetime.now(timezone.utc) + timedelta(days=7),
        "type": "access"
    }
    return jwt.encode(payload, get_jwt_secret(), algorithm=JWT_ALGORITHM)

async def get_current_user(request: Request) -> dict:
    token = request.headers.get("Authorization", "")
    if token.startswith("Bearer "):
        token = token[7:]
    if not token:
        raise HTTPException(status_code=401, detail="Not authenticated")
    try:
        payload = jwt.decode(token, get_jwt_secret(), algorithms=[JWT_ALGORITHM])
        if payload.get("type") != "access":
            raise HTTPException(status_code=401, detail="Invalid token type")
        user = await db.users.find_one({"_id": ObjectId(payload["sub"])})
        if not user:
            raise HTTPException(status_code=401, detail="User not found")
        user["id"] = str(user["_id"])
        # Migrate: old single pair_id → pair_ids list
        if "pair_ids" not in user:
            old = user.get("pair_id")
            user["pair_ids"] = [str(old)] if old else []
        else:
            user["pair_ids"] = [str(p) for p in user.get("pair_ids", []) if p]
        return user
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")

def generate_invite_code(length=6):
    chars = string.ascii_uppercase + string.digits
    return ''.join(secrets.choice(chars) for _ in range(length))

async def build_friends_list(user: dict) -> List[FriendResponse]:
    """Build the full friends list for a user from their pair_ids."""
    friends = []
    for pair_id_str in user.get("pair_ids", []):
        try:
            pair = await db.pairs.find_one({"_id": ObjectId(pair_id_str)})
            if not pair:
                continue
            partner_id = pair["user_2"] if pair["user_1"] == user["id"] else pair["user_1"]
            partner = await db.users.find_one({"_id": ObjectId(partner_id)})
            if pair["user_1"] == user["id"]:
                nickname = pair.get("nickname_1")
            else:
                nickname = pair.get("nickname_2")
            friends.append(FriendResponse(
                pair_id=pair_id_str,
                partner_id=partner_id,
                partner_name=partner.get("name", "") if partner else "",
                partner_nickname=nickname,
                relationship=pair.get("relationship"),
                status="paired"
            ))
        except Exception:
            continue
    return friends


# --- Auth Routes ---
@api_router.post("/auth/register", response_model=TokenResponse)
async def register(req: RegisterRequest):
    email = req.email.lower()
    existing = await db.users.find_one({"email": email})
    if existing:
        raise HTTPException(status_code=400, detail="Bu e-posta zaten kayıtlı")

    user_doc = {
        "email": email,
        "password_hash": hash_password(req.password),
        "name": req.name,
        "pair_ids": [],
        "created_at": datetime.now(timezone.utc)
    }
    result = await db.users.insert_one(user_doc)
    user_id = str(result.inserted_id)
    token = create_access_token(user_id, email)

    return TokenResponse(
        user=UserResponse(id=user_id, email=email, name=req.name, pair_ids=[]),
        access_token=token
    )

@api_router.post("/auth/login", response_model=TokenResponse)
async def login(req: LoginRequest):
    email = req.email.lower()
    user = await db.users.find_one({"email": email})
    if not user:
        raise HTTPException(status_code=401, detail="Geçersiz e-posta veya şifre")
    if not verify_password(req.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Geçersiz e-posta veya şifre")

    user_id = str(user["_id"])
    # Migrate old pair_id to pair_ids
    if "pair_ids" not in user:
        old = user.get("pair_id")
        pair_ids = [str(old)] if old else []
    else:
        pair_ids = [str(p) for p in user.get("pair_ids", []) if p]

    token = create_access_token(user_id, email)
    return TokenResponse(
        user=UserResponse(id=user_id, email=email, name=user.get("name", ""), pair_ids=pair_ids),
        access_token=token
    )

class AppleSignInRequest(BaseModel):
    identity_token: str
    full_name: Optional[str] = None
    email: Optional[str] = None   # only sent on first sign-in by Apple

class ForgotPasswordRequest(BaseModel):
    email: str

class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str

async def verify_apple_identity_token(identity_token: str) -> dict:
    """Verify Apple's identity token against Apple's public keys."""
    bundle_id = os.environ.get("APNS_BUNDLE_ID", "com.nubittech.surprisecard")
    async with httpx.AsyncClient() as client:
        resp = await client.get("https://appleid.apple.com/auth/keys", timeout=10)
        resp.raise_for_status()
        apple_keys = resp.json()["keys"]

    header = jwt.get_unverified_header(identity_token)
    kid = header.get("kid")
    apple_key_data = next((k for k in apple_keys if k["kid"] == kid), None)
    if not apple_key_data:
        raise HTTPException(status_code=401, detail="Apple public key bulunamadı")

    public_key = RSAAlgorithm.from_jwk(apple_key_data)
    try:
        payload = jwt.decode(
            identity_token,
            public_key,
            algorithms=["RS256"],
            audience=bundle_id,
            issuer="https://appleid.apple.com"
        )
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Apple token süresi dolmuş")
    except jwt.InvalidTokenError as e:
        raise HTTPException(status_code=401, detail=f"Geçersiz Apple token: {e}")
    return payload

@api_router.post("/auth/apple", response_model=TokenResponse)
async def apple_sign_in(req: AppleSignInRequest):
    payload = await verify_apple_identity_token(req.identity_token)
    apple_sub = payload["sub"]
    # Email is only provided by Apple on the first sign-in
    email = payload.get("email") or req.email

    # Try to find user by apple_id
    user = await db.users.find_one({"apple_id": apple_sub})

    if not user and email:
        # If not found by apple_id, check if email is already registered
        user = await db.users.find_one({"email": email.lower()})
        if user:
            # Link this Apple ID to the existing account
            await db.users.update_one({"_id": user["_id"]}, {"$set": {"apple_id": apple_sub}})
            user["apple_id"] = apple_sub

    if not user:
        # Create a new user
        name = req.full_name or (email.split("@")[0] if email else "Apple Kullanıcısı")
        fallback_email = email.lower() if email else f"{apple_sub}@privaterelay.appleid.com"
        user_doc = {
            "email": fallback_email,
            "apple_id": apple_sub,
            "password_hash": None,
            "name": name,
            "pair_ids": [],
            "created_at": datetime.now(timezone.utc)
        }
        result = await db.users.insert_one(user_doc)
        user = await db.users.find_one({"_id": result.inserted_id})

    user_id = str(user["_id"])
    user_email = user.get("email", "")
    pair_ids = [str(p) for p in user.get("pair_ids", []) if p]
    token = create_access_token(user_id, user_email)
    return TokenResponse(
        user=UserResponse(id=user_id, email=user_email, name=user.get("name", ""), pair_ids=pair_ids),
        access_token=token
    )

@api_router.post("/auth/forgot-password")
async def forgot_password(req: ForgotPasswordRequest):
    email = req.email.lower().strip()
    user = await db.users.find_one({"email": email})
    # Always return success to prevent email enumeration
    if user:
        reset_token = secrets.token_urlsafe(32)
        expires_at = datetime.now(timezone.utc) + timedelta(hours=1)
        await db.password_resets.insert_one({
            "user_id": user["_id"],
            "token": reset_token,
            "expires_at": expires_at,
            "used": False
        })
        # TODO: Send email with reset link when email service is configured
        logger.info(f"[Auth] Password reset token for {email}: {reset_token}")
    return {"message": "Sıfırlama bağlantısı e-posta adresinize gönderildi."}

@api_router.post("/auth/reset-password")
async def reset_password(req: ResetPasswordRequest):
    record = await db.password_resets.find_one({"token": req.token, "used": False})
    if not record:
        raise HTTPException(status_code=400, detail="Geçersiz veya süresi dolmuş token")
    if record["expires_at"] < datetime.now(timezone.utc):
        raise HTTPException(status_code=400, detail="Token süresi dolmuş")
    new_hash = hash_password(req.new_password)
    await db.users.update_one({"_id": record["user_id"]}, {"$set": {"password_hash": new_hash}})
    await db.password_resets.update_one({"_id": record["_id"]}, {"$set": {"used": True}})
    return {"message": "Şifreniz başarıyla sıfırlandı."}

@api_router.get("/auth/me", response_model=UserResponse)
async def get_me(user: dict = Depends(get_current_user)):
    return UserResponse(
        id=user["id"],
        email=user["email"],
        name=user.get("name", ""),
        pair_ids=user.get("pair_ids", [])
    )


# --- Pairing Routes ---
@api_router.post("/pairs/create-invite", response_model=InviteResponse)
async def create_invite(user: dict = Depends(get_current_user)):
    # Allow multiple invites/friends — no restriction on existing pairs
    existing = await db.invites.find_one({"creator_id": user["id"], "status": "pending"})
    if existing:
        return InviteResponse(invite_code=existing["code"])

    code = generate_invite_code()
    while await db.invites.find_one({"code": code}):
        code = generate_invite_code()

    await db.invites.insert_one({
        "code": code,
        "creator_id": user["id"],
        "creator_name": user.get("name", ""),
        "status": "pending",
        "created_at": datetime.now(timezone.utc)
    })
    return InviteResponse(invite_code=code)

@api_router.post("/pairs/accept-invite")
async def accept_invite(req: AcceptInviteRequest, user: dict = Depends(get_current_user)):
    invite = await db.invites.find_one({"code": req.invite_code.upper(), "status": "pending"})
    if not invite:
        raise HTTPException(status_code=404, detail="Geçersiz veya süresi dolmuş davet kodu")

    creator_id = invite["creator_id"]

    # Check if already friends with this person
    for pair_id_str in user.get("pair_ids", []):
        try:
            pair = await db.pairs.find_one({"_id": ObjectId(pair_id_str)})
            if pair and (pair["user_1"] == creator_id or pair["user_2"] == creator_id):
                raise HTTPException(status_code=400, detail="Bu kişiyle zaten arkadaşsın")
        except HTTPException:
            raise
        except Exception:
            continue

    pair_doc = {
        "user_1": creator_id,
        "user_2": user["id"],
        "nickname_1": None,
        "nickname_2": req.partner_nickname,
        "relationship": req.relationship,
        "created_at": datetime.now(timezone.utc)
    }
    result = await db.pairs.insert_one(pair_doc)
    pair_id = result.inserted_id
    pair_id_str = str(pair_id)

    # Append to pair_ids list (migrate old users if needed)
    await db.users.update_one(
        {"_id": ObjectId(creator_id)},
        {"$addToSet": {"pair_ids": pair_id_str}, "$set": {"pair_id": pair_id}}
    )
    await db.users.update_one(
        {"_id": ObjectId(user["id"])},
        {"$addToSet": {"pair_ids": pair_id_str}, "$set": {"pair_id": pair_id}}
    )
    await db.invites.update_one({"_id": invite["_id"]}, {"$set": {"status": "used"}})

    partner = await db.users.find_one({"_id": ObjectId(creator_id)})
    return {
        "message": "Eşleşme tamamlandı!",
        "pair_id": pair_id_str,
        "partner_name": partner.get("name", "") if partner else ""
    }

@api_router.get("/pairs/status", response_model=PairStatusResponse)
async def get_pair_status(user: dict = Depends(get_current_user)):
    pair_ids = user.get("pair_ids", [])

    # Pending invite (not yet accepted by anyone)
    pending_invite = await db.invites.find_one({"creator_id": user["id"], "status": "pending"})

    # Build full friends list
    friends = await build_friends_list(user)

    if not friends and not pending_invite:
        return PairStatusResponse(status="unpaired", friends=[])

    if not friends and pending_invite:
        return PairStatusResponse(
            status="pending",
            invite_code=pending_invite["code"],
            friends=[]
        )

    # Has at least one friend — return first friend for backward compat + full list
    first = friends[0]
    return PairStatusResponse(
        status="paired",
        partner_name=first.partner_name,
        partner_nickname=first.partner_nickname,
        pair_id=first.pair_id,
        invite_code=pending_invite["code"] if pending_invite else None,
        friends=friends
    )

@api_router.get("/pairs/friends", response_model=List[FriendResponse])
async def get_friends(user: dict = Depends(get_current_user)):
    return await build_friends_list(user)

@api_router.post("/pairs/unpair")
async def unpair(req: UnpairRequest, user: dict = Depends(get_current_user)):
    pair_id_str = req.pair_id
    if pair_id_str not in user.get("pair_ids", []):
        raise HTTPException(status_code=400, detail="Bu eşleşme bulunamadı")

    pair = await db.pairs.find_one({"_id": ObjectId(pair_id_str)})
    if pair:
        await db.users.update_one(
            {"_id": ObjectId(pair["user_1"])},
            {"$pull": {"pair_ids": pair_id_str}}
        )
        await db.users.update_one(
            {"_id": ObjectId(pair["user_2"])},
            {"$pull": {"pair_ids": pair_id_str}}
        )
        await db.pairs.delete_one({"_id": pair["_id"]})
        # Also purge any cards that belonged to this pair so they cannot
        # resurface from caches or be fetched by /cards/latest.
        await db.cards.delete_many({"pair_id": pair_id_str})

    return {"message": "Arkadaşlık silindi"}


# --- Card Routes ---
@api_router.post("/cards/create", response_model=CardResponse)
async def create_card(req: CreateCardRequest, user: dict = Depends(get_current_user)):
    if req.pair_id not in user.get("pair_ids", []):
        raise HTTPException(status_code=400, detail="Bu eşleşme bulunamadı")

    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    daily_count = await db.daily_limits.find_one({"user_id": user["id"], "date": today})
    used = daily_count["count"] if daily_count else 0

    pair = await db.pairs.find_one({"_id": ObjectId(req.pair_id)})
    if not pair:
        raise HTTPException(status_code=400, detail="Eşleşme bulunamadı")

    receiver_id = pair["user_2"] if pair["user_1"] == user["id"] else pair["user_1"]

    # Replace semantics: we only keep ONE active card per pair at a time.
    # Physically delete any previous card(s) for this pair so stale entries
    # can never resurface in a widget fallback or a race-sorted query.
    await db.cards.delete_many({"pair_id": req.pair_id})

    card_doc = {
        "pair_id": req.pair_id,
        "sender_id": user["id"],
        "sender_name": user.get("name", ""),
        "receiver_id": receiver_id,
        "background": req.background,
        "elements": [e.dict() for e in req.elements],
        "created_at": datetime.now(timezone.utc)
    }
    result = await db.cards.insert_one(card_doc)

    await db.daily_limits.update_one(
        {"user_id": user["id"], "date": today},
        {"$inc": {"count": 1}},
        upsert=True
    )

    # Send push notification to the receiver so their widget updates instantly
    try:
        await send_push_notification(receiver_id, {
            "type": "new_card",
            "pair_id": req.pair_id,
            "sender_name": user.get("name", ""),
        })
    except Exception as e:
        logger.error(f"[Push] Error sending notification: {e}")
        # Don't fail the card creation if push fails

    return CardResponse(
        id=str(result.inserted_id),
        pair_id=card_doc["pair_id"],
        sender_id=card_doc["sender_id"],
        sender_name=card_doc["sender_name"],
        background=card_doc["background"],
        elements=card_doc["elements"],
        created_at=card_doc["created_at"].isoformat()
    )

@api_router.get("/cards/latest")
async def get_latest_card(user: dict = Depends(get_current_user), pair_id: Optional[str] = None):
    """Get latest received card. Optionally filter by pair_id."""
    pair_ids = user.get("pair_ids", [])
    if not pair_ids:
        return {"card": None}

    query: dict = {"receiver_id": user["id"]}
    if pair_id and pair_id in pair_ids:
        query["pair_id"] = pair_id
    else:
        query["pair_id"] = {"$in": pair_ids}

    card = await db.cards.find_one(query, sort=[("created_at", -1)])
    if not card:
        return {"card": None}

    return {
        "card": {
            "id": str(card["_id"]),
            "pair_id": card["pair_id"],
            "sender_id": card["sender_id"],
            "sender_name": card.get("sender_name", ""),
            "background": card["background"],
            "elements": card["elements"],
            "created_at": card["created_at"].isoformat() if isinstance(card["created_at"], datetime) else card["created_at"]
        }
    }

@api_router.get("/cards/sent")
async def get_sent_cards(user: dict = Depends(get_current_user)):
    pair_ids = user.get("pair_ids", [])
    if not pair_ids:
        return {"cards": []}

    cards = await db.cards.find(
        {"sender_id": user["id"], "pair_id": {"$in": pair_ids}},
    ).sort("created_at", -1).to_list(20)

    return {
        "cards": [{
            "id": str(c["_id"]),
            "pair_id": c["pair_id"],
            "sender_id": c["sender_id"],
            "sender_name": c.get("sender_name", ""),
            "background": c["background"],
            "elements": c["elements"],
            "created_at": c["created_at"].isoformat() if isinstance(c["created_at"], datetime) else c["created_at"]
        } for c in cards]
    }


# --- Account Management ---

@api_router.delete("/auth/account")
async def delete_account(user: dict = Depends(get_current_user)):
    """Permanently delete account and all associated data."""
    from bson import ObjectId as BsonObjectId
    user_id = user["id"]

    # Delete all cards sent by user
    await db.cards.delete_many({"sender_id": user_id})

    # Leave all pairs — notify partners by clearing their card cache
    pair_ids = user.get("pair_ids", [])
    for pair_id in pair_ids:
        pair = await db.pairs.find_one({"_id": BsonObjectId(pair_id)})
        if pair:
            # Remove user from pair members
            await db.pairs.update_one(
                {"_id": pair["_id"]},
                {"$pull": {"members": user_id}}
            )
            # Remove pair_id from partner's pair_ids
            partner_ids = [m for m in pair.get("members", []) if m != user_id]
            for partner_id in partner_ids:
                await db.users.update_one(
                    {"_id": BsonObjectId(partner_id)},
                    {"$pull": {"pair_ids": BsonObjectId(pair_id)}}
                )
            # Delete received cards for this pair
            await db.cards.delete_many({"pair_id": pair_id})

    # Delete device tokens
    await db.devices.delete_many({"user_id": user_id})

    # Delete password reset tokens
    await db.password_resets.delete_many({"user_id": BsonObjectId(user_id)})

    # Delete the user
    await db.users.delete_one({"_id": BsonObjectId(user_id)})

    logger.info(f"[Account] Deleted account for user {user_id}")
    return {"message": "Hesabınız kalıcı olarak silindi."}


# --- Device / Push Notification Routes ---

@api_router.post("/devices/register")
async def register_device(req: DeviceRegisterRequest, user: dict = Depends(get_current_user)):
    """Register or update a device token for push notifications."""
    await db.devices.update_one(
        {"user_id": user["id"], "device_token": req.device_token},
        {"$set": {
            "user_id": user["id"],
            "device_token": req.device_token,
            "platform": req.platform,
            "updated_at": datetime.now(timezone.utc),
        }},
        upsert=True,
    )
    return {"message": "Device registered"}


async def send_push_notification(user_id: str, payload: dict):
    """Send a silent push notification to all devices of a user.

    Uses Apple Push Notification service (APNs) via HTTP/2.
    Requires environment variables:
      APNS_KEY_ID   — Key ID from Apple Developer
      APNS_TEAM_ID  — Team ID from Apple Developer
      APNS_KEY_PATH — Path to .p8 private key file (local dev)
      APNS_KEY_CONTENT — .p8 key content as env variable (production)
      APNS_BUNDLE_ID — App bundle identifier
      APNS_USE_SANDBOX — "true" for development, "false" for production
    """
    import httpx
    import time as _time

    key_id = os.environ.get("APNS_KEY_ID")
    team_id = os.environ.get("APNS_TEAM_ID")
    key_path = os.environ.get("APNS_KEY_PATH")
    key_content = os.environ.get("APNS_KEY_CONTENT")
    bundle_id = os.environ.get("APNS_BUNDLE_ID", "com.nubittech.surprisecard")
    use_sandbox = os.environ.get("APNS_USE_SANDBOX", "true").lower() == "true"

    if not all([key_id, team_id]) or not (key_path or key_content):
        logger.warning("[Push] APNs not configured — skipping push notification")
        return

    # Build JWT for APNs authentication
    try:
        if key_content:
            key_data = key_content
        else:
            with open(key_path, "r") as f:
                key_data = f.read()

        token_payload = {
            "iss": team_id,
            "iat": int(_time.time()),
        }
        apns_token = jwt.encode(token_payload, key_data, algorithm="ES256", headers={
            "alg": "ES256",
            "kid": key_id,
        })
    except Exception as e:
        logger.error(f"[Push] Failed to create APNs JWT: {e}")
        return

    # Find all device tokens for this user
    devices = await db.devices.find({"user_id": user_id}).to_list(10)
    if not devices:
        logger.info(f"[Push] No devices for user {user_id}")
        return

    host = "https://api.sandbox.push.apple.com" if use_sandbox else "https://api.push.apple.com"

    # APNs payload — silent push with content-available
    apns_payload = {
        "aps": {
            "content-available": 1,
        },
        **payload,
    }

    headers = {
        "authorization": f"bearer {apns_token}",
        "apns-topic": bundle_id,
        "apns-push-type": "background",
        "apns-priority": "5",
    }

    async with httpx.AsyncClient(http2=True) as client_http:
        for device in devices:
            token = device["device_token"]
            url = f"{host}/3/device/{token}"
            try:
                resp = await client_http.post(url, json=apns_payload, headers=headers)
                if resp.status_code == 200:
                    logger.info(f"[Push] Sent to {token[:12]}...")
                elif resp.status_code == 410:
                    # Token is no longer valid — remove it
                    await db.devices.delete_one({"_id": device["_id"]})
                    logger.info(f"[Push] Removed stale token {token[:12]}...")
                else:
                    logger.warning(f"[Push] APNs error {resp.status_code}: {resp.text}")
            except Exception as e:
                logger.error(f"[Push] Failed to send: {e}")


# --- Limit Routes ---
@api_router.get("/limits/status", response_model=LimitResponse)
async def get_limit_status(user: dict = Depends(get_current_user)):
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    daily_count = await db.daily_limits.find_one({"user_id": user["id"], "date": today})
    used = daily_count["count"] if daily_count else 0
    return LimitResponse(used=used, limit=10, remaining=max(0, 10 - used))


# Include router and middleware
app.include_router(api_router)

app.add_middleware(
    CORSMiddleware,
    allow_credentials=True,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup():
    await db.users.create_index("email", unique=True)
    await db.invites.create_index("code")
    await db.invites.create_index("creator_id")
    await db.cards.create_index([("receiver_id", 1), ("created_at", -1)])
    await db.cards.create_index([("sender_id", 1), ("created_at", -1)])
    await db.daily_limits.create_index([("user_id", 1), ("date", 1)], unique=True)
    await db.devices.create_index([("user_id", 1), ("device_token", 1)], unique=True)

    admin_email = os.environ.get("ADMIN_EMAIL", "admin@example.com")
    admin_password = os.environ.get("ADMIN_PASSWORD", "admin123")
    existing = await db.users.find_one({"email": admin_email})
    if not existing:
        await db.users.insert_one({
            "email": admin_email,
            "password_hash": hash_password(admin_password),
            "name": "Admin",
            "role": "admin",
            "pair_ids": [],
            "created_at": datetime.now(timezone.utc)
        })
        logger.info(f"Admin user seeded: {admin_email}")
