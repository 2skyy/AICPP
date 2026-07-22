from datetime import date, datetime
from typing import Any

from anthropic import Anthropic

from app.services.keyword_extractor import extract_topic_keyword
from app.services.markdown_utils import strip_markdown
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
            raw = self.policy_service.search(region=region, size=10)
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
            max_tokens=1500,
            system=system_prompt,
            # 정책 목록에서 근거를 찾아 답하는 단순 조회형 작업이라 확장 사고(thinking)가
            # 필요 없다. 꺼두면 응답이 눈에 띄게 빨라진다(측정상 약 25~30% 단축).
            thinking={"type": "disabled"},
            messages=[{"role": "user", "content": question}],
        )
        text = "".join(
            block.text for block in message.content if getattr(block, "type", None) == "text"
        )
        return strip_markdown(text)

    @staticmethod
    def _build_system_prompt(profile: dict[str, Any], items: list[dict[str, Any]]) -> str:
        age = profile.get("age")
        gpa = profile.get("gpa")
        income_percent = profile.get("income_percent")
        interested_regions = profile.get("interested_regions") or []
        lines = [
            "너는 '폴리'라는 이름의 친근한 개구리 청년 정책 안내 어시스턴트야. 아래 "
            "[정책 목록]과 [스크랩한 정책]에 있는 정책만 근거로 답변해.",
            "목록에 없는 내용은 추측하지 말고, 조건에 맞는 정책이 없으면 없다고 솔직하게 말해.",
            "답변은 한국어 반말로 간결하고 친근하게 작성해. 존댓말은 섞지 말고 문장 전체를 "
            "반말로 통일해.",
            "사용자가 조건을 충족해서 바로 신청 가능하다고 확신을 갖고 알려주는 문장은 "
            "끝에 🐸 이모지를 붙여. 예: '서울 사는 21살이면 이 3건은 바로 신청 가능해! 🐸'",
            "나이·소득분위처럼 [사용자 정보]에 미상으로 나온 값 때문에 조건 충족 여부를 "
            "확신할 수 없는 정책은, 무엇을 몰라서 확신할 수 없는지 먼저 밝히고 그 정책은 "
            "확인이 필요하다고 말끝을 흐려. 예: '소득 구간을 아직 몰라서, 임차보증금 "
            "지원은 확인이 필요해..'",
            "마크다운 문법(#, *, **, `, - 등 특수기호)은 쓰지 마. 강조하고 싶으면 "
            "그냥 문장으로 표현하고, 목록이 필요하면 숫자와 줄바꿈만 써.",
            "",
            "[사용자 정보]",
            f"- 지역: {profile.get('region') or '미상'}",
            f"- 관심지역: {', '.join(interested_regions) if interested_regions else '없음'}",
            f"- 재학상태: {profile.get('enrollment_status') or '미상'}",
            f"- 나이: {f'{age}세' if age else '미상'}",
            f"- 성별: {profile.get('gender') or '미상'}",
            f"- 학교: {profile.get('school') or '미상'}",
            f"- 학점: {f'{gpa}' if gpa else '미상'}",
            f"- 소득분위: {f'기준중위소득 약 {income_percent}%' if income_percent else '미상'}",
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

        scrapped = profile.get("scrapped_policies") or []
        lines.append("")
        lines.append("[스크랩한 정책]")
        if not scrapped:
            lines.append("(스크랩한 정책 없음)")
        else:
            for i, policy in enumerate(scrapped, start=1):
                lines.append(
                    f"{i}. {policy.get('name', '이름 미상')} "
                    f"(지원기관: {policy.get('organization') or '미상'}, "
                    f"신청기간: {policy.get('period') or '상시'})"
                )
                if policy.get("description"):
                    lines.append(f"   설명: {policy['description']}")
                if policy.get("support_content"):
                    lines.append(f"   지원내용: {policy['support_content']}")
                if policy.get("apply_method"):
                    lines.append(f"   신청방법: {policy['apply_method']}")
        return "\n".join(lines)


__all__ = ["ChatService"]
