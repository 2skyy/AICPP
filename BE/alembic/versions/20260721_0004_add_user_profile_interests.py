"""Add user_profiles.interests so the profile's 관심사 selection persists.

Revision ID: 20260721_0004
Revises: 20260721_0003
Create Date: 2026-07-21
"""

from collections.abc import Sequence

from alembic import op
from sqlalchemy import Column, Text
from sqlalchemy.dialects.postgresql import ARRAY


revision: str = "20260721_0004"
down_revision: str | None = "20260721_0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "user_profiles",
        Column("interests", ARRAY(Text), nullable=True),
        schema="public",
    )


def downgrade() -> None:
    op.drop_column("user_profiles", "interests", schema="public")
