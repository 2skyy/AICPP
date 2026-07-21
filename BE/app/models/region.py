from sqlalchemy import CheckConstraint, ForeignKey, SmallInteger, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class Region(Base):
    __tablename__ = "regions"
    __table_args__ = (
        CheckConstraint("level IN ('SIDO', 'SIGUNGU')", name="level"),
        {"schema": "public"},
    )

    code: Mapped[str] = mapped_column(String(20), primary_key=True)
    name: Mapped[str] = mapped_column(Text, nullable=False)
    short_name: Mapped[str | None] = mapped_column(Text)
    parent_code: Mapped[str | None] = mapped_column(
        ForeignKey("public.regions.code", ondelete="RESTRICT"), index=True
    )
    level: Mapped[str] = mapped_column(String(10), nullable=False)
    sort_order: Mapped[int] = mapped_column(SmallInteger, nullable=False, server_default="0")
