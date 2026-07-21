import requests
from fastapi import APIRouter, Depends, HTTPException, Response

from app.core.auth import CurrentUser, get_bearer_token, get_current_user
from app.core.config import Settings, get_settings
from app.schemas.auth import AuthMeResponse


router = APIRouter(prefix="/api/v1/auth", tags=["v1-auth"])


@router.get("/me", response_model=AuthMeResponse)
def me(user: CurrentUser = Depends(get_current_user)) -> AuthMeResponse:
    return AuthMeResponse(id=user.id, email=user.email, user_metadata=user.user_metadata or {})


@router.delete("/session", status_code=204)
def logout(
    token: str = Depends(get_bearer_token),
    settings: Settings = Depends(get_settings),
) -> Response:
    if not settings.supabase_url or not settings.supabase_anon_key:
        raise HTTPException(status_code=503, detail="Supabase Auth is not configured")
    try:
        response = requests.post(
            f"{settings.supabase_url.rstrip('/')}/auth/v1/logout",
            headers={"apikey": settings.supabase_anon_key, "Authorization": f"Bearer {token}"},
            timeout=10,
        )
    except requests.RequestException as exc:
        raise HTTPException(status_code=502, detail="Supabase Auth is unavailable") from exc
    if response.status_code not in (200, 204):
        raise HTTPException(status_code=401, detail="Unable to revoke session")
    return Response(status_code=204)
