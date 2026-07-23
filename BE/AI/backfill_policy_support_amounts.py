"""전체 2,646건 정책에 support_amount_extraction.py의 v2(규칙+few-shot) 판정을 돌려
policy_support_amounts 테이블을 채운다.

주의: 이 배치는 amount_krw/amount_type/amount_percent/confidence/evidence/source/note/
extracted_at만 갱신하고 verification_status는 건드리지 않는다(기본값 PENDING 유지).
LLM 추출일 뿐 사람 검토가 아니므로, README 원칙("사람 검토까지 마친 값만 화면에 노출")에
따라 policy_amount_service.py는 사람이 verification_status를 VERIFIED로 바꾸기 전까지는
여전히 policies 테이블을 봐야 한다.

사용법:
    python AI/backfill_policy_support_amounts.py
"""

import sys
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import create_engine, text

sys.path.insert(0, str(Path(__file__).resolve().parent))
from support_amount_extraction import (  # noqa: E402
    DETERMINATION_RULES,
    build_fewshot_block,
    build_tool_schema,
    find_regex_candidates,
    load_labeled_rows,
)

import os  # noqa: E402

from anthropic import Anthropic  # noqa: E402

from app.schemas.support_amount_extraction import SupportAmountExtraction  # noqa: E402

load_dotenv(Path(__file__).resolve().parent.parent / ".env")
MODEL = "claude-sonnet-5"


def load_all_policies() -> list[dict]:
    engine = create_engine(os.environ["DB_URL"])
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                """
                SELECT ap.policy_no, ap.policy_name, ap.support_content
                FROM public.arranged_policies ap
                WHERE ap.support_content IS NOT NULL AND length(trim(ap.support_content)) > 0
                  AND NOT EXISTS (
                      SELECT 1 FROM public.policy_support_amounts psa
                      WHERE psa.policy_no = ap.policy_no AND psa.source = 'LLM'
                  )
                """
            )
        )
        return [
            {"policy_no": r.policy_no, "policy_name": r.policy_name, "raw_content": r.support_content}
            for r in rows
        ]


def extract_one(client: Anthropic, row: dict, system_prompt: str) -> SupportAmountExtraction | None:
    candidates = find_regex_candidates(row["raw_content"])
    user_content = (
        f"[정책명]\n{row['policy_name']}\n\n"
        f"[정책지원내용 원문]\n{row['raw_content']}\n\n"
        f"[정규식으로 찾은 숫자 후보 (참고용, 그대로 믿지 말고 문맥으로 판단할 것)]\n"
        f"{', '.join(candidates) if candidates else '(없음)'}"
    )
    message = client.messages.create(
        model=MODEL,
        max_tokens=1024,
        system=system_prompt,
        tools=[build_tool_schema()],
        tool_choice={"type": "tool", "name": "record_support_amount_determination"},
        messages=[{"role": "user", "content": user_content}],
    )
    tool_use = next(b for b in message.content if b.type == "tool_use")
    return SupportAmountExtraction.model_validate(tool_use.input)


def upsert(engine, rows_with_extraction: list[tuple[dict, SupportAmountExtraction]]) -> None:
    now = datetime.now(timezone.utc)
    payload = []
    for row, extraction in rows_with_extraction:
        amount_type = None
        amount_krw = None
        amount_percent = None
        if extraction.determination == "있음":
            amount_type = "고정금액"
            amount_krw = extraction.amount_krw
        elif extraction.determination == "확인필요":
            amount_type = "확인필요"
            amount_percent = extraction.amount_percent
        payload.append(
            {
                "policy_no": row["policy_no"],
                "amount_krw": amount_krw,
                "amount_type": amount_type,
                "amount_percent": amount_percent,
                "confidence": extraction.confidence,
                "evidence": extraction.evidence,
                "source": "LLM",
                "note": extraction.note,
                "extracted_at": now,
            }
        )
    with engine.begin() as conn:
        conn.execute(
            text(
                """
                INSERT INTO public.policy_support_amounts
                    (policy_no, amount_krw, amount_type, amount_percent, confidence,
                     evidence, source, note, extracted_at)
                VALUES
                    (:policy_no, :amount_krw, :amount_type, :amount_percent, :confidence,
                     :evidence, :source, :note, :extracted_at)
                ON CONFLICT (policy_no) DO UPDATE SET
                    amount_krw = EXCLUDED.amount_krw,
                    amount_type = EXCLUDED.amount_type,
                    amount_percent = EXCLUDED.amount_percent,
                    confidence = EXCLUDED.confidence,
                    evidence = EXCLUDED.evidence,
                    source = EXCLUDED.source,
                    note = EXCLUDED.note,
                    extracted_at = EXCLUDED.extracted_at
                """
            ),
            payload,
        )


if __name__ == "__main__":
    engine = create_engine(os.environ["DB_URL"])
    policies = load_all_policies()
    print(f"대상 정책 {len(policies)}건")

    labeled_rows = load_labeled_rows()
    system_prompt = (
        "너는 청년정책 원문에서 실제 지원금액 지급 여부를 판정하는 전문가야.\n\n"
        + DETERMINATION_RULES
        + "\n"
        + build_fewshot_block(labeled_rows)
    )

    client = Anthropic()
    BATCH = 50
    done = 0
    errors = 0
    for start in range(0, len(policies), BATCH):
        chunk = policies[start : start + BATCH]
        results: list[tuple[dict, SupportAmountExtraction] | None] = [None] * len(chunk)

        def worker(i_row):
            i, row = i_row
            try:
                extraction = extract_one(client, row, system_prompt)
                results[i] = (row, extraction)
            except Exception as exc:  # noqa: BLE001
                print(f"  오류 {row['policy_no']} {row['policy_name']!r}: {exc}")
                results[i] = None

        with ThreadPoolExecutor(max_workers=10) as pool:
            list(pool.map(worker, enumerate(chunk)))

        valid = [r for r in results if r is not None]
        errors += len(chunk) - len(valid)
        if valid:
            upsert(engine, valid)
        done += len(chunk)
        print(f"진행: {done}/{len(policies)} (누적 오류 {errors})")

    print(f"완료. 총 {len(policies)}건 중 {len(policies) - errors}건 반영, {errors}건 오류.")
