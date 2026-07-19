import anthropic
import requests
from fastapi import APIRouter, Depends, HTTPException, Query

from app.api.clients.news_api import NewsApiClient
from app.services.news_service import RECOMMENDATION_COUNT, NewsRecommendationService

router = APIRouter(prefix="/api/news", tags=["news"])


def get_news_service() -> NewsRecommendationService:
    return NewsRecommendationService(NewsApiClient())


@router.get("/recommendations")
def recommendations(
    interests: list[str] = Query(default=[]),
    # 매칭된 정책 수만큼 뉴스를 보여주고 싶을 때 등, 원하는 추천 개수를 지정.
    # 안 넘기면 기본값(RECOMMENDATION_COUNT)만큼 추천한다. 상한은 서비스 내부에서
    # CANDIDATE_COUNT로 알아서 클램프하므로, 여기서는 그보다 큰 값도 그대로 받는다
    # (매칭된 정책 수가 CANDIDATE_COUNT를 넘으면 422로 거부되던 문제를 방지).
    count: int = Query(default=RECOMMENDATION_COUNT, ge=0),
    service: NewsRecommendationService = Depends(get_news_service),
):
    try:
        return {"articles": service.recommend(interests, count=count)}
    except RuntimeError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    except (requests.RequestException, ValueError) as exc:
        raise HTTPException(
            status_code=502,
            detail=f"뉴스 조회 실패: {exc}",
        ) from exc
    except anthropic.APIError as exc:
        raise HTTPException(
            status_code=502,
            detail=f"AI 추천 생성에 실패했어요: {exc}",
        ) from exc
