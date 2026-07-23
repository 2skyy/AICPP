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


def _extract_total_count(raw: dict[str, Any]) -> int | None:
    result = raw.get("result")
    if isinstance(result, dict):
        pagging = result.get("pagging")
        if isinstance(pagging, dict):
            return pagging.get("totCount")
    return None


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

    def ask(
        self, question: str, profile: dict[str, Any], is_first_message: bool = True
    ) -> dict[str, Any]:
        items, total_count = self._find_relevant_policies(question, profile)
        answer = self._generate_answer(question, profile, items, total_count, is_first_message)
        policies = [
            {"name": item.get("plcyNm", ""), "period": item.get("aplyYmd")}
            for item in items
        ]
        return {"answer": answer, "policies": policies}

    def _find_relevant_policies(
        self, question: str, profile: dict[str, Any]
    ) -> tuple[list[dict[str, Any]], int | None]:
        keyword = extract_topic_keyword(question)
        region = profile.get("region")
        if keyword:
            raw = self.policy_service.search(topic=keyword, size=10)
        elif region:
            raw = self.policy_service.search(region=region, size=10)
        else:
            return [], None
        today = date.today()
        items = [item for item in _extract_items(raw) if _is_open(item, today)]
        return items, _extract_total_count(raw)

    def _generate_answer(
        self,
        question: str,
        profile: dict[str, Any],
        items: list[dict[str, Any]],
        total_count: int | None,
        is_first_message: bool,
    ) -> str:
        system_prompt = self._build_system_prompt(profile, items, total_count, is_first_message)
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
    def _build_system_prompt(
        profile: dict[str, Any],
        items: list[dict[str, Any]],
        total_count: int | None,
        is_first_message: bool = True,
    ) -> str:
        age = profile.get("age")
        gpa = profile.get("gpa")
        income_percent = profile.get("income_percent")
        interested_regions = profile.get("interested_regions") or []
        greeting_instruction = (
            "이번이 사용자와의 첫 대화니까 '안녕' 등으로 짧게 자기소개하며 인사해도 좋아."
            if is_first_message
            else "지금은 이미 진행 중인 대화의 후속 질문이야. '안녕', '나는 폴리야' 같은 "
            "인사나 자기소개는 하지 말고 바로 답변부터 시작해."
        )
        lines = [
            "너는 '폴리'라는 이름의 친근한 개구리 청년 정책 안내 어시스턴트야. 아래 "
            "[정책 목록]과 [스크랩한 정책]에 있는 정책만 근거로 답변해.",
            "목록에 있는 내용은 지원금액·신청기간·신청방법까지 구체적으로 자세히 설명해. "
            "목록에 없는 내용은 절대 추측하지 말고 모른다고 짧고 솔직하게 말해 — 아는 "
            "척하거나 얼버무리지 마.",
            "정책에 '확정 지원금액'이 있으면 사람이 검토까지 마친 정확한 값이니 확신 있게 "
            "알려줘. 'AI 추정(검토 전, 참고용) 지원금액'만 있으면 아직 사람이 검토하지 "
            "않은 값이라고 꼭 밝히고 '약 OO원으로 추정되는데, 정확한 금액은 확인이 "
            "필요해' 처럼 말해. '지원금액 유형: 확인필요'라고 표시된 정책은 소득구간이나 "
            "개인 사정에 따라 금액·비율 자체가 달라지는 정책이라는 뜻이니, 특정 숫자를 "
            "만들어내지 말고 '이 정책은 조건에 따라 지원금이 달라져서, 정확한 금액은 "
            "확인이 필요해' 처럼 말해. 셋 다 없는 정책은 '지원내용' 원문에 적힌 대로만 "
            "말하고, 원문에도 구체적 금액이 없으면 금액은 모른다고 솔직하게 말해.",
            "[정책 목록]에 이번 질문 조건에 맞는 정책이 없으면 '이번 질문으로는 못 "
            "찾았어'처럼 이번 검색에 한정해서 말하고, 마치 정책 정보 자체가 아예 없는 "
            "것처럼 말하지 마. 이전 답변을 정정하거나 '아, 그 말이 아니라' 같은 자기 "
            "정정 표현은 쓰지 말고, 매 질문마다 그때 주어진 [정책 목록]만 근거로 바로 "
            "정확하게 답해.",
            "답변은 한국어 반말로 간결하고 친근하게 작성해. 존댓말은 섞지 말고 문장 전체를 "
            "반말로 통일해.",
            greeting_instruction,
            "사용자가 조건을 충족해서 바로 신청 가능하다고 확신을 갖고 알려주는 문장은 "
            "끝에 🐸 이모지를 붙여. 예: '서울 사는 21살이면 이 3건은 바로 신청 가능해! 🐸'",
            "나이·소득분위처럼 [사용자 정보]에 미상으로 나온 값 때문에 조건 충족 여부를 "
            "확신할 수 없는 정책은, 무엇을 몰라서 확신할 수 없는지 먼저 밝히고 그 정책은 "
            "확인이 필요하다고 말끝을 흐려. 예: '소득 구간을 아직 몰라서, 임차보증금 "
            "지원은 확인이 필요해..'",
            "마크다운 문법(#, *, **, `, - 등 특수기호)은 쓰지 마. 강조하고 싶으면 "
            "그냥 문장으로 표현하고, 목록이 필요하면 숫자와 줄바꿈만 써.",
            "[정책 목록] 맨 앞에 '이번 검색에서 상위 N건만 보여주는 중, 전체 후보는 "
            "약 M건'이라고 적혀 있으면, 답변 끝에 'OO건 더 있으니 더 보고 싶으면 "
            "말해줘' 처럼 짧게 한 줄 덧붙여. 그 문구가 없으면 언급하지 마.",
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
            if total_count is not None and total_count > len(items):
                lines.append(
                    f"(이번 검색에서 상위 {len(items)}건만 보여주는 중, 전체 후보는 "
                    f"약 {total_count}건 — 신청기간이 지난 것도 섞여 있을 수 있음)"
                )
            for i, item in enumerate(items, start=1):
                lines.append(
                    f"{i}. {item.get('plcyNm', '이름 미상')} "
                    f"(지원기관: {item.get('sprvsnInstCdNm', '미상')}, "
                    f"신청기간: {item.get('aplyYmd', '상시')})"
                )
                amt_label = "확정" if item.get("sprtAmtVerified") else "AI 추정(검토 전, 참고용)"
                if item.get("sprtAmtKrw"):
                    lines.append(f"   {amt_label} 지원금액: {item['sprtAmtKrw']:,}원")
                elif item.get("sprtAmtType") == "확인필요":
                    lines.append(f"   지원금액 유형({amt_label}): 확인필요 — 조건별로 금액이 달라 원문만으로는 확정 불가")
                if item.get("plcyExplnCn"):
                    lines.append(f"   설명: {item['plcyExplnCn']}")
                if item.get("plcySprtCn"):
                    lines.append(f"   지원내용: {item['plcySprtCn']}")
                if item.get("plcyAplyMthdCn"):
                    lines.append(f"   신청방법: {item['plcyAplyMthdCn']}")
                apply_url = item.get("aplyUrlAddr") or item.get("refUrlAddr1")
                if apply_url:
                    lines.append(f"   신청링크: {apply_url}")

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
                if policy.get("apply_url"):
                    lines.append(f"   신청링크: {policy['apply_url']}")
        return "\n".join(lines)


__all__ = ["ChatService"]
