from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models import Policy, PolicyRegion, Region
from app.schemas.region import RegionPolicyCount, RegionResponse


router = APIRouter(prefix="/api/v1", tags=["v1-regions"])


@router.get("/regions", response_model=list[RegionResponse])
def list_regions(level: str | None = None, db: Session = Depends(get_db)):
    statement = select(Region)
    if level:
        statement = statement.where(Region.level == level.upper())
    return db.scalars(statement.order_by(Region.sort_order, Region.name)).all()


@router.get("/map/regions", response_model=list[RegionPolicyCount])
def region_policy_counts(db: Session = Depends(get_db)) -> list[RegionPolicyCount]:
    rows = db.execute(
        select(Region.code, Region.name, func.count(Policy.policy_no))
        .outerjoin(PolicyRegion, PolicyRegion.region_code == Region.code)
        .outerjoin(Policy, (Policy.policy_no == PolicyRegion.policy_no) & Policy.is_active)
        .where(Region.level == "SIDO")
        .group_by(Region.code, Region.name, Region.sort_order)
        .order_by(Region.sort_order, Region.name)
    ).all()
    return [RegionPolicyCount(region_code=code, region_name=name, policy_count=count) for code, name, count in rows]


@router.get("/map/regions/{region_code}/children", response_model=list[RegionPolicyCount])
def region_children(region_code: str, db: Session = Depends(get_db)) -> list[RegionPolicyCount]:
    if db.get(Region, region_code) is None:
        raise HTTPException(status_code=404, detail="Region not found")
    rows = db.execute(
        select(Region.code, Region.name, func.count(Policy.policy_no))
        .outerjoin(PolicyRegion, PolicyRegion.region_code == Region.code)
        .outerjoin(Policy, (Policy.policy_no == PolicyRegion.policy_no) & Policy.is_active)
        .where(Region.parent_code == region_code)
        .group_by(Region.code, Region.name, Region.sort_order)
        .order_by(Region.sort_order, Region.name)
    ).all()
    return [RegionPolicyCount(region_code=code, region_name=name, policy_count=count) for code, name, count in rows]
