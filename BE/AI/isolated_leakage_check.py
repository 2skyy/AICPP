"""사용자가 제안한 방식대로, few-shot 12건과 문항 원문만으로 프롬프트를 만들고
(1) 문항의 정책번호가 프롬프트 어디에도 없는지 문자열로 직접 assert하고
(2) 매 건 새 API 호출로(대화 이력 없이) held-out 63건을 독립적으로 재판정한다.

model 오타(claude-sonnet-4-6)는 claude-sonnet-5로 고쳤다 — 존재하지 않는 모델명으로
호출하면 이 스크립트가 곧바로 에러를 던지도록 그대로 뒀다(조용히 넘어가지 않게).

사용법:
    python AI/isolated_leakage_check.py
"""

import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from anthropic import Anthropic
from dotenv import load_dotenv

sys.path.insert(0, str(Path(__file__).resolve().parent))
from support_amount_extraction import (  # noqa: E402
    DETERMINATION_RULES,
    FEWSHOT_TRAIN_NOS,
    build_fewshot_block,
    build_tool_schema,
    find_regex_candidates,
    load_labeled_rows,
)

from app.schemas.support_amount_extraction import SupportAmountExtraction  # noqa: E402

load_dotenv(Path(__file__).resolve().parent.parent / ".env")
MODEL = "claude-sonnet-5"  # 원래 스니펫의 claude-sonnet-4-6은 존재하지 않는 모델명


def build_prompt(fewshot_rows: list[dict], item: dict) -> tuple[str, str]:
    system_prompt = (
        "너는 청년정책 원문에서 실제 지원금액 지급 여부를 판정하는 전문가야.\n\n"
        + DETERMINATION_RULES
        + "\n"
        + build_fewshot_block(fewshot_rows)
    )
    candidates = find_regex_candidates(item["raw_content"])
    user_content = (
        f"[정책명]\n{item['policy_name']}\n\n"
        f"[정책지원내용 원문]\n{item['raw_content']}\n\n"
        f"[정규식으로 찾은 숫자 후보 (참고용, 그대로 믿지 말고 문맥으로 판단할 것)]\n"
        f"{', '.join(candidates) if candidates else '(없음)'}"
    )
    return system_prompt, user_content


if __name__ == "__main__":
    all_rows = load_labeled_rows()
    held_out = [r for r in all_rows if r["policy_no"] not in FEWSHOT_TRAIN_NOS]
    print(f"held-out {len(held_out)}건, few-shot {len(FEWSHOT_TRAIN_NOS)}건")

    client = Anthropic()
    results = [None] * len(held_out)

    def worker(i_item):
        i, item = i_item
        system_prompt, user_content = build_prompt(all_rows, item)
        full_prompt = system_prompt + "\n" + user_content

        # 사용자가 제안한 누출 검사: 이 문항의 정책번호가 프롬프트 어디에도 없어야 한다.
        assert item["policy_no"] not in full_prompt, f"정책번호 누출: {item['policy_no']}"

        message = client.messages.create(
            model=MODEL,
            max_tokens=1024,
            system=system_prompt,
            tools=[build_tool_schema()],
            tool_choice={"type": "tool", "name": "record_support_amount_determination"},
            messages=[{"role": "user", "content": user_content}],  # 매 건 새 호출, 이력 없음
        )
        tool_use = next(b for b in message.content if b.type == "tool_use")
        extraction = SupportAmountExtraction.model_validate(tool_use.input)
        results[i] = {
            "policy_no": item["policy_no"],
            "policy_name": item["policy_name"],
            "predicted": extraction.determination,
            "ground_truth": item["ground_truth"],
        }

    with ThreadPoolExecutor(max_workers=8) as pool:
        list(pool.map(worker, enumerate(held_out)))

    correct = sum(1 for r in results if r["predicted"] == r["ground_truth"])
    print(f"\n결과: {correct}/{len(results)} = {correct/len(results):.1%}")
    print("\n오답:")
    for r in results:
        if r["predicted"] != r["ground_truth"]:
            print(f"- {r['policy_name']!r}: 예측={r['predicted']} 정답={r['ground_truth']}")
