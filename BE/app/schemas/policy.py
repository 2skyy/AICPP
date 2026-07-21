from datetime import date, datetime
from decimal import Decimal
from pydantic import BaseModel
from app.schemas.common import PaginationMeta


class PolicySummary(BaseModel):
    policy_no: str
    policy_name: str
    description: str | None = None
    support_content: str | None = None
    large_category: str | None = None
    medium_category: str | None = None
    application_start_date: date | None = None
    application_end_date: date | None = None
    application_date_text: str | None = None
    supervising_org_name: str | None = None
    support_amount_krw: int | None = None


class PolicyDetail(PolicySummary):
    keyword_names: str | None = None
    min_age: int | None = None
    max_age: int | None = None
    income_condition_text: str | None = None
    additional_qualification: str | None = None
    participation_restriction: str | None = None
    application_method: str | None = None
    application_url: str | None = None
    screening_method: str | None = None
    submission_documents: str | None = None
    additional_information: str | None = None
    operating_org_name: str | None = None
    reference_url_1: str | None = None
    reference_url_2: str | None = None
    source_updated_at: datetime | None = None
    support_amount_type: str | None = None
    support_amount_percent: Decimal | None = None
    support_amount_confidence: Decimal | None = None
    support_amount_evidence: str | None = None


class PolicyListResponse(BaseModel):
    items: list[PolicySummary]
    pagination: PaginationMeta


class SavedPolicyResponse(PolicySummary):
    saved_at: datetime
