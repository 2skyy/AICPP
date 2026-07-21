import math
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from sqlalchemy import asc, desc, func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.auth import CurrentUser, get_current_user
from app.core.database import get_db
from app.models import Policy, PolicyCategory, PolicyRegion, UserSavedPolicy
from app.schemas.common import MessageResponse, PaginationMeta
from app.schemas.policy import PolicyDetail, PolicyListResponse, PolicySummary, SavedPolicyResponse


router = APIRouter(prefix="/api/v1", tags=["v1-policies"])


def _summary(policy: Policy) -> PolicySummary:
    return PolicySummary(
        policy_no=policy.policy_no,
        policy_name=policy.policy_name or "이름 없는 정책",
        description=policy.description,
        support_content=policy.support_content,
        large_category=policy.large_category,
        medium_category=policy.medium_category,
        application_start_date=policy.application_start_date,
        application_end_date=policy.application_end_date,
        application_date_text=policy.application_date_text,
        supervising_org_name=policy.supervising_org_name,
        support_amount_krw=policy.sprt_amt_krw,
    )


def _detail(policy: Policy) -> PolicyDetail:
    return PolicyDetail(
        **_summary(policy).model_dump(),
        keyword_names=policy.keyword_names,
        min_age=policy.min_age,
        max_age=policy.max_age,
        income_condition_text=policy.income_condition_text,
        additional_qualification=policy.additional_qualification,
        participation_restriction=policy.participation_restriction,
        application_method=policy.application_method,
        application_url=policy.application_url,
        screening_method=policy.screening_method,
        submission_documents=policy.submission_documents,
        additional_information=policy.additional_information,
        operating_org_name=policy.operating_org_name,
        reference_url_1=policy.reference_url_1,
        reference_url_2=policy.reference_url_2,
        source_updated_at=policy.source_updated_at,
        support_amount_type=policy.sprt_amt_type,
        support_amount_percent=policy.sprt_amt_pct,
        support_amount_confidence=policy.sprt_amt_confidence,
        support_amount_evidence=policy.sprt_amt_evidence,
    )


@router.get("/policies", response_model=PolicyListResponse)
def list_policies(
    search: str | None = None,
    region_code: str | None = None,
    category_code: str | None = None,
    accepting_only: bool = False,
    sort: str = Query(default="latest", pattern="^(latest|deadline|amount)$"),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_db),
) -> PolicyListResponse:
    statement = select(Policy).where(Policy.is_active.is_(True))
    if search:
        pattern = f"%{search.strip()}%"
        statement = statement.where(
            or_(Policy.policy_name.ilike(pattern), Policy.description.ilike(pattern), Policy.keyword_names.ilike(pattern))
        )
    if region_code:
        statement = statement.join(PolicyRegion).where(PolicyRegion.region_code == region_code)
    if category_code:
        statement = statement.join(PolicyCategory).where(PolicyCategory.category_code == category_code)
    if accepting_only:
        today = date.today()
        statement = statement.where(
            or_(Policy.application_start_date.is_(None), Policy.application_start_date <= today),
            or_(Policy.application_end_date.is_(None), Policy.application_end_date >= today),
        )
    count_statement = select(func.count()).select_from(statement.order_by(None).subquery())
    total = db.scalar(count_statement) or 0
    if sort == "deadline":
        statement = statement.order_by(Policy.application_end_date.asc().nulls_last(), Policy.policy_no)
    elif sort == "amount":
        statement = statement.order_by(Policy.sprt_amt_krw.desc().nulls_last(), Policy.policy_no)
    else:
        statement = statement.order_by(Policy.source_updated_at.desc().nulls_last(), Policy.created_at.desc())
    policies = db.scalars(statement.offset((page - 1) * page_size).limit(page_size)).all()
    return PolicyListResponse(
        items=[_summary(policy) for policy in policies],
        pagination=PaginationMeta(
            page=page,
            page_size=page_size,
            total=total,
            total_pages=math.ceil(total / page_size) if total else 0,
        ),
    )


@router.get("/policies/{policy_no}", response_model=PolicyDetail)
def get_policy(policy_no: str, db: Session = Depends(get_db)) -> PolicyDetail:
    policy = db.get(Policy, policy_no)
    if policy is None or not policy.is_active:
        raise HTTPException(status_code=404, detail="Policy not found")
    return _detail(policy)


@router.post("/saved-policies/{policy_no}", response_model=MessageResponse, status_code=201)
def save_policy(
    policy_no: str,
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MessageResponse:
    if db.get(Policy, policy_no) is None:
        raise HTTPException(status_code=404, detail="Policy not found")
    saved = UserSavedPolicy(user_id=user.id, policy_no=policy_no)
    db.add(saved)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=409, detail="Policy is already saved or profile is missing") from exc
    return MessageResponse(message="Policy saved")


@router.get("/saved-policies", response_model=list[SavedPolicyResponse])
def list_saved_policies(
    user: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)
) -> list[SavedPolicyResponse]:
    rows = db.execute(
        select(UserSavedPolicy, Policy)
        .join(Policy, Policy.policy_no == UserSavedPolicy.policy_no)
        .where(UserSavedPolicy.user_id == user.id)
        .order_by(UserSavedPolicy.created_at.desc())
    ).all()
    return [
        SavedPolicyResponse(**_summary(policy).model_dump(), saved_at=saved.created_at)
        for saved, policy in rows
    ]


@router.delete("/saved-policies/{policy_no}", status_code=204)
def unsave_policy(
    policy_no: str,
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Response:
    saved = db.get(UserSavedPolicy, (user.id, policy_no))
    if saved is None:
        raise HTTPException(status_code=404, detail="Saved policy not found")
    db.delete(saved)
    db.commit()
    return Response(status_code=204)
