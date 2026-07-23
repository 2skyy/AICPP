from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, Field


class SupportAmountExtraction(BaseModel):
    """정책 원문(정책지원내용)에서 청년 개인/청년 창업기업에게 실제 지급되는
    지원금액을 판정한다. 문화정책_라벨링_중앙·서울_코드기준.xlsx의 판정 기준과
    동일한 규칙을 따른다.
    """

    determination: Literal["있음", "없음", "비율기반"] = Field(
        description=(
            "청년 개인(또는 청년 창업기업)에게 실제로 돈이 지급되는지 여부. "
            "대출/융자/보증 한도(상환해야 하는 돈), 사업 전체 예산/펀드 조성액, "
            "자격조건에 등장하는 숫자는 지원금액이 아니므로 '없음'으로 판정."
        )
    )
    amount_krw: int | None = Field(
        default=None,
        description="determination이 '있음'일 때 원 단위 지원금액. 범위로 제시되면 상한값.",
    )
    amount_percent: Decimal | None = Field(
        default=None,
        description="determination이 '비율기반'일 때 지원 비율(%).",
    )
    evidence: str = Field(description="판정 근거가 된 원문 문장을 그대로 인용.")
    confidence: Decimal = Field(ge=0, le=1, description="판정에 대한 자체 신뢰도(0~1).")
    note: str | None = Field(
        default=None, description="확인 필요 사유 등 특이사항. 없으면 null.",
    )


__all__ = ["SupportAmountExtraction"]
