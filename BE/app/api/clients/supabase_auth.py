import requests

from app.core.config import Settings


class SupabaseAuthError(Exception):
    """Supabase Auth(GoTrue) API가 에러를 반환했을 때 던진다."""

    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


class SupabaseAuthClient:
    """Supabase Auth(GoTrue) REST API를 감싸는 얇은 클라이언트.

    비밀번호 해싱/세션 발급/토큰 갱신 같은 걸 우리가 새로 구현하지 않고
    Supabase에 그대로 위임한다.
    """

    def __init__(self, settings: Settings):
        self.base_url = (settings.supabase_url or "").rstrip("/")
        self.api_key = settings.supabase_anon_key
        self.secret_key = settings.supabase_secret_key

    def _headers(self) -> dict[str, str]:
        return {"apikey": self.api_key or "", "Content-Type": "application/json"}

    def _admin_headers(self) -> dict[str, str]:
        return {
            "apikey": self.secret_key or "",
            "Authorization": f"Bearer {self.secret_key or ''}",
            "Content-Type": "application/json",
        }

    def sign_up(self, email: str, password: str) -> dict:
        response = requests.post(
            f"{self.base_url}/auth/v1/signup",
            headers=self._headers(),
            json={"email": email, "password": password},
            timeout=10,
        )
        return self._parse(response)

    def sign_in(self, email: str, password: str) -> dict:
        response = requests.post(
            f"{self.base_url}/auth/v1/token?grant_type=password",
            headers=self._headers(),
            json={"email": email, "password": password},
            timeout=10,
        )
        return self._parse(response)

    def admin_confirm_email(self, user_id: str) -> dict:
        """이 프로젝트는 이메일 확인을 요구하므로, 데모에서 실제 메일 발송에
        기대지 않도록 가입 직후 서버 쪽에서 즉시 확인 처리한다.
        """
        response = requests.put(
            f"{self.base_url}/auth/v1/admin/users/{user_id}",
            headers=self._admin_headers(),
            json={"email_confirm": True},
            timeout=10,
        )
        return self._parse(response)

    @staticmethod
    def _parse(response: requests.Response) -> dict:
        try:
            data = response.json()
        except ValueError:
            data = {}
        if response.status_code >= 400:
            message = (
                data.get("error_description")
                or data.get("msg")
                or data.get("error")
                or "인증 요청이 실패했습니다."
            )
            raise SupabaseAuthError(message, response.status_code)
        return data


__all__ = ["SupabaseAuthClient", "SupabaseAuthError"]
