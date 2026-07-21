from pydantic import BaseModel


class RegionResponse(BaseModel):
    code: str
    name: str
    short_name: str | None = None
    parent_code: str | None = None
    level: str


class RegionPolicyCount(BaseModel):
    region_code: str
    region_name: str
    policy_count: int
