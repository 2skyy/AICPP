import requests
from fastapi import APIRouter, Depends, HTTPException, Query

from app.api.clients.ontong_policy import OntongPolicyClient
from app.services.ontong_policy_service import OntongPolicyService


router = APIRouter(prefix="/api/ontong-policy", tags=["ontong-policy"])


def get_policy_service() -> OntongPolicyService:
    return OntongPolicyService(OntongPolicyClient())


@router.get("/search")
def search_policies(
    query: str | None = None,
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
