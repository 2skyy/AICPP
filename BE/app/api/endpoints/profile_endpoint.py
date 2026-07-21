from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy import delete, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.auth import CurrentUser, get_current_user
from app.core.database import get_db
from app.models import Region, UserInterestRegion, UserProfile
from app.schemas.profile import (
    InterestRegionsResponse,
    InterestRegionsUpdate,
    ProfileCreate,
    ProfileResponse,
    ProfileUpdate,
)


router = APIRouter(prefix="/api/v1/profile", tags=["v1-profile"])


def _profile_or_404(db: Session, user_id) -> UserProfile:
    profile = db.get(UserProfile, user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Profile not found")
    return profile


@router.post("", response_model=ProfileResponse, status_code=201)
def create_profile(
    body: ProfileCreate,
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UserProfile:
    if db.get(UserProfile, user.id):
        raise HTTPException(status_code=409, detail="Profile already exists")
    profile = UserProfile(id=user.id, **body.model_dump())
    db.add(profile)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=422, detail="Invalid region code or profile value") from exc
    db.refresh(profile)
    return profile


@router.get("", response_model=ProfileResponse)
def get_profile(
    user: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)
) -> UserProfile:
    return _profile_or_404(db, user.id)


@router.patch("", response_model=ProfileResponse)
def update_profile(
    body: ProfileUpdate,
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UserProfile:
    profile = _profile_or_404(db, user.id)
    values = body.model_dump(exclude_unset=True)
    for field, value in values.items():
        setattr(profile, field, value)
    if values:
        profile.profile_version += 1
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=422, detail="Invalid region code or profile value") from exc
    db.refresh(profile)
    return profile


@router.get("/interest-regions", response_model=InterestRegionsResponse)
def get_interest_regions(
    user: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)
) -> InterestRegionsResponse:
    codes = db.scalars(
        select(UserInterestRegion.region_code)
        .where(UserInterestRegion.user_id == user.id)
        .order_by(UserInterestRegion.created_at)
    ).all()
    return InterestRegionsResponse(region_codes=list(codes))


@router.patch("/interest-regions", response_model=InterestRegionsResponse)
def replace_interest_regions(
    body: InterestRegionsUpdate,
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> InterestRegionsResponse:
    _profile_or_404(db, user.id)
    codes = list(dict.fromkeys(body.region_codes))
    known = set(db.scalars(select(Region.code).where(Region.code.in_(codes))).all()) if codes else set()
    unknown = [code for code in codes if code not in known]
    if unknown:
        raise HTTPException(status_code=422, detail={"unknown_region_codes": unknown})
    db.execute(delete(UserInterestRegion).where(UserInterestRegion.user_id == user.id))
    db.add_all(UserInterestRegion(user_id=user.id, region_code=code) for code in codes)
    db.commit()
    return InterestRegionsResponse(region_codes=codes)


@router.delete("/interest-regions", status_code=204)
def delete_interest_regions(
    user: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)
) -> Response:
    db.execute(delete(UserInterestRegion).where(UserInterestRegion.user_id == user.id))
    db.commit()
    return Response(status_code=204)
