import anthropic
import requests
from fastapi import APIRouter, Depends, HTTPException, Query

from app.api.clients.news_api import NewsApiClient
from app.services.news_service import NewsRecommendationService

router = APIRouter(prefix="/api/news", tags=["news"])


def get_news_service() -> NewsRecommendationService:
    return NewsRecommendationService(NewsApiClient())


@router.get("/recommendations")
def recommendations(
    interests: list[str] = Query(default=[]),
    service: NewsRecommendationService = Depends(get_news_service),
):
    try:
        return {"articles": service.recommend(interests)}
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
