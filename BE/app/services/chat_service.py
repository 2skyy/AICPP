from datetime import date, datetime
from typing import Any

from anthropic import Anthropic

from app.services.keyword_extractor import extract_topic_keyword
from app.services.ontong_policy_service import OntongPolicyService

DEFAULT_MODEL = "claude-sonnet-5"


def _parse_ymd(raw: str) -> date | None:
    raw = raw.strip()
    if len(raw) != 8 or not raw.isdigit():
        return None
    try:
        return datetime.strptime(raw, "%Y%m%d").date()
    except ValueError:
        return None


def _is_open(item: dict[str, Any], today: date) -> bool:
    raw = item.get("aplyYmd")
    if not raw or "~" not in raw:
        return True  # 상시 모집으로 취급
    start_raw, end_raw = raw.split("~", 1)
    start, end = _parse_ymd(start_raw), _parse_ymd(end_raw)
    if end is not None and end < today:
        return False
    if start is not None and start > today:
        return False
    return True


def _extract_items(raw: dict[str, Any]) -> list[dict[str, Any]]:
    result = raw.get("result")
    if isinstance(result, dict):
        items = result.get("youthPolicyList")
        if isinstance(items, list):
            return [item for item in items if isinstance(item, dict)]
    return []


class ChatService:
    """사용자 질문 + 프로필을 받아 관련 정책을 찾고, Claude로 근거 기반 답변을 생성한다."""

    def __init__(
        self,
        policy_service: OntongPolicyService,
        client: Anthropic | None = None,
        model: str = DEFAULT_MODEL,
    ):
        self.policy_service = policy_service
        self.client = client or Anthropic()
        self.model = model

    def ask(self, question: str, profile: dict[str, Any]) -> dict[str, Any]:
        items = self._find_relevant_policies(question, profile)
        answer = self._generate_answer(question, profile, items)
        policies = [
            {"name": item.get("plcyNm", ""), "period": item.get("aplyYmd")}
            for item in items
        ]
        return {"answer": answer, "policies": policies}

    def _find_relevant_policies(
        self, question: str, profile: dict[str, Any]
    ) -> list[dict[str, Any]]:
        keyword = extract_topic_keyword(question)
        region = profile.get("region")
        if keyword:
            raw = self.policy_service.search(topic=keyword, size=10)
        elif region:
            raw = self.policy_service.search(name=region, size=10)
        else:
            return []
        today = date.today()
        return [item for item in _extract_items(raw) if _is_open(item, today)]

    def _generate_answer(
        self, question: str, profile: dict[str, Any], items: list[dict[str, Any]]
    ) -> str:
        system_prompt = self._build_system_prompt(profile, items)
        message = self.client.messages.create(
            model=self.model,
            max_tokens=800,
            system=system_prompt,
            messages=[{"role": "user", "content": question}],
        )
        return "".join(
            block.text for block in message.content if getattr(block, "type", None) == "text"
        )

    @staticmethod
    def _build_system_prompt(profile: dict[str, Any], items: list[dict[str, Any]]) -> str:
        age = profile.get("age")
        lines = [
            "너는 청년 정책 안내 어시스턴트야. 아래 [정책 목록]에 있는 정책만 근거로 답변해.",
            "목록에 없는 내용은 추측하지 말고, 조건에 맞는 정책이 없으면 없다고 솔직하게 말해.",
            "답변은 한국어로, 친근하고 간결하게 작성해.",
            "",
            "[사용자 정보]",
            f"- 지역: {profile.get('region') or '미상'}",
            f"- 재학상태: {profile.get('enrollment_status') or '미상'}",
            f"- 나이: {f'{age}세' if age else '미상'}",
            "",
            "[정책 목록]",
        ]
        if not items:
            lines.append("(조건에 맞는 정책을 찾지 못했습니다)")
        else:
            for i, item in enumerate(items, start=1):
                lines.append(
                    f"{i}. {item.get('plcyNm', '이름 미상')} "
                    f"(지원기관: {item.get('sprvsnInstCdNm', '미상')}, "
                    f"신청기간: {item.get('aplyYmd', '상시')})"
                )
                if item.get("plcyExplnCn"):
                    lines.append(f"   설명: {item['plcyExplnCn']}")
                if item.get("plcySprtCn"):
                    lines.append(f"   지원내용: {item['plcySprtCn']}")
                if item.get("plcyAplyMthdCn"):
                    lines.append(f"   신청방법: {item['plcyAplyMthdCn']}")
        return "\n".join(lines)


__all__ = ["ChatService"]
