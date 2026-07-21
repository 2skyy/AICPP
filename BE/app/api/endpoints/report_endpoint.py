from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.auth import CurrentUser, get_current_user
from app.core.database import get_db
from app.models import Policy, PolicyMatchResult, UserSavedPolicy
from app.schemas.report import CategoryCount, MyReportResponse


router = APIRouter(prefix="/api/v1/reports", tags=["v1-reports"])


@router.get("/me", response_model=MyReportResponse)
def my_report(
    user: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)
) -> MyReportResponse:
    active = db.scalar(select(func.count()).select_from(Policy).where(Policy.is_active.is_(True))) or 0
    matched = db.scalar(
        select(func.count()).select_from(PolicyMatchResult).where(PolicyMatchResult.user_id == user.id)
    ) or 0
    eligible = db.scalar(
        select(func.count()).select_from(PolicyMatchResult).where(
            PolicyMatchResult.user_id == user.id,
            PolicyMatchResult.eligibility_status == "ELIGIBLE",
        )
    ) or 0
    saved = db.scalar(
        select(func.count()).select_from(UserSavedPolicy).where(UserSavedPolicy.user_id == user.id)
    ) or 0
    category_rows = db.execute(
        select(func.coalesce(Policy.large_category, "UNCLASSIFIED"), func.count(Policy.policy_no))
        .join(UserSavedPolicy, UserSavedPolicy.policy_no == Policy.policy_no)
        .where(UserSavedPolicy.user_id == user.id)
        .group_by(Policy.large_category)
        .order_by(func.count(Policy.policy_no).desc())
    ).all()
    return MyReportResponse(
        total_active_policies=active,
        matched_policies=matched,
        eligible_policies=eligible,
        saved_policies=saved,
        category_distribution=[CategoryCount(category=category, count=count) for category, count in category_rows],
    )
