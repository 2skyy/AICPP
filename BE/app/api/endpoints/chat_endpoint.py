import anthropic
import requests
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.api.clients.ontong_policy import OntongPolicyClient
from app.services.chat_service import ChatService
from app.services.ontong_policy_service import OntongPolicyService

router = APIRouter(prefix="/api/chat", tags=["chat"])


class ProfileIn(BaseModel):
    region: str | None = None
    enrollment_status: str | None = None
    age: int | None = None
    interested_regions: list[str] | None = None


class ChatRequest(BaseModel):
    question: str
    profile: ProfileIn


def get_chat_service() -> ChatService:
    return ChatService(OntongPolicyService(OntongPolicyClient()))


@router.post("/ask")
def ask(request: ChatRequest, service: ChatService = Depends(get_chat_service)):
    try:
        return service.ask(request.question, request.profile.model_dump())
    except RuntimeError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    except (requests.RequestException, ValueError) as exc:
        raise HTTPException(
            status_code=502,
            detail=f"온통청년 API 호출 실패: {exc}",
        ) from exc
    except anthropic.APIError as exc:
        raise HTTPException(
            status_code=502,
            detail=f"AI 응답 생성에 실패했어요: {exc}",
        ) from exc
