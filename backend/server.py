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
from pymongo import ReturnDocument
from pymongo.errors import DuplicateKeyError
import asyncio
import collections

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
    is_premium: bool = False
    premium_until: Optional[str] = None  # ISO-8601 UTC, None = never / lifetime handled via flag

class TokenResponse(BaseModel):
    user: UserResponse
    access_token: str

class InviteResponse(BaseModel):
    invite_code: str

class AcceptInviteRequest(BaseModel):
    invite_code: str
    partner_nickname: Optional[str] = None
    relationship: Optional[str] = None

class UpdatePairLabelRequest(BaseModel):
    pair_id: str
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
    textBg: Optional[str] = None

class CreateCardRequest(BaseModel):
    pair_id: str  # which friend to send to
    background: str
    elements: List[CardElement]
    music_url: Optional[str] = None
    music_title: Optional[str] = None
    music_artist: Optional[str] = None
    music_artwork: Optional[str] = None

class CardResponse(BaseModel):
    id: str
    pair_id: str
    sender_id: str
    sender_name: str
    background: str
    elements: List[dict]
    created_at: str
    music_url: Optional[str] = None
    music_title: Optional[str] = None
    music_artist: Optional[str] = None
    music_artwork: Optional[str] = None

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

def is_user_premium(user: dict) -> bool:
    """Source of truth for premium status on the backend.
    Lifetime entitlements set is_premium=True (no expiry).
    Subscription-style entitlements set premium_until to a future UTC datetime.
    """
    if user.get("is_premium") is True:
        return True
    pu = user.get("premium_until")
    if isinstance(pu, datetime):
        if pu.tzinfo is None:
            pu = pu.replace(tzinfo=timezone.utc)
        return pu > datetime.now(timezone.utc)
    return False

def user_premium_until_iso(user: dict) -> Optional[str]:
    pu = user.get("premium_until")
    if isinstance(pu, datetime):
        if pu.tzinfo is None:
            pu = pu.replace(tzinfo=timezone.utc)
        return pu.isoformat()
    return None

def build_user_response(user: dict, user_id: str, email: str, name: str, pair_ids: List[str]) -> UserResponse:
    return UserResponse(
        id=user_id,
        email=email,
        name=name,
        pair_ids=pair_ids,
        is_premium=is_user_premium(user),
        premium_until=user_premium_until_iso(user),
    )

# ---------------------------------------------------------------------------
# Spam / rate-limit helpers
# ---------------------------------------------------------------------------

# In-memory burst limiter: (key, window_minute) → hit count
# Lightweight; resets on server restart but that's fine for burst protection.
_burst_counters: dict = collections.defaultdict(int)
_burst_lock = asyncio.Lock()

async def check_burst(key: str, max_hits: int = 5, window_seconds: int = 60):
    """Raise 429 if `key` exceeds `max_hits` in the current time window.
    Window is rounded to `window_seconds`-wide UTC buckets.
    """
    bucket = int(datetime.now(timezone.utc).timestamp() // window_seconds)
    full_key = f"{key}:{bucket}"
    async with _burst_lock:
        _burst_counters[full_key] += 1
        count = _burst_counters[full_key]
        # Prune stale buckets roughly every 1000 hits to avoid unbounded growth
        if len(_burst_counters) > 1000:
            now_bucket = bucket
            stale = [k for k in list(_burst_counters) if int(k.rsplit(":", 1)[-1]) < now_bucket - 2]
            for k in stale:
                _burst_counters.pop(k, None)
    if count > max_hits:
        raise HTTPException(
            status_code=429,
            detail="Too many requests. Please slow down and try again."
        )

async def check_login_attempts(ip: str, email: str):
    """MongoDB-backed brute-force guard for /auth/login.
    Blocks after 10 failed attempts per IP per 15-minute window.
    """
    window_start = datetime.now(timezone.utc) - timedelta(minutes=15)
    count = await db.login_attempts.count_documents({
        "$or": [{"ip": ip}, {"email": email.lower()}],
        "ts": {"$gte": window_start},
        "success": False,
    })
    if count >= 10:
        raise HTTPException(
            status_code=429,
            detail="Too many failed login attempts. Please try again later."
        )

async def record_login_attempt(ip: str, email: str, success: bool):
    await db.login_attempts.insert_one({
        "ip": ip, "email": email.lower(),
        "success": success, "ts": datetime.now(timezone.utc)
    })

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
    fresh = await db.users.find_one({"_id": result.inserted_id}) or user_doc

    return TokenResponse(
        user=build_user_response(fresh, user_id, email, req.name, []),
        access_token=token
    )

@api_router.post("/auth/login", response_model=TokenResponse)
async def login(req: LoginRequest, request: Request):
    email = req.email.lower()
    ip = request.client.host if request.client else "unknown"

    # Brute-force guard: block after 10 failed attempts per IP/email in 15 min
    await check_login_attempts(ip, email)

    user = await db.users.find_one({"email": email})
    if not user or not verify_password(req.password, user.get("password_hash") or ""):
        await record_login_attempt(ip, email, success=False)
        raise HTTPException(status_code=401, detail="Geçersiz e-posta veya şifre")

    await record_login_attempt(ip, email, success=True)
    user_id = str(user["_id"])
    # Migrate old pair_id to pair_ids
    if "pair_ids" not in user:
        old = user.get("pair_id")
        pair_ids = [str(old)] if old else []
    else:
        pair_ids = [str(p) for p in user.get("pair_ids", []) if p]

    token = create_access_token(user_id, email)
    return TokenResponse(
        user=build_user_response(user, user_id, email, user.get("name", ""), pair_ids),
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
        user=build_user_response(user, user_id, user_email, user.get("name", ""), pair_ids),
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
    return build_user_response(
        user,
        user["id"],
        user["email"],
        user.get("name", ""),
        user.get("pair_ids", []),
    )


class SyncEntitlementRequest(BaseModel):
    is_active: bool
    # ISO-8601 UTC expiration from RevenueCat (null for lifetime or inactive)
    expiration_date: Optional[str] = None
    product_id: Optional[str] = None

@api_router.post("/users/me/sync-entitlement", response_model=UserResponse)
async def sync_entitlement(
    req: SyncEntitlementRequest,
    user: dict = Depends(get_current_user),
):
    """Client reports its current RevenueCat entitlement state.
    Backend stores is_premium + premium_until as the authoritative source for
    server-side gates (pair limit, sticker/bg reject, daily cap).
    """
    update: dict = {}
    if req.is_active:
        # Parse expiration if provided; lifetime entitlements come with None.
        expires_at: Optional[datetime] = None
        if req.expiration_date:
            try:
                raw = req.expiration_date.replace("Z", "+00:00")
                expires_at = datetime.fromisoformat(raw)
                if expires_at.tzinfo is None:
                    expires_at = expires_at.replace(tzinfo=timezone.utc)
            except Exception:
                expires_at = None

        update["is_premium"] = True
        update["premium_until"] = expires_at  # may be None for lifetime
        update["premium_product_id"] = req.product_id
        update["premium_synced_at"] = datetime.now(timezone.utc)
    else:
        # Client reports no active entitlement. Keep premium_until in place so
        # a client with a stale/offline RevenueCat cache can't accidentally
        # downgrade an active subscription — server re-evaluates via is_user_premium.
        update["is_premium"] = False
        update["premium_synced_at"] = datetime.now(timezone.utc)

    await db.users.update_one({"_id": ObjectId(user["id"])}, {"$set": update})
    fresh = await db.users.find_one({"_id": ObjectId(user["id"])}) or user
    return build_user_response(
        fresh,
        user["id"],
        user["email"],
        fresh.get("name", user.get("name", "")),
        [str(p) for p in fresh.get("pair_ids", []) if p],
    )


# --- Pairing Routes ---
FREE_PAIR_LIMIT = 2
PREMIUM_PAIR_LIMIT = 10

def pair_limit_for(user: dict) -> int:
    return PREMIUM_PAIR_LIMIT if is_user_premium(user) else FREE_PAIR_LIMIT

@api_router.post("/pairs/create-invite", response_model=InviteResponse)
async def create_invite(user: dict = Depends(get_current_user)):
    existing = await db.invites.find_one({"creator_id": user["id"], "status": "pending"})
    if existing:
        return InviteResponse(invite_code=existing["code"])

    # Gate — refuse to generate a new invite code if the user is already at
    # their pair cap. The accept_invite endpoint enforces the same limit, but
    # blocking here avoids handing out codes that can never be redeemed.
    pair_count = len([p for p in user.get("pair_ids", []) if p])
    if pair_count >= pair_limit_for(user):
        raise HTTPException(
            status_code=402,
            detail="You've reached your friend limit. Upgrade to Premium to add more."
        )

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

    # Pair-count guard: both sides must have room under their tier cap.
    acceptor_count = len([p for p in user.get("pair_ids", []) if p])
    if acceptor_count >= pair_limit_for(user):
        raise HTTPException(
            status_code=402,
            detail="You've reached your friend limit. Upgrade to Premium to add more."
        )
    creator = await db.users.find_one({"_id": ObjectId(creator_id)})
    if creator:
        creator_count = len([p for p in creator.get("pair_ids", []) if p])
        if creator_count >= pair_limit_for(creator):
            raise HTTPException(
                status_code=402,
                detail="The person who sent this code has hit their friend limit."
            )

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

@api_router.post("/pairs/update-label")
async def update_pair_label(req: UpdatePairLabelRequest, user: dict = Depends(get_current_user)):
    """
    Lets the current user set (or update) how they label a specific pair:
      • partner_nickname — what they call their partner (shows on widget)
      • relationship     — e.g. "My Love", "My Bestie"

    Only the *caller's* nickname slot is updated. If caller is user_1 of the
    pair, we write nickname_1. If caller is user_2, we write nickname_2.
    This keeps each participant's personal labels independent.
    """
    if req.pair_id not in user.get("pair_ids", []):
        raise HTTPException(status_code=400, detail="Bu eşleşme bulunamadı")

    try:
        pair = await db.pairs.find_one({"_id": ObjectId(req.pair_id)})
    except Exception:
        pair = None
    if not pair:
        raise HTTPException(status_code=404, detail="Eşleşme bulunamadı")

    # Determine which nickname slot to update based on the caller's identity.
    if pair.get("user_1") == user["id"]:
        nickname_field = "nickname_1"
    elif pair.get("user_2") == user["id"]:
        nickname_field = "nickname_2"
    else:
        raise HTTPException(status_code=403, detail="Bu eşleşmede yetkin yok")

    update_set: dict = {}
    # Trim empty strings → None so we don't persist whitespace nicknames.
    nickname = (req.partner_nickname or "").strip() or None
    update_set[nickname_field] = nickname
    # Relationship is a shared field on the pair (both users share one label).
    if req.relationship is not None:
        rel = req.relationship.strip() or None
        update_set["relationship"] = rel

    await db.pairs.update_one(
        {"_id": pair["_id"]},
        {"$set": update_set}
    )
    return {"message": "Güncellendi"}

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
# Premium-content gates for card payload
def _is_premium_background(bg: str) -> bool:
    """PNG backgrounds are stored with an 'img:' prefix (see BG_IMAGES in iOS).
    Solid-color backgrounds are hex strings and free for everyone.
    """
    return isinstance(bg, str) and bg.startswith("img:")

def _is_premium_sticker_asset(name: str) -> bool:
    """Essentials stickers use the 'stk_temel_' prefix and are free. Every
    other 'stk_' asset belongs to a premium category.
    Emojis and user text/images don't go through this check.
    """
    if not isinstance(name, str):
        return False
    if name.startswith("stk_temel_"):
        return False
    return name.startswith("stk_")

@api_router.post("/cards/create", response_model=CardResponse)
async def create_card(req: CreateCardRequest, user: dict = Depends(get_current_user)):
    if req.pair_id not in user.get("pair_ids", []):
        raise HTTPException(status_code=400, detail="Bu eşleşme bulunamadı")

    is_premium = is_user_premium(user)

    # Premium content gate: PNG bg + premium stickers require Premium.
    if not is_premium and _is_premium_background(req.background):
        raise HTTPException(
            status_code=402,
            detail="Premium backgrounds are unlocked with Premium."
        )
    if not is_premium:
        for el in req.elements:
            if el.type == "sticker" and _is_premium_sticker_asset(el.content):
                raise HTTPException(
                    status_code=402,
                    detail="Premium stickers are unlocked with Premium."
                )

    # Burst guard: max 3 send attempts per user per 30 seconds regardless of
    # daily limits. Prevents rapid-fire spam before the daily counter persists.
    await check_burst(f"card_send:{user['id']}", max_hits=3, window_seconds=30)

    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    limit = 10 if is_premium else 1
    daily_key = {"user_id": user["id"], "pair_id": req.pair_id, "date": today}

    # Atomic increment + limit check in one round-trip (race-safe).
    # We increment first; if the resulting count exceeds the limit we reject
    # WITHOUT creating the card. The counter may end slightly above `limit` if
    # concurrent requests slip through simultaneously, but that's bounded by
    # the burst guard above (max 3 concurrent) and is acceptable.
    try:
        doc = await db.daily_limits.find_one_and_update(
            daily_key,
            {"$inc": {"count": 1}},
            upsert=True,
            return_document=ReturnDocument.AFTER,
        )
    except DuplicateKeyError:
        # Two simultaneous upserts on the same key; retry as a plain update.
        doc = await db.daily_limits.find_one_and_update(
            daily_key,
            {"$inc": {"count": 1}},
            return_document=ReturnDocument.AFTER,
        )

    used = doc["count"] if doc else 1
    if used > limit:
        # Roll counter back so we don't inflate it on rejected attempts.
        await db.daily_limits.update_one(daily_key, {"$inc": {"count": -1}})
        if is_premium:
            raise HTTPException(
                status_code=429,
                detail="Daily card limit reached for this friend. Try again tomorrow."
            )
        raise HTTPException(
            status_code=402,
            detail="You've used today's free card for this friend. Upgrade to Premium for more."
        )

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
        "created_at": datetime.now(timezone.utc),
        "music_url":    req.music_url,
        "music_title":  req.music_title,
        "music_artist": req.music_artist,
        "music_artwork": req.music_artwork,
    }
    result = await db.cards.insert_one(card_doc)

    # Counter already incremented atomically above. No second write needed.

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
        created_at=card_doc["created_at"].isoformat(),
        music_url=card_doc.get("music_url"),
        music_title=card_doc.get("music_title"),
        music_artist=card_doc.get("music_artist"),
        music_artwork=card_doc.get("music_artwork"),
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
            "created_at": card["created_at"].isoformat() if isinstance(card["created_at"], datetime) else card["created_at"],
            "music_url":    card.get("music_url"),
            "music_title":  card.get("music_title"),
            "music_artist": card.get("music_artist"),
            "music_artwork": card.get("music_artwork"),
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
async def get_limit_status(user: dict = Depends(get_current_user), pair_id: Optional[str] = None):
    """Aggregate daily card usage.

    - If `pair_id` is provided, returns usage for that specific pair
      (the limit the sender actually hits when sending to that friend).
    - Otherwise returns the sum across all the user's pairs, with the
      theoretical ceiling being per-pair-limit × number-of-pairs.
    """
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    per_pair_limit = 10 if is_user_premium(user) else 1
    pair_ids = [p for p in user.get("pair_ids", []) if p]

    if pair_id:
        if pair_id not in pair_ids:
            raise HTTPException(status_code=400, detail="Bu eşleşme bulunamadı")
        doc = await db.daily_limits.find_one(
            {"user_id": user["id"], "pair_id": pair_id, "date": today}
        )
        used = doc["count"] if doc else 0
        limit = per_pair_limit
    else:
        # Sum usage across every pair for the day so the user sees global
        # remaining. Includes legacy docs that pre-date the pair_id split.
        cursor = db.daily_limits.find({"user_id": user["id"], "date": today})
        used = 0
        async for doc in cursor:
            used += int(doc.get("count", 0) or 0)
        limit = per_pair_limit * max(1, len(pair_ids))
    return LimitResponse(used=used, limit=limit, remaining=max(0, limit - used))


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
    # Daily limits switched from per-user-per-day to per-user-per-pair-per-day
    # when free-tier gating shipped. Drop the legacy unique index if present
    # so the new composite index can be built without conflicts.
    try:
        await db.daily_limits.drop_index("user_id_1_date_1")
    except Exception:
        pass
    await db.daily_limits.create_index(
        [("user_id", 1), ("pair_id", 1), ("date", 1)], unique=True
    )
    await db.devices.create_index([("user_id", 1), ("device_token", 1)], unique=True)
    # Login attempt records auto-expire after 1 hour (TTL = 3600 seconds)
    await db.login_attempts.create_index("ts", expireAfterSeconds=3600)
    await db.login_attempts.create_index([("ip", 1), ("ts", 1)])
    await db.login_attempts.create_index([("email", 1), ("ts", 1)])

    # ── One-time migration: reset sandbox/test premium flags ──────────────
    # Premium gating shipped in v1.4. Before this, some users got is_premium=True
    # from TestFlight RevenueCat sandbox purchases. Reset everyone to free tier;
    # the app will re-sync via /users/me/sync-entitlement on next launch so
    # genuine paying users get their status back within seconds.
    migration_id = "reset_sandbox_premium_v1"
    already_run = await db.migrations.find_one({"id": migration_id})
    if not already_run:
        result = await db.users.update_many(
            {"is_premium": True},
            {"$set": {"is_premium": False, "premium_until": None, "premium_product_id": None}}
        )
        # Also wipe daily_limits so counters start fresh under the new schema.
        await db.daily_limits.delete_many({})
        await db.migrations.insert_one({
            "id": migration_id,
            "ran_at": datetime.now(timezone.utc),
            "users_reset": result.modified_count,
        })
        logger.info(f"[Migration] {migration_id}: reset {result.modified_count} users to free tier")

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
