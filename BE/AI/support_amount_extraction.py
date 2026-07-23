"""정규식+LLM 하이브리드로 정책 원문에서 지원금액 지급 여부를 판정하는 오프라인 배치.

정답(ground truth)은 `문화정책_라벨링_중앙·서울_코드기준.xlsx`의 '자동판정(인간)' 열
(사람이 실제로 검토·확정한 값) 81건이다. 같은 파일의 '자동판정(참고)' 열은 기존
regex-only 방식의 결과이며, 이 배치가 그 baseline 정확도를 넘기는 것이 목표다.

사용법:
    python AI/support_amount_extraction.py
"""

import json
import os
import re
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import openpyxl
from anthropic import Anthropic
from dotenv import load_dotenv

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from app.schemas.support_amount_extraction import SupportAmountExtraction  # noqa: E402

load_dotenv(Path(__file__).resolve().parent.parent / ".env")

XLSX_PATH = Path(__file__).resolve().parent.parent.parent / "문화정책_라벨링_중앙·서울_코드기준.xlsx"
MODEL = "claude-sonnet-5"

DETERMINATION_RULES = """[판정 기준]
정책 원문을 읽고, 청년 개인(또는 청년 창업기업)에게 실제로 돈이 지급되는지 판정해.

- 있음: 청년 개인/창업기업에게 실제 현금이 지급됨
- 비율기반: 정액이 아니라 비용의 일정 비율(%)을 지원함 (예: 이자 50% 지원, 매칭 적립)
- 없음: 아래 중 하나라도 해당하면 없음
  - 대출/융자/보증 한도 (상환해야 하는 돈이라 지원금이 아님)
  - 사업 전체 예산, 펀드 조성액 (개인에게 지급되는 금액이 아님)
  - 자격조건·심사기준에 등장하는 숫자 (예: 소득 기준, 나이 상한)
  - 시설 이용, 교육, 컨설팅, 공간 대여처럼 현금이 아닌 현물/서비스성 지원

바우처/이용권은 두 종류를 구분해:
  - 구매력형(=있음): 카드/포인트에 총액이 미리 충전되어 지정 카테고리 안에서 본인이 자유롭게
    사고 싶은 걸 고르는 방식. 예: "OO만원 상당 문화이용권(카드) 지급", "전자바우처(카드방식),
    지원품목: 채소류·과일류..." → 개인이 실질적 구매력을 받는 것이므로 있음.
  - 서비스이용형(=없음): 국가가 지정한 전문 서비스 제공기관에 세션 단가를 정산해주는 방식.
    예: "심리상담 서비스 8회, 1회당 OO원, 본인부담금 OO%" → 본인은 서비스를 받을 뿐 돈을
    만지지 않으므로 없음.

지자체 행사(축제·공연·심사위원 모집 등) 공고문처럼 원문에 금액이 전혀 안 나오는 경우는
아래 [판정 예시]를 참고해서 판단해 — 이런 유형은 원문에 안 적혀 있어도 실제로는 사례비/
활동비가 관행적으로 지급되는 경우가 있다.
"""

FEWSHOT_TRAIN_NOS = [
    "20250305005400110593",  # 서울 청년수당 — 있음, 명시적 현금
    "20250609005400110892",  # 자립준비청년 자립수당 지급 — 있음, 매월 현금 계좌이체
    "20250827005400211523",  # 은평청년축제 청년톡톡콘서트 — 있음, 행사 참여(암묵적 사례비)
    "20250819005400211519",  # 버스킹 페스타 판정단 모집 — 있음, 심사 활동(암묵적 심사비)
    "20250317005400210641",  # 청년예술청 운영 — 있음, 프로그램 참가 지원 포함
    "20250519005400210859",  # 서울시 고립·은둔청년 지원사업 — 있음, 개인 대상 지원 프로그램
    "20260421005400112773",  # 미소금융 청년 미래이음 대출 — 없음, 대출(상환 의무)
    "20260415005400112751",  # (복지부) 26년 정신건강 심리상담 바우처사업 — 없음, 서비스이용형 바우처
    "20250121005400110344",  # 2025년 전국민마음투자지원사업 — 없음, 서비스이용형 바우처
    "20250316005400210640",  # 서울청년문화패스 지원 — 있음, 구매력형 바우처(카드)
    "20260430005400113009",  # 청년내일저축계좌 — 비율기반, 정부 매칭 적립
    "20260710005400113257",  # K-패스(K패스) — 비율기반, 요금 환급 비율
]

REGEX_CANDIDATE_PATTERN = re.compile(
    r"\d[\d,]*\s*(?:천|백)?\s*만\s*원|\d[\d,]*\s*원(?!\w)|\d+(?:\.\d+)?\s*%"
)


def find_regex_candidates(text: str) -> list[str]:
    return list(dict.fromkeys(m.strip() for m in REGEX_CANDIDATE_PATTERN.findall(text or "")))


def build_fewshot_block(rows: list[dict]) -> str:
    by_no = {r["policy_no"]: r for r in rows}
    lines = ["[판정 예시] (실제 사람이 검토·확정한 판정 결과)"]
    for i, no in enumerate(FEWSHOT_TRAIN_NOS, start=1):
        r = by_no[no]
        content = (r["raw_content"] or "").strip()
        if len(content) > 350:
            content = content[:350] + "..."
        lines.append(
            f"\n예시 {i}. {r['policy_name']}\n원문: {content}\n→ 판정: {r['ground_truth']}"
        )
    return "\n".join(lines)


# 자동판정(인간) 원본값 대비 사람이 직접 확인해서 정정한 값.
# 20260330005400112329 "자립준비청년 자립수당지원": 원문이 "매월 50만원 지급"으로 다른
# 자립수당 정책(같은 원문 패턴)과 동일한데 정답만 '없음'으로 잘못 입력돼 있었음 → '있음'으로 정정.
GROUND_TRUTH_CORRECTIONS = {
    "20260330005400112329": "있음",
}


def load_labeled_rows() -> list[dict]:
    wb = openpyxl.load_workbook(XLSX_PATH, data_only=True)
    ws = wb["Sheet1"] if "Sheet1" in wb.sheetnames else wb[wb.sheetnames[0]]
    rows = []
    header_row = next(ws.iter_rows(min_row=1, max_row=1, values_only=True))
    idx = {name: i for i, name in enumerate(header_row)}
    for row in ws.iter_rows(min_row=2, values_only=True):
        policy_no = row[idx["정책번호"]]
        if not policy_no:
            continue
        policy_no = str(policy_no)
        ground_truth = GROUND_TRUTH_CORRECTIONS.get(policy_no, row[idx["자동판정(인간)"]])
        rows.append(
            {
                "policy_no": policy_no,
                "policy_name": row[idx["정책명"]],
                "raw_content": row[idx["정책지원내용(원문)"]] or "",
                "baseline": row[idx["자동판정(참고)"]],
                "ground_truth": ground_truth,
            }
        )
    return rows


def build_tool_schema() -> dict:
    schema = SupportAmountExtraction.model_json_schema()
    schema.pop("description", None)
    return {
        "name": "record_support_amount_determination",
        "description": "정책 원문에서 지원금액 지급 여부와 근거를 구조화해서 기록한다.",
        "input_schema": schema,
    }


def extract_one(client: Anthropic, row: dict, system_prompt: str) -> SupportAmountExtraction:
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


def run_batch(system_prompt: str, rows: list[dict], workers: int = 8) -> list[dict]:
    client = Anthropic()
    results = [None] * len(rows)

    def worker(i_row):
        i, row = i_row
        try:
            extraction = extract_one(client, row, system_prompt)
            results[i] = {**row, "predicted": extraction.determination, "extraction": extraction.model_dump(mode="json")}
        except Exception as exc:  # noqa: BLE001
            results[i] = {**row, "predicted": None, "error": str(exc)}

    with ThreadPoolExecutor(max_workers=workers) as pool:
        list(pool.map(worker, enumerate(rows)))
    return results


def score(results: list[dict]) -> tuple[int, int, list[dict]]:
    correct, total, mismatches = 0, 0, []
    for r in results:
        total += 1
        if r["predicted"] == r["ground_truth"]:
            correct += 1
        else:
            mismatches.append(r)
    return correct, total, mismatches


def is_scoreable(ground_truth: str | None) -> bool:
    """'확인 필요'/'확인필요(...)' 류는 정답 자체가 3지선다 밖이라 채점에서 제외한다."""
    return bool(ground_truth) and not ground_truth.startswith("확인")


if __name__ == "__main__":
    out_dir = Path(__file__).resolve().parent / "results"
    out_dir.mkdir(exist_ok=True)

    all_rows = load_labeled_rows()
    scoreable_rows = [r for r in all_rows if is_scoreable(r["ground_truth"])]
    excluded = len(all_rows) - len(scoreable_rows)
    print(f"전체 {len(all_rows)}건 중 '확인 필요'류 {excluded}건 제외 → 채점 대상 {len(scoreable_rows)}건")

    eval_rows = [r for r in scoreable_rows if r["policy_no"] not in FEWSHOT_TRAIN_NOS]
    print(f"few-shot 학습 예시 {len(FEWSHOT_TRAIN_NOS)}건 제외 → held-out 평가셋 {len(eval_rows)}건\n")

    baseline_correct = sum(1 for r in eval_rows if r["baseline"] == r["ground_truth"])
    print(f"[baseline] 자동판정(참고) vs 자동판정(인간) (held-out {len(eval_rows)}건): "
          f"{baseline_correct}/{len(eval_rows)} = {baseline_correct/len(eval_rows):.1%}")

    system_prompt_v1 = (
        "너는 청년정책 원문에서 실제 지원금액 지급 여부를 판정하는 전문가야.\n\n"
        + DETERMINATION_RULES
    )
    print(f"\n[v1] held-out {len(eval_rows)}건 LLM 판정 실행 중 (few-shot 없음)...")
    results_v1 = run_batch(system_prompt_v1, eval_rows)
    correct_v1, total_v1, mismatches_v1 = score(results_v1)
    print(f"[v1] {correct_v1}/{total_v1} = {correct_v1/total_v1:.1%}")
    (out_dir / "v1_results.json").write_text(
        json.dumps(results_v1, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    system_prompt_v2 = (
        "너는 청년정책 원문에서 실제 지원금액 지급 여부를 판정하는 전문가야.\n\n"
        + DETERMINATION_RULES
        + "\n"
        + build_fewshot_block(all_rows)
    )
    print(f"\n[v2] held-out {len(eval_rows)}건 LLM 판정 실행 중 (few-shot {len(FEWSHOT_TRAIN_NOS)}건)...")
    results_v2 = run_batch(system_prompt_v2, eval_rows)
    correct_v2, total_v2, mismatches_v2 = score(results_v2)
    print(f"[v2] {correct_v2}/{total_v2} = {correct_v2/total_v2:.1%}")
    (out_dir / "v2_results.json").write_text(
        json.dumps(results_v2, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    summary = {
        "held_out_size": len(eval_rows),
        "excluded_confirm_needed": excluded,
        "fewshot_train_size": len(FEWSHOT_TRAIN_NOS),
        "baseline_accuracy": baseline_correct / len(eval_rows),
        "v1_accuracy": correct_v1 / total_v1,
        "v2_accuracy": correct_v2 / total_v2,
    }
    (out_dir / "summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"\n요약: {summary}")

    print(f"\n[v2] 오답 {len(mismatches_v2)}건:")
    for m in mismatches_v2:
        print(f"- {m['policy_name']!r}: 예측={m['predicted']} 정답={m['ground_truth']}")
