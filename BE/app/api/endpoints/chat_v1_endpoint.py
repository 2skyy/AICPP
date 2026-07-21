import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.auth import CurrentUser, get_current_user
from app.core.database import get_db
from app.models import ChatConversation, ChatMessage
from app.schemas.chat import (
    ChatMessageResponse,
    ConversationCreate,
    ConversationDetail,
    ConversationResponse,
    MessageCreate,
)


router = APIRouter(prefix="/api/v1/chat/conversations", tags=["v1-chat"])


def _conversation(db: Session, conversation_id, user_id) -> ChatConversation:
    conversation = db.scalar(
        select(ChatConversation).where(
            ChatConversation.id == conversation_id,
            ChatConversation.user_id == user_id,
        )
    )
    if conversation is None:
        raise HTTPException(status_code=404, detail="Conversation not found")
    return conversation


def _conversation_response(item: ChatConversation) -> ConversationResponse:
    return ConversationResponse(
        id=item.id, title=item.title, created_at=item.created_at, updated_at=item.updated_at
    )


def _message_response(item: ChatMessage) -> ChatMessageResponse:
    return ChatMessageResponse(
        id=item.id,
        sequence_no=item.sequence_no,
        role=item.role,
        content=item.content,
        created_at=item.created_at,
    )


@router.post("", response_model=ConversationResponse, status_code=201)
def create_conversation(
    body: ConversationCreate,
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ConversationResponse:
    item = ChatConversation(user_id=user.id, title=body.title)
    db.add(item)
    db.commit()
    db.refresh(item)
    return _conversation_response(item)


@router.get("", response_model=list[ConversationResponse])
def list_conversations(
    user: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)
) -> list[ConversationResponse]:
    items = db.scalars(
        select(ChatConversation)
        .where(ChatConversation.user_id == user.id)
        .order_by(ChatConversation.updated_at.desc())
    ).all()
    return [_conversation_response(item) for item in items]


@router.get("/{conversation_id}", response_model=ConversationDetail)
def get_conversation(
    conversation_id: uuid.UUID,
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ConversationDetail:
    item = _conversation(db, conversation_id, user.id)
    messages = db.scalars(
        select(ChatMessage)
        .where(ChatMessage.conversation_id == item.id)
        .order_by(ChatMessage.sequence_no)
    ).all()
    return ConversationDetail(
        **_conversation_response(item).model_dump(),
        messages=[_message_response(message) for message in messages],
    )


@router.post("/{conversation_id}/messages", response_model=ChatMessageResponse, status_code=201)
def create_message(
    conversation_id: uuid.UUID,
    body: MessageCreate,
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ChatMessageResponse:
    conversation = _conversation(db, conversation_id, user.id)
    next_sequence = (db.scalar(
        select(func.max(ChatMessage.sequence_no)).where(ChatMessage.conversation_id == conversation.id)
    ) or 0) + 1
    message = ChatMessage(
        conversation_id=conversation.id,
        sequence_no=next_sequence,
        role="USER",
        content=body.content,
    )
    db.add(message)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=409, detail="Message sequence conflict; retry request") from exc
    db.refresh(message)
    return _message_response(message)
