"""Create the application domain schema without replacing existing policies.

Revision ID: 20260721_0001
Revises:
Create Date: 2026-07-21
"""

from collections.abc import Sequence

from alembic import op
from sqlalchemy import inspect

from app.models import Base, Policy


revision: str = "20260721_0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


EXTERNAL_TABLES = {"auth.users"}
DOMAIN_TABLES = [
    "public.regions",
    "public.categories",
    "public.policies",
    "public.user_profiles",
    "public.policy_sync_runs",
    "public.news_articles",
    "public.user_interest_regions",
    "public.policy_categories",
    "public.policy_regions",
    "public.policy_support_amounts",
    "public.user_saved_policies",
    "public.policy_match_results",
    "public.policy_news",
    "public.chat_conversations",
    "public.chat_messages",
]


def _qualified(table) -> str:
    return f"{table.schema}.{table.name}" if table.schema else table.name


def upgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)

    # A support-amount pipeline may already have created public.policies.
    # Extend it in place instead of dropping users' existing extracted data.
    if inspector.has_table("policies", schema="public"):
        existing = {
            column["name"]
            for column in inspector.get_columns("policies", schema="public")
        }
        for column in Policy.__table__.columns:
            if column.name == "plcy_no" or column.name in existing:
                continue
            new_column = column._copy()
            # Existing rows cannot satisfy a newly added required field until
            # the first policy synchronization has backfilled it.
            if new_column.name == "policy_name":
                new_column.nullable = True
            op.add_column("policies", new_column, schema="public")
    else:
        Policy.__table__.create(bind=bind, checkfirst=True)

    # SQLAlchemy sorts these by foreign-key dependency. Supabase's auth.users
    # is external and deliberately excluded.
    for table in Base.metadata.sorted_tables:
        name = _qualified(table)
        if name in EXTERNAL_TABLES or name == "public.policies":
            continue
        table.create(bind=bind, checkfirst=True)


def downgrade() -> None:
    bind = op.get_bind()
    for name in reversed(DOMAIN_TABLES):
        schema, table_name = name.split(".", 1)
        if table_name == "policies":
            # The table can predate Alembic and may contain reviewed support
            # amounts, so a downgrade must never destroy it.
            continue
        table = Base.metadata.tables.get(name)
        if table is not None:
            table.drop(bind=bind, checkfirst=True)
