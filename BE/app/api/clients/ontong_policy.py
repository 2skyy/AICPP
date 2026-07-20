import os
from typing import Any

import requests


class OntongPolicyClient:
    """온통청년 청년정책 Open API 호출만 담당하는 클라이언트."""

    DEFAULT_BASE_URL = "https://www.youthcenter.go.kr/go/ythip/getPlcy"

    def __init__(
        self,
        api_key: str | None = None,
        base_url: str | None = None,
        timeout: int = 10,
    ):
        self.api_key = api_key or os.getenv("ONTONG_API_KEY")
        self.base_url = base_url or self.DEFAULT_BASE_URL
        self.timeout = timeout

    def get_policies(self, **query_params: Any) -> dict[str, Any]:
        if not self.api_key:
            raise RuntimeError("ONTONG_API_KEY가 설정되지 않았습니다.")

        params = {
            "apiKeyNm": self.api_key,
            **{
                key: value
                for key, value in query_params.items()
                if value is not None and value != ""
            },
        }

        # requests는 기본적으로 HTTP(S)_PROXY 환경변수를 사용한다. 잘못된
        # 로컬 프록시(:8080)가 온통청년 요청을 가로채지 않도록 직접 연결한다.
        with requests.Session() as session:
            session.trust_env = False
            response = session.get(
                self.base_url,
                params=params,
                timeout=self.timeout,
                allow_redirects=False,
            )
            if response.is_redirect:
                location = response.headers.get("Location", "알 수 없음")
                raise requests.RequestException(
                    "온통청년 API가 요청을 거부하고 리다이렉트했습니다. "
                    f"API 키의 발급·승인 상태를 확인하세요. (Location: {location})"
                )
            response.raise_for_status()
            return response.json()


__all__ = ["OntongPolicyClient"]