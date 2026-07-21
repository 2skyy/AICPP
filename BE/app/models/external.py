from sqlalchemy import Column, Table
from sqlalchemy.dialects.postgresql import UUID

from app.models.base import Base


# Supabase owns this table. Declaring only its key lets SQLAlchemy resolve
# foreign keys without asking Alembic to create or modify the auth schema.
auth_users = Table(
    "users",
    Base.metadata,
    Column("id", UUID(as_uuid=True), primary_key=True),
    schema="auth",
    info={"external": True},
)
