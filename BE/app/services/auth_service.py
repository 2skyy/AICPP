from app.api.clients.supabase_auth import SupabaseAuthClient, SupabaseAuthError


class AuthService:
    """회원가입/로그인을 Supabase Auth(GoTrue)에 위임하는 서비스.

    이 프로젝트는 이메일 확인을 요구하도록 설정돼 있어서, 가입 직후 바로
    로그인 세션을 못 받는다. 데모에서 실제 메일함을 거치지 않아도 되도록,
    가입 → 즉시 관리자 API로 확인 처리 → 로그인 순서로 처리해 최종적으로는
    항상 세션을 돌려준다.
    """

    def __init__(self, client: SupabaseAuthClient):
        self.client = client

    def sign_up(self, email: str, password: str) -> dict:
        result = self.client.sign_up(email, password)
        user_id = result.get("id") or (result.get("user") or {}).get("id")
        if not user_id:
            raise SupabaseAuthError("회원가입에 실패했습니다.")
        self.client.admin_confirm_email(user_id)
        return self.client.sign_in(email, password)

    def sign_in(self, email: str, password: str) -> dict:
        return self.client.sign_in(email, password)


__all__ = ["AuthService"]
