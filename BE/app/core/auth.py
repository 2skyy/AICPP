from dataclasses import dataclass
import uuid

import requests
from fastapi import Depends, Header, HTTPException, status

from app.core.config import Settings, get_settings


@dataclass(frozen=True)
class CurrentUser:
    id: uuid.UUID
    email: str | None = None
    user_metadata: dict | None = None


def _access_token(authorization: str | None) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Bearer access token is required")
    return authorization.removeprefix("Bearer ").strip()


def get_current_user(
    authorization: str | None = Header(default=None),
    settings: Settings = Depends(get_settings),
) -> CurrentUser:
    token = _access_token(authorization)
    if not settings.supabase_url or not settings.supabase_anon_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="SUPABASE_URL and SUPABASE_ANON_KEY are not configured",
        )
    try:
        response = requests.get(
            f"{settings.supabase_url.rstrip('/')}/auth/v1/user",
            headers={"apikey": settings.supabase_anon_key, "Authorization": f"Bearer {token}"},
            timeout=10,
        )
    except requests.RequestException as exc:
        raise HTTPException(status_code=502, detail="Supabase Auth is unavailable") from exc
    if response.status_code != 200:
        raise HTTPException(status_code=401, detail="Invalid or expired access token")
    payload = response.json()
    try:
        user_id = uuid.UUID(payload["id"])
    except (KeyError, TypeError, ValueError) as exc:
        raise HTTPException(status_code=401, detail="Invalid Supabase user payload") from exc
    return CurrentUser(user_id, payload.get("email"), payload.get("user_metadata") or {})


def get_bearer_token(authorization: str | None = Header(default=None)) -> str:
    return _access_token(authorization)
