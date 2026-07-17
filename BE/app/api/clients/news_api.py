import os
from typing import Any

import requests


class NewsApiClient:
    """newsapi.org 호출만 담당하는 클라이언트."""

    DEFAULT_BASE_URL = "https://newsapi.org/v2/everything"

    def __init__(
        self,
        api_key: str | None = None,
        base_url: str | None = None,
        timeout: int = 10,
    ):
        self.api_key = api_key or os.getenv("NEWSAPI_KEY")
        self.base_url = base_url or self.DEFAULT_BASE_URL
        self.timeout = timeout

    def search(self, query: str, page_size: int = 20) -> list[dict[str, Any]]:
        if not self.api_key:
            raise RuntimeError("NEWSAPI_KEY가 설정되지 않았습니다.")

        with requests.Session() as session:
            session.trust_env = False
            response = session.get(
                self.base_url,
                params={
                    "q": query,
                    "language": "ko",
                    "sortBy": "publishedAt",
                    "pageSize": page_size,
                    "apiKey": self.api_key,
                },
                timeout=self.timeout,
            )
            response.raise_for_status()
            data = response.json()
            if data.get("status") != "ok":
                raise requests.RequestException(
                    f"newsapi 응답 오류: {data.get('message', '알 수 없는 오류')}"
                )
            return data.get("articles", [])


__all__ = ["NewsApiClient"]
