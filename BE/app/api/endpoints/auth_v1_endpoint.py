import requests
from fastapi import APIRouter, Depends, HTTPException, Response

from app.api.clients.supabase_auth import SupabaseAuthClient, SupabaseAuthError
from app.core.auth import CurrentUser, get_bearer_token, get_current_user
from app.core.config import Settings, get_settings
from app.schemas.auth import AuthCredentials, AuthMeResponse, AuthSessionResponse
from app.services.auth_service import AuthService


router = APIRouter(prefix="/api/v1/auth", tags=["v1-auth"])


def get_auth_service(settings: Settings = Depends(get_settings)) -> AuthService:
    return AuthService(SupabaseAuthClient(settings))


def _to_response(session: dict) -> AuthSessionResponse:
    user = session.get("user") or {}
    return AuthSessionResponse(
        access_token=session.get("access_token") or "",
        refresh_token=session.get("refresh_token") or "",
        user_id=user.get("id") or "",
        email=user.get("email") or "",
    )


@router.post("/signup", response_model=AuthSessionResponse)
def signup(body: AuthCredentials, service: AuthService = Depends(get_auth_service)):
    try:
        session = service.sign_up(body.email, body.password)
    except SupabaseAuthError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc
    return _to_response(session)


@router.post("/login", response_model=AuthSessionResponse)
def login(body: AuthCredentials, service: AuthService = Depends(get_auth_service)):
    try:
        session = service.sign_in(body.email, body.password)
    except SupabaseAuthError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc
    return _to_response(session)


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
