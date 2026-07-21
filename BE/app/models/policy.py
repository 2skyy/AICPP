import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    SmallInteger,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class Category(Base):
    __tablename__ = "categories"
    __table_args__ = ({"schema": "public"},)

    code: Mapped[str] = mapped_column(String(30), primary_key=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False, unique=True)
    sort_order: Mapped[int] = mapped_column(SmallInteger, nullable=False, server_default="0")
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true")


class Policy(Base):
    __tablename__ = "arranged_policies"
    __table_args__ = (
        CheckConstraint("min_age IS NULL OR min_age >= 0", name="min_age"),
        CheckConstraint("max_age IS NULL OR max_age >= 0", name="max_age"),
        CheckConstraint("min_age IS NULL OR max_age IS NULL OR min_age <= max_age", name="age_range"),
        {"schema": "public"},
    )

    policy_no: Mapped[str] = mapped_column(String(100), primary_key=True)
    policy_name: Mapped[str] = mapped_column(Text, nullable=False, index=True)
    keyword_names: Mapped[str | None] = mapped_column(Text)
    description: Mapped[str | None] = mapped_column(Text)
    support_content: Mapped[str | None] = mapped_column(Text)
    large_category: Mapped[str | None] = mapped_column(String(100), index=True)
    medium_category: Mapped[str | None] = mapped_column(String(100))
    approval_status_code: Mapped[str | None] = mapped_column(String(30))
    provision_method_code: Mapped[str | None] = mapped_column(String(30))
    min_age: Mapped[int | None] = mapped_column(SmallInteger)
    max_age: Mapped[int | None] = mapped_column(SmallInteger)
    age_limit_yn: Mapped[bool | None] = mapped_column(Boolean)
    marital_status_code: Mapped[str | None] = mapped_column(String(30))
    income_condition_code: Mapped[str | None] = mapped_column(String(30))
    min_income_amount: Mapped[int | None] = mapped_column(BigInteger)
    max_income_amount: Mapped[int | None] = mapped_column(BigInteger)
    income_condition_text: Mapped[str | None] = mapped_column(Text)
    additional_qualification: Mapped[str | None] = mapped_column(Text)
    participation_restriction: Mapped[str | None] = mapped_column(Text)
    education_code: Mapped[str | None] = mapped_column(Text)
    employment_code: Mapped[str | None] = mapped_column(Text)
    major_code: Mapped[str | None] = mapped_column(Text)
    special_business_code: Mapped[str | None] = mapped_column(Text)
    application_period_code: Mapped[str | None] = mapped_column(String(30))
    application_date_text: Mapped[str | None] = mapped_column(Text)
    application_start_date: Mapped[date | None] = mapped_column(Date, index=True)
    application_end_date: Mapped[date | None] = mapped_column(Date, index=True)
    application_method: Mapped[str | None] = mapped_column(Text)
    application_url: Mapped[str | None] = mapped_column(Text)
    screening_method: Mapped[str | None] = mapped_column(Text)
    submission_documents: Mapped[str | None] = mapped_column(Text)
    additional_information: Mapped[str | None] = mapped_column(Text)
    reference_url_1: Mapped[str | None] = mapped_column(Text)
    reference_url_2: Mapped[str | None] = mapped_column(Text)
    business_period_code: Mapped[str | None] = mapped_column(String(30))
    business_start_date: Mapped[date | None] = mapped_column(Date)
    business_end_date: Mapped[date | None] = mapped_column(Date)
    business_period_text: Mapped[str | None] = mapped_column(Text)
    support_scale_limit_yn: Mapped[bool | None] = mapped_column(Boolean)
    support_scale_count: Mapped[int | None] = mapped_column(Integer)
    first_come_first_served_yn: Mapped[bool | None] = mapped_column(Boolean)
    supervising_org_code: Mapped[str | None] = mapped_column(String(50))
    supervising_org_name: Mapped[str | None] = mapped_column(Text)
    supervising_contact_name: Mapped[str | None] = mapped_column(Text)
    operating_org_code: Mapped[str | None] = mapped_column(String(50))
    operating_org_name: Mapped[str | None] = mapped_column(Text)
    operating_contact_name: Mapped[str | None] = mapped_column(Text)
    registrar_org_code: Mapped[str | None] = mapped_column(String(50))
    registrar_org_name: Mapped[str | None] = mapped_column(Text)
    parent_registrar_code: Mapped[str | None] = mapped_column(String(50))
    parent_registrar_name: Mapped[str | None] = mapped_column(Text)
    top_registrar_code: Mapped[str | None] = mapped_column(String(50))
    top_registrar_name: Mapped[str | None] = mapped_column(Text)
    source_created_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    source_updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True)
    source_view_count: Mapped[int | None] = mapped_column(Integer)
    basic_plan_cycle: Mapped[int | None] = mapped_column(SmallInteger)
    basic_plan_policy_direction_no: Mapped[str | None] = mapped_column(String(30))
    basic_plan_focus_task_no: Mapped[str | None] = mapped_column(String(30))
    basic_plan_task_no: Mapped[str | None] = mapped_column(String(30))
    provision_institution_group_code: Mapped[str | None] = mapped_column(String(30))
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true", index=True)
    synced_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    source_hash: Mapped[str | None] = mapped_column(String(64))
    raw_data: Mapped[dict | None] = mapped_column(JSONB)
    # Existing support-amount pipeline columns. Keep these while callers are
    # migrated to policy_support_amounts.
    sprt_amt_krw: Mapped[int | None] = mapped_column(BigInteger)
    sprt_amt_type: Mapped[str | None] = mapped_column(String(30))
    sprt_amt_pct: Mapped[Decimal | None] = mapped_column(Numeric(8, 3))
    sprt_amt_confidence: Mapped[Decimal | None] = mapped_column(Numeric(5, 4))
    sprt_amt_evidence: Mapped[str | None] = mapped_column(Text)
    sprt_amt_source: Mapped[str | None] = mapped_column(String(100))
    sprt_amt_note: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now())


class PolicyCategory(Base):
    __tablename__ = "policy_categories"
    __table_args__ = ({"schema": "public"},)
    policy_no: Mapped[str] = mapped_column(ForeignKey("public.arranged_policies.policy_no", ondelete="CASCADE"), primary_key=True)
    category_code: Mapped[str] = mapped_column(ForeignKey("public.categories.code", ondelete="CASCADE"), primary_key=True, index=True)
    is_primary: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="false")


class PolicyRegion(Base):
    __tablename__ = "policy_regions"
    __table_args__ = ({"schema": "public"},)
    policy_no: Mapped[str] = mapped_column(ForeignKey("public.arranged_policies.policy_no", ondelete="CASCADE"), primary_key=True)
    region_code: Mapped[str] = mapped_column(ForeignKey("public.regions.code", ondelete="CASCADE"), primary_key=True, index=True)


class PolicySupportAmount(Base):
    __tablename__ = "policy_support_amounts"
    __table_args__ = (
        CheckConstraint("amount_krw IS NULL OR amount_krw >= 0", name="amount"),
        CheckConstraint("confidence IS NULL OR confidence BETWEEN 0 AND 1", name="confidence"),
        {"schema": "public"},
    )
    policy_no: Mapped[str] = mapped_column(ForeignKey("public.arranged_policies.policy_no", ondelete="CASCADE"), primary_key=True)
    amount_krw: Mapped[int | None] = mapped_column(BigInteger)
    amount_type: Mapped[str | None] = mapped_column(String(30))
    amount_percent: Mapped[Decimal | None] = mapped_column(Numeric(8, 3))
    confidence: Mapped[Decimal | None] = mapped_column(Numeric(5, 4))
    evidence: Mapped[str | None] = mapped_column(Text)
    source: Mapped[str | None] = mapped_column(String(100))
    note: Mapped[str | None] = mapped_column(Text)
    verification_status: Mapped[str] = mapped_column(String(20), nullable=False, server_default="PENDING")
    extracted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class UserSavedPolicy(Base):
    __tablename__ = "user_saved_policies"
    __table_args__ = ({"schema": "public"},)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("public.user_profiles.id", ondelete="CASCADE"), primary_key=True)
    policy_no: Mapped[str] = mapped_column(ForeignKey("public.arranged_policies.policy_no", ondelete="CASCADE"), primary_key=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now(), index=True)


class PolicyMatchResult(Base):
    __tablename__ = "policy_match_results"
    __table_args__ = (
        CheckConstraint("match_score IS NULL OR match_score BETWEEN 0 AND 100", name="score"),
        UniqueConstraint("user_id", "policy_no", "profile_version", "matcher_version", name="uq_policy_match_context"),
        {"schema": "public"},
    )
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=func.gen_random_uuid())
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("public.user_profiles.id", ondelete="CASCADE"), index=True)
    policy_no: Mapped[str] = mapped_column(ForeignKey("public.arranged_policies.policy_no", ondelete="CASCADE"), index=True)
    eligibility_status: Mapped[str] = mapped_column(String(20), nullable=False)
    match_score: Mapped[Decimal | None] = mapped_column(Numeric(5, 2))
    matched_conditions: Mapped[list | dict | None] = mapped_column(JSONB)
    unmatched_conditions: Mapped[list | dict | None] = mapped_column(JSONB)
    unknown_conditions: Mapped[list | dict | None] = mapped_column(JSONB)
    reason: Mapped[str | None] = mapped_column(Text)
    profile_version: Mapped[int] = mapped_column(Integer, nullable=False)
    matcher_version: Mapped[str] = mapped_column(String(30), nullable=False)
    policy_updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    calculated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
