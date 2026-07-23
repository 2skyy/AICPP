"""문화정책_라벨링_중앙·서울_코드기준.xlsx의 사람 확정 판정(자동판정(인간), 정정 반영)을
policy_support_amounts에 반영해 verification_status를 VERIFIED로 올린다.

사람은 있음/없음/확인필요 "분류"만 확정했고 구체적인 원 단위 금액까지 검토한 건 아니다.
그래서:
  - LLM이 이미 뽑아둔 amount_type이 사람 분류와 같으면: 그 금액은 그대로 두고 상태만 VERIFIED로.
  - 다르면: amount_type을 사람 분류로 정정하고, 검증 안 된 금액(amount_krw/percent)은 비워서
    "분류는 확정, 금액은 미상"으로 남긴다 — 틀린 숫자를 확정치처럼 두지 않기 위함.

사용법:
    python AI/apply_human_verified_labels.py
"""

import sys
from datetime import datetime, timezone
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import create_engine, text

sys.path.insert(0, str(Path(__file__).resolve().parent))
from support_amount_extraction import load_labeled_rows  # noqa: E402

import os  # noqa: E402

load_dotenv(Path(__file__).resolve().parent.parent / ".env")

TARGET_TYPE = {"있음": "고정금액", "확인필요": "확인필요", "없음": None}


if __name__ == "__main__":
    engine = create_engine(os.environ["DB_URL"])
    now = datetime.now(timezone.utc)

    scoreable = load_labeled_rows()
    nos = [r["policy_no"] for r in scoreable]

    with engine.connect() as conn:
        current = {
            r.policy_no: r
            for r in conn.execute(
                text(
                    "SELECT policy_no, amount_type FROM public.policy_support_amounts "
                    "WHERE policy_no = ANY(:nos)"
                ),
                {"nos": nos},
            )
        }

    matched_payload, mismatch_payload = [], []
    for r in scoreable:
        want = TARGET_TYPE[r["ground_truth"]]
        c = current.get(r["policy_no"])
        if c is not None and c.amount_type == want:
            matched_payload.append({"policy_no": r["policy_no"], "now": now})
        else:
            mismatch_payload.append({"policy_no": r["policy_no"], "amount_type": want, "now": now})

    with engine.begin() as conn:
        if matched_payload:
            conn.execute(
                text(
                    """
                    UPDATE public.policy_support_amounts
                    SET verification_status = 'VERIFIED',
                        verified_at = :now,
                        source = '사람검토(문화라벨링)',
                        note = COALESCE(note, '') ||
                               CASE WHEN note IS NOT NULL AND note <> '' THEN ' / ' ELSE '' END ||
                               '사람이 있음/없음/확인필요 분류 확인함(구체 금액은 LLM 추출값 유지)'
                    WHERE policy_no = :policy_no
                    """
                ),
                matched_payload,
            )
        if mismatch_payload:
            conn.execute(
                text(
                    """
                    UPDATE public.policy_support_amounts
                    SET amount_type = :amount_type,
                        amount_krw = NULL,
                        amount_percent = NULL,
                        verification_status = 'VERIFIED',
                        verified_at = :now,
                        source = '사람검토(문화라벨링)',
                        note = '사람 검토로 분류(있음/없음/확인필요)만 확정, 구체 금액은 미상 — 추가 확인 필요'
                    WHERE policy_no = :policy_no
                    """
                ),
                mismatch_payload,
            )

    print(f"일치분 확정: {len(matched_payload)}건, 정정 후 확정: {len(mismatch_payload)}건")
