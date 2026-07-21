from pydantic import BaseModel


class CategoryCount(BaseModel):
    category: str
    count: int


class MyReportResponse(BaseModel):
    total_active_policies: int
    matched_policies: int
    eligible_policies: int
    saved_policies: int
    category_distribution: list[CategoryCount]
