import uuid
from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, Field
from app.schemas.common import ORMModel


class ProfileFields(BaseModel):
    name: str | None = None
    profile_image_url: str | None = None
    birth_date: date | None = None
    gender_code: str | None = None
    residence_region_code: str | None = None
    origin_region_code: str | None = None
    school_name: str | None = None
    gpa: Decimal | None = Field(default=None, ge=0, le=4.5)
    major_code: str | None = None
    education_status_code: str | None = None
    employment_status_code: str | None = None
    marital_status_code: str | None = None
    military_service_status_code: str | None = None
    homeownership_status_code: str | None = None
    annual_income_amount: int | None = Field(default=None, ge=0)
    median_income_ratio: Decimal | None = Field(default=None, ge=0)
    household_member_count: int | None = Field(default=None, ge=1)
    income_standard_year: int | None = None
    profile_completed: bool = False
    frog_progress: int = Field(default=0, ge=0, le=100)
    frog_stage: str = "EGG"


class ProfileCreate(ProfileFields):
    pass


class ProfileUpdate(BaseModel):
    name: str | None = None
    profile_image_url: str | None = None
    birth_date: date | None = None
    gender_code: str | None = None
    residence_region_code: str | None = None
    origin_region_code: str | None = None
    school_name: str | None = None
    gpa: Decimal | None = Field(default=None, ge=0, le=4.5)
    major_code: str | None = None
    education_status_code: str | None = None
    employment_status_code: str | None = None
    marital_status_code: str | None = None
    military_service_status_code: str | None = None
    homeownership_status_code: str | None = None
    annual_income_amount: int | None = Field(default=None, ge=0)
    median_income_ratio: Decimal | None = Field(default=None, ge=0)
    household_member_count: int | None = Field(default=None, ge=1)
    income_standard_year: int | None = None
    profile_completed: bool | None = None
    frog_progress: int | None = Field(default=None, ge=0, le=100)
    frog_stage: str | None = None


class ProfileResponse(ProfileFields, ORMModel):
    id: uuid.UUID
    profile_version: int
    created_at: datetime
    updated_at: datetime


class InterestRegionsUpdate(BaseModel):
    region_codes: list[str] = Field(default_factory=list, max_length=20)


class InterestRegionsResponse(BaseModel):
    region_codes: list[str]
