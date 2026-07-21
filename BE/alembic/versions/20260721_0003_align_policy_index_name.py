"""Align the renamed policy match index with ORM naming conventions.

Revision ID: 20260721_0003
Revises: 20260721_0002
Create Date: 2026-07-21
"""

from collections.abc import Sequence

from alembic import op
from sqlalchemy import inspect


revision: str = "20260721_0003"
down_revision: str | None = "20260721_0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


OLD_NAME = "ix_public_policy_match_results_plcy_no"
NEW_NAME = "ix_public_policy_match_results_policy_no"


def upgrade() -> None:
    indexes = {
        index["name"]
        for index in inspect(op.get_bind()).get_indexes(
            "policy_match_results", schema="public"
        )
    }
    if OLD_NAME in indexes and NEW_NAME not in indexes:
        op.execute(
            f'ALTER INDEX public."{OLD_NAME}" RENAME TO "{NEW_NAME}"'
        )


def downgrade() -> None:
    indexes = {
        index["name"]
        for index in inspect(op.get_bind()).get_indexes(
            "policy_match_results", schema="public"
        )
    }
    if NEW_NAME in indexes and OLD_NAME not in indexes:
        op.execute(
            f'ALTER INDEX public."{NEW_NAME}" RENAME TO "{OLD_NAME}"'
        )
