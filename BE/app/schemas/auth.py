import uuid
from pydantic import BaseModel, Field


class AuthMeResponse(BaseModel):
    id: uuid.UUID
    email: str | None = None
    user_metadata: dict = Field(default_factory=dict)


class AuthCredentials(BaseModel):
    email: str
    password: str


class AuthSessionResponse(BaseModel):
    access_token: str
    refresh_token: str
    user_id: str
    email: str
