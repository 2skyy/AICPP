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
    func,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class UserProfile(Base):
    __tablename__ = "user_profiles"
    __table_args__ = (
        CheckConstraint("gpa IS NULL OR (gpa >= 0 AND gpa <= 4.5)", name="gpa"),
        CheckConstraint("annual_income_amount IS NULL OR annual_income_amount >= 0", name="income"),
        CheckConstraint("median_income_ratio IS NULL OR median_income_ratio >= 0", name="income_ratio"),
        CheckConstraint("household_member_count IS NULL OR household_member_count >= 1", name="household"),
        CheckConstraint("profile_version >= 1", name="profile_version"),
        CheckConstraint("frog_progress BETWEEN 0 AND 100", name="frog_progress"),
        {"schema": "public"},
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("auth.users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    name: Mapped[str | None] = mapped_column(Text)
    profile_image_url: Mapped[str | None] = mapped_column(Text)
    birth_date: Mapped[date | None] = mapped_column(Date)
    gender_code: Mapped[str | None] = mapped_column(String(20))
    residence_region_code: Mapped[str | None] = mapped_column(
        ForeignKey("public.regions.code", ondelete="SET NULL"), index=True
    )
    origin_region_code: Mapped[str | None] = mapped_column(
        ForeignKey("public.regions.code", ondelete="SET NULL"), index=True
    )
    school_name: Mapped[str | None] = mapped_column(Text)
    gpa: Mapped[Decimal | None] = mapped_column(Numeric(3, 2))
    major_code: Mapped[str | None] = mapped_column(String(30))
    education_status_code: Mapped[str | None] = mapped_column(String(30))
    employment_status_code: Mapped[str | None] = mapped_column(String(30))
    marital_status_code: Mapped[str | None] = mapped_column(String(30))
    military_service_status_code: Mapped[str | None] = mapped_column(String(30))
    homeownership_status_code: Mapped[str | None] = mapped_column(String(30))
    annual_income_amount: Mapped[int | None] = mapped_column(BigInteger)
    median_income_ratio: Mapped[Decimal | None] = mapped_column(Numeric(6, 2))
    household_member_count: Mapped[int | None] = mapped_column(SmallInteger)
    income_standard_year: Mapped[int | None] = mapped_column(SmallInteger)
    income_calculated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    profile_version: Mapped[int] = mapped_column(Integer, nullable=False, server_default="1")
    profile_completed: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="false")
    frog_progress: Mapped[int] = mapped_column(SmallInteger, nullable=False, server_default="0")
    frog_stage: Mapped[str] = mapped_column(String(20), nullable=False, server_default="EGG")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now())


class UserInterestRegion(Base):
    __tablename__ = "user_interest_regions"
    __table_args__ = ({"schema": "public"},)

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("public.user_profiles.id", ondelete="CASCADE"), primary_key=True
    )
    region_code: Mapped[str] = mapped_column(
        ForeignKey("public.regions.code", ondelete="CASCADE"), primary_key=True, index=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
