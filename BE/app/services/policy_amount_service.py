import os
from functools import lru_cache

from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError


class PolicyAmountService:
    """정책지원금액 추출 파이프라인이 Supabase에 적재한 정확한 지원금액을 조회한다.

    오프라인 배치(정규식+LLM+사람 검토)로 뽑은 값이라 온통청년 API의 실시간
    응답보다 정확하지만, 스냅샷이라 최신 정책은 아직 없을 수 있다. 그래서
    조회 실패/미스매치는 예외를 던지지 않고 빈 결과로 처리해서, 호출부가
    항상 온통청년 응답을 그대로 보여줄 수 있게(하이브리드) 한다.
    """

    def __init__(self, db_url: str | None = None):
        url = db_url if db_url is not None else os.environ.get("DB_URL")
        self.engine = create_engine(url) if url else None

    def amounts_for(self, policy_numbers: list[str]) -> dict[str, dict]:
        if not self.engine or not policy_numbers:
            return {}
        try:
            with self.engine.connect() as conn:
                rows = conn.execute(
                    text(
                        """
                        SELECT plcy_no, sprt_amt_krw, sprt_amt_type, sprt_amt_pct,
                               sprt_amt_confidence, sprt_amt_evidence, sprt_amt_source,
                               sprt_amt_note
                        FROM policies
                        WHERE plcy_no = ANY(:nos)
                        """
                    ),
                    {"nos": policy_numbers},
                )
                return {row.plcy_no: dict(row._mapping) for row in rows}
        except SQLAlchemyError:
            return {}


@lru_cache
def get_shared_policy_amount_service() -> PolicyAmountService:
    """앱 전체가 공유하는 단일 인스턴스(=단일 커넥션 풀)를 반환한다.

    요청마다 새 PolicyAmountService()를 만들면 그때마다 Supabase에 새 커넥션을
    맺어야 해서(~2초) 매 요청이 느려진다. lru_cache로 프로세스 생애주기 동안
    하나만 만들어서, 정책 검색 엔드포인트와 챗봇 엔드포인트가 모두 이 인스턴스를
    공유하도록 한다. (main.py가 load_dotenv()를 먼저 실행한 뒤 첫 요청이 와야
    이 함수가 처음 호출되므로 DB_URL이 이미 로드되어 있음이 보장된다.)
    """
    return PolicyAmountService()


__all__ = ["PolicyAmountService", "get_shared_policy_amount_service"]
