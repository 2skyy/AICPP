import anthropic
import requests
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.api.clients.ontong_policy import OntongPolicyClient
from app.services.chat_service import ChatService
from app.services.ontong_policy_service import OntongPolicyService
from app.services.policy_amount_service import get_shared_policy_amount_service

router = APIRouter(prefix="/api/chat", tags=["chat"])


class ScrappedPolicyIn(BaseModel):
    name: str
    organization: str | None = None
    period: str | None = None
    description: str | None = None
    support_content: str | None = None
    apply_method: str | None = None


class ProfileIn(BaseModel):
    region: str | None = None
    enrollment_status: str | None = None
    age: int | None = None
    gender: str | None = None
    school: str | None = None
    gpa: float | None = None
    income_percent: int | None = None
    interested_regions: list[str] | None = None
    scrapped_policies: list[ScrappedPolicyIn] | None = None


class ChatRequest(BaseModel):
    question: str
    profile: ProfileIn
    is_first_message: bool = True


def get_chat_service() -> ChatService:
    policy_service = OntongPolicyService(
        OntongPolicyClient(), amount_service=get_shared_policy_amount_service()
    )
    return ChatService(policy_service)


@router.post("/ask")
def ask(request: ChatRequest, service: ChatService = Depends(get_chat_service)):
    try:
        return service.ask(request.question, request.profile.model_dump(), request.is_first_message)
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
