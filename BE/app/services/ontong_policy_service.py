from collections.abc import Sequence
from typing import Any

from app.api.clients.ontong_policy import OntongPolicyClient


class OntongPolicyService:
    """앱의 검색조건을 온통청년 API 파라미터로 변환한다."""

    def __init__(self, client: OntongPolicyClient):
        self.client = client

    def search(
        self,
        query: str | None = None,
        name: str | None = None,
        topic: str | None = None,
        keywords: Sequence[str] | None = None,
        business_types: Sequence[str] | None = None,
        region_codes: Sequence[str] | None = None,
        page: int = 1,
        size: int = 10,
    ) -> dict[str, Any]:
        return self.client.get_policies(
            pageNum=page,
            pageSize=size,
            rtnType="json",
            query=query,
            plcyNm=name,
            plcyKywdNm=topic,
            keyword=self._join(keywords),
            bizTycdSel=self._join(business_types),
            srchPolyBizSecd=self._join(region_codes),
        )

    @staticmethod
    def _join(values: Sequence[str] | None) -> str | None:
        return ",".join(value for value in values if value) if values else None
