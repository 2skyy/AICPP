"""Create arranged_policies and copy normalized data from legacy policies.

Revision ID: 20260721_0002
Revises: 20260721_0001
Create Date: 2026-07-21
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

from app.models import Policy


revision: str = "20260721_0002"
down_revision: str | None = "20260721_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


REGIONS = [
    ("11", "서울특별시", "서울", 1), ("26", "부산광역시", "부산", 2),
    ("27", "대구광역시", "대구", 3), ("28", "인천광역시", "인천", 4),
    ("29", "광주광역시", "광주", 5), ("30", "대전광역시", "대전", 6),
    ("31", "울산광역시", "울산", 7), ("36", "세종특별자치시", "세종", 8),
    ("41", "경기도", "경기", 9), ("43", "충청북도", "충북", 10),
    ("44", "충청남도", "충남", 11), ("46", "전라남도", "전남", 12),
    ("47", "경상북도", "경북", 13), ("48", "경상남도", "경남", 14),
    ("50", "제주특별자치도", "제주", 15), ("51", "강원특별자치도", "강원", 16),
    ("52", "전북특별자치도", "전북", 17),
]

CATEGORIES = [
    ("JOB_STARTUP", "취업·창업", 1), ("FINANCE", "경제·재테크", 2),
    ("CULTURE_ART", "문화·예술", 3), ("HEALTH", "건강", 4),
    ("EDUCATION", "교육", 5), ("HOUSING", "주거", 6),
    ("UNCLASSIFIED", "미분류", 99),
]

SOURCE_MAP = {
    "policy_no": "plcy_no",
    "policy_name": "plcy_nm",
    "large_category": "lclsf_nm",
    "medium_category": "mclsf_nm",
    "description": "plcy_expln_cn",
    "support_content": "plcy_sprt_cn",
    "provision_method_code": "plcy_pvsn_mthd_cd",
    "supervising_org_name": "sprvsn_inst_nm",
    "operating_org_name": "oper_inst_nm",
    "min_age": "sprt_trgt_min_age",
    "max_age": "sprt_trgt_max_age",
    "employment_code": "job_cd",
    "education_code": "school_cd",
    "marital_status_code": "mrg_stts_cd",
    "income_condition_code": "earn_cnd_se_cd",
    "min_income_amount": "earn_min_amt",
    "max_income_amount": "earn_max_amt",
    "income_condition_text": "earn_etc_cn",
    "special_business_code": "sbiz_cd",
    "application_date_text": "aply_ymd",
    "application_url": "aply_url_addr",
    "reference_url_1": "ref_url_addr1",
    "reference_url_2": "ref_url_addr2",
    "source_created_at": "frst_reg_dt",
    "source_updated_at": "last_mdfcn_dt",
}

DEPENDENT_TABLES = [
    "policy_categories", "policy_regions", "policy_support_amounts",
    "user_saved_policies", "policy_match_results", "policy_news",
]


def _quoted(name: str) -> str:
    return f'"{name}"'


def _copy_source_policies(bind) -> None:
    inspector = inspect(bind)
    source_columns = {
        column["name"] for column in inspector.get_columns("policies", schema="public")
    }
    target_columns = [column.name for column in Policy.__table__.columns]
    expressions: list[str] = []
    for target in target_columns:
        source = SOURCE_MAP.get(target)
        if target in {"min_age", "max_age"} and source and source in source_columns:
            if target in source_columns:
                expression = f"NULLIF(COALESCE({_quoted(target)}, {_quoted(source)}), 0)"
            else:
                expression = f"NULLIF({_quoted(source)}, 0)"
        elif target == "age_limit_yn" and "sprt_trgt_age_lmt_yn" in source_columns:
            expression = "CASE WHEN lower(trim(sprt_trgt_age_lmt_yn)) IN ('y','yes','true','1') THEN true WHEN lower(trim(sprt_trgt_age_lmt_yn)) IN ('n','no','false','0') THEN false ELSE NULL END"
        elif target == "application_start_date" and "aply_ymd" in source_columns:
            expression = "CASE WHEN aply_ymd ~ '^\\s*\\d{8}' THEN to_date(substring(aply_ymd FROM '^\\s*(\\d{8})'), 'YYYYMMDD') ELSE NULL END"
        elif target == "application_end_date" and "aply_ymd" in source_columns:
            expression = "CASE WHEN aply_ymd ~ '~\\s*\\d{8}' THEN to_date(substring(aply_ymd FROM '~\\s*(\\d{8})'), 'YYYYMMDD') ELSE NULL END"
        elif source and source in source_columns and target in source_columns:
            expression = f"COALESCE({_quoted(target)}, {_quoted(source)})"
        elif source and source in source_columns:
            expression = _quoted(source)
        elif target in source_columns:
            expression = _quoted(target)
        elif target == "policy_name":
            expression = "'[이름 없음]'"
        elif target == "is_active":
            expression = "true"
        elif target in {"created_at", "updated_at"}:
            expression = "now()"
        else:
            expression = "NULL"
        expressions.append(f"{expression} AS {_quoted(target)}")

    sql = (
        f"INSERT INTO public.arranged_policies ({', '.join(map(_quoted, target_columns))}) "
        f"SELECT {', '.join(expressions)} FROM public.policies "
        "ON CONFLICT (policy_no) DO UPDATE SET updated_at = EXCLUDED.updated_at"
    )
    bind.exec_driver_sql(sql)


def _repoint_foreign_keys(bind) -> None:
    inspector = inspect(bind)
    for table_name in DEPENDENT_TABLES:
        if not inspector.has_table(table_name, schema="public"):
            continue
        columns = {column["name"] for column in inspector.get_columns(table_name, schema="public")}
        old_column = "plcy_no" if "plcy_no" in columns else "policy_no"
        for fk in inspector.get_foreign_keys(table_name, schema="public"):
            if old_column in fk.get("constrained_columns", []):
                op.drop_constraint(fk["name"], table_name, schema="public", type_="foreignkey")
        if old_column == "plcy_no":
            op.alter_column(table_name, "plcy_no", new_column_name="policy_no", schema="public")
        op.create_foreign_key(
            f"fk_{table_name}_policy_no_arranged_policies",
            table_name,
            "arranged_policies",
            ["policy_no"],
            ["policy_no"],
            source_schema="public",
            referent_schema="public",
            ondelete="CASCADE",
        )


def upgrade() -> None:
    bind = op.get_bind()
    if not inspect(bind).has_table("policies", schema="public"):
        raise RuntimeError("public.policies source table is required")
    Policy.__table__.create(bind=bind, checkfirst=True)
    _copy_source_policies(bind)
    _repoint_foreign_keys(bind)

    for code, name, short_name, sort_order in REGIONS:
        bind.execute(sa.text("""
            INSERT INTO public.regions (code, name, short_name, level, sort_order)
            VALUES (:code, :name, :short_name, 'SIDO', :sort_order)
            ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name, short_name=EXCLUDED.short_name,
                level=EXCLUDED.level, sort_order=EXCLUDED.sort_order
        """), {"code": code, "name": name, "short_name": short_name, "sort_order": sort_order})

    for code, name, sort_order in CATEGORIES:
        bind.execute(sa.text("""
            INSERT INTO public.categories (code, name, sort_order, is_active)
            VALUES (:code, :name, :sort_order, true)
            ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name,
                sort_order=EXCLUDED.sort_order, is_active=true
        """), {"code": code, "name": name, "sort_order": sort_order})

    source_columns = {
        column["name"] for column in inspect(bind).get_columns("policies", schema="public")
    }
    if "zip_cd" in source_columns:
        op.execute(sa.text("""
            INSERT INTO public.policy_regions (policy_no, region_code)
            SELECT DISTINCT p.plcy_no, left(trim(z.zip_code), 2)
            FROM public.policies p
            CROSS JOIN LATERAL unnest(p.zip_cd) AS z(zip_code)
            JOIN public.regions r ON r.code = left(trim(z.zip_code), 2)
            WHERE z.zip_code IS NOT NULL AND trim(z.zip_code) ~ '^\\d{5}$'
            ON CONFLICT DO NOTHING
        """))

    op.execute(sa.text("""
        INSERT INTO public.policy_support_amounts
            (policy_no, amount_krw, amount_type, amount_percent, confidence, evidence, source, note)
        SELECT policy_no, sprt_amt_krw, sprt_amt_type, sprt_amt_pct,
               sprt_amt_confidence, sprt_amt_evidence, sprt_amt_source, sprt_amt_note
        FROM public.arranged_policies
        WHERE sprt_amt_krw IS NOT NULL OR sprt_amt_pct IS NOT NULL
        ON CONFLICT (policy_no) DO NOTHING
    """))


def downgrade() -> None:
    # Keep both source and arranged policy data on rollback. A destructive
    # downgrade must be performed manually after checking dependent records.
    pass
