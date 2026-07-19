from collections.abc import Sequence
from typing import Any

from app.api.clients.ontong_policy import OntongPolicyClient
from app.constants.region_codes import zip_codes_for
from app.services.policy_amount_service import PolicyAmountService


class OntongPolicyService:
    """앱의 검색조건을 온통청년 API 파라미터로 변환한다."""

    def __init__(self, client: OntongPolicyClient, amount_service: PolicyAmountService | None = None):
        self.client = client
        self.amount_service = amount_service or PolicyAmountService()

    def search(
        self,
        query: str | None = None,
        name: str | None = None,
        topic: str | None = None,
        region: str | None = None,
        keywords: Sequence[str] | None = None,
        business_types: Sequence[str] | None = None,
        region_codes: Sequence[str] | None = None,
        page: int = 1,
        size: int = 10,
    ) -> dict[str, Any]:
        response = self.client.get_policies(
            pageNum=page,
            pageSize=size,
            rtnType="json",
            query=query,
            plcyNm=name,
            plcyKywdNm=topic,
            zipCd=self._join(zip_codes_for(region)),
            keyword=self._join(keywords),
            bizTycdSel=self._join(business_types),
            srchPolyBizSecd=self._join(region_codes),
        )
        self._enrich_with_amounts(response)
        return response

    def _enrich_with_amounts(self, response: dict[str, Any]) -> None:
        """온통청년 응답 위에, 배치 파이프라인이 Supabase에 미리 뽑아둔 더
        정확한 지원금액(sprtAmtKrw 등)을 plcyNo 기준으로 덧붙인다. Supabase에
        없는 정책(신규 등록분 등)은 그대로 두어, 프론트가 기존 정규식 추출로
        폴백할 수 있게 한다.
        """
        result = response.get("result")
        items = result.get("youthPolicyList") if isinstance(result, dict) else None
        if not isinstance(items, list):
            return

        policy_numbers = [
            item["plcyNo"] for item in items if isinstance(item, dict) and item.get("plcyNo")
        ]
        amounts = self.amount_service.amounts_for(policy_numbers)
        if not amounts:
            return

        for item in items:
            if not isinstance(item, dict):
                continue
            row = amounts.get(item.get("plcyNo"))
            if not row:
                continue
            item["sprtAmtKrw"] = row.get("sprt_amt_krw")
            item["sprtAmtType"] = row.get("sprt_amt_type")
            item["sprtAmtPct"] = row.get("sprt_amt_pct")
            item["sprtAmtConfidence"] = row.get("sprt_amt_confidence")
            item["sprtAmtEvidence"] = row.get("sprt_amt_evidence")
            item["sprtAmtSource"] = row.get("sprt_amt_source")
            item["sprtAmtNote"] = row.get("sprt_amt_note")

    @staticmethod
    def _join(values: Sequence[str] | None) -> str | None:
        return ",".join(value for value in values if value) if values else None
