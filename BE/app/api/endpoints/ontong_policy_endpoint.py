import requests
from fastapi import APIRouter, Depends, HTTPException, Query

from app.api.clients.ontong_policy import OntongPolicyClient
from app.services.ontong_policy_service import OntongPolicyService
from app.services.policy_amount_service import get_shared_policy_amount_service


router = APIRouter(prefix="/api/ontong-policy", tags=["ontong-policy"])


def get_policy_service() -> OntongPolicyService:
    return OntongPolicyService(OntongPolicyClient(), amount_service=get_shared_policy_amount_service())


@router.get("/search")
def search_policies(
    query: str | None = None,
    # 정책명(plcyNm) 검색. 실제 온통청년 API에서 검증된 필터 파라미터.
    # 다른 필터(query/keyword/business_type/region_code)는 API가 인식하지
    # 못하는 이름이라 무시된다는 게 확인되어 그대로 두고, name만 추가함.
    name: str | None = None,
    # 정책키워드(plcyKywdNm) 검색. plcyNm과 마찬가지로 실제 API에서 검증된
    # 필터 파라미터. 정책명이 아니라 주제 키워드(주거/취업 등) 기준으로
    # 더 넓게 매칭하고 싶을 때 사용한다.
    topic: str | None = None,
    # 지역(zipCd) 검색. 시도명을 받아 app/constants/region_codes.py의 매핑으로
    # 시군구 코드 목록으로 변환한 뒤 zipCd 파라미터로 전달한다. plcyNm과 달리
    # 정책 "제목"이 아니라 정책이 실제로 적용되는 지역 기준으로 걸러진다.
    region: str | None = None,
    keyword: list[str] | None = Query(default=None),
    business_type: list[str] | None = Query(default=None),
    region_code: list[str] | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    size: int = Query(default=10, ge=1, le=100),
    service: OntongPolicyService = Depends(get_policy_service),
):
    try:
        return service.search(
            query=query,
            name=name,
            topic=topic,
            region=region,
            keywords=keyword,
            business_types=business_type,
            region_codes=region_code,
            page=page,
            size=size,
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    except (requests.RequestException, ValueError) as exc:
        raise HTTPException(
            status_code=502,
            detail=f"온통청년 API 호출 실패: {exc}",
        ) from exc
