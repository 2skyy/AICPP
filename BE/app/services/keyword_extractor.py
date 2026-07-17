# 자주 쓰이는 청년정책 주제 키워드 사전. 더 구체적인 단어를 먼저 확인해서
# 예를 들어 "학자금"이 "교육"보다 먼저 매칭되도록 순서를 둔다.
_TOPIC_KEYWORDS = [
    "전세", "월세", "주거", "주택", "기숙사",
    "취업", "일자리", "채용", "인턴", "구직",
    "창업", "사업화",
    "장학금", "등록금", "학자금", "교육",
    "지원금", "생활비", "수당", "복지",
    "문화", "여가", "동아리",
    "건강", "의료", "상담",
    "대출", "저축", "금융",
    "참여", "권리",
]


def extract_topic_keyword(question: str) -> str | None:
    """질문 문자열에 포함된 첫 번째 알려진 정책 주제 키워드를 반환한다."""
    for keyword in _TOPIC_KEYWORDS:
        if keyword in question:
            return keyword
    return None
