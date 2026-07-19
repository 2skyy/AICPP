import json
import re
from typing import Any

from anthropic import Anthropic

from app.api.clients.news_api import NewsApiClient
from app.services.markdown_utils import strip_markdown

DEFAULT_MODEL = "claude-sonnet-5"
CANDIDATE_COUNT = 20
RECOMMENDATION_COUNT = 5

_JSON_ARRAY_RE = re.compile(r"\[.*\]", re.DOTALL)


class NewsRecommendationService:
    """관심사로 뉴스 후보를 찾고, Claude로 그중 가장 관련 있는 것들을 골라준다."""

    def __init__(
        self,
        news_client: NewsApiClient,
        client: Anthropic | None = None,
        model: str = DEFAULT_MODEL,
    ):
        self.news_client = news_client
        self.client = client or Anthropic()
        self.model = model

    def recommend(
        self, interests: list[str], count: int = RECOMMENDATION_COUNT
    ) -> list[dict[str, Any]]:
        interests = [interest for interest in interests if interest]
        if not interests or count <= 0:
            return []
        count = min(count, CANDIDATE_COUNT)

        query = " OR ".join(f'"{interest}"' for interest in interests)
        articles = self.news_client.search(query, page_size=CANDIDATE_COUNT)
        if not articles:
            return []

        picks = self._pick_relevant(interests, articles, count)
        recommendations = []
        for pick in picks:
            index = pick.get("index")
            if not isinstance(index, int) or not 0 <= index < len(articles):
                continue
            article = articles[index]
            recommendations.append(
                {
                    "title": article.get("title") or "",
                    "url": article.get("url") or "",
                    "source": (article.get("source") or {}).get("name") or "",
                    "publishedAt": article.get("publishedAt"),
                    "reason": strip_markdown(pick.get("reason") or ""),
                }
            )
        return recommendations

    def _pick_relevant(
        self, interests: list[str], articles: list[dict[str, Any]], count: int
    ) -> list[dict[str, Any]]:
        listing = "\n".join(
            f"{i}. {article.get('title') or '(제목 없음)'} "
            f"— {(article.get('source') or {}).get('name') or '출처 미상'}\n"
            f"   {article.get('description') or ''}"
            for i, article in enumerate(articles)
        )
        system_prompt = (
            "너는 청년 대상 뉴스 큐레이터야. 아래 [관심사]를 가진 사용자에게 "
            f"[뉴스 후보] 중 가장 관련 있고 흥미로울 기사를 정확히 {count}개 골라줘 "
            f"(후보가 {count}개보다 적으면 있는 만큼만).\n"
            "각 기사를 고른 이유를 한국어 한 문장으로 붙여. 마크다운 문법(#, *, ** 등)은 "
            "쓰지 말고 일반 텍스트로만 답해.\n"
            "번호(index)는 후보 목록의 앞자리 숫자를 그대로 사용해.\n"
            '반드시 다음 JSON 배열 형식으로만 답해: [{"index": 0, "reason": "..."}]\n'
            "다른 설명 문장은 붙이지 마.\n\n"
            f"[관심사]\n{', '.join(interests)}\n\n"
            f"[뉴스 후보]\n{listing}"
        )
        message = self.client.messages.create(
            model=self.model,
            max_tokens=3000,
            system=system_prompt,
            # JSON 배열만 골라내는 단순 작업이라 확장 사고(thinking)가 필요 없다.
            thinking={"type": "disabled"},
            messages=[{"role": "user", "content": "관련 기사를 골라줘."}],
        )
        text = "".join(
            block.text for block in message.content if getattr(block, "type", None) == "text"
        )
        return self._parse_picks(text)

    @staticmethod
    def _parse_picks(text: str) -> list[dict[str, Any]]:
        match = _JSON_ARRAY_RE.search(text)
        if not match:
            return []
        try:
            parsed = json.loads(match.group(0))
        except json.JSONDecodeError:
            return []
        if not isinstance(parsed, list):
            return []
        return [item for item in parsed if isinstance(item, dict)]


__all__ = ["NewsRecommendationService"]
