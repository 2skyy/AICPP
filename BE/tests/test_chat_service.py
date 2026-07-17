import unittest
from datetime import date
from unittest.mock import Mock

from app.services.chat_service import ChatService, _is_open
from app.services.keyword_extractor import extract_topic_keyword


class ExtractTopicKeywordTest(unittest.TestCase):
    def test_finds_a_known_keyword_inside_the_question(self):
        self.assertEqual(extract_topic_keyword("내 지역 청년 주거지원이 궁금해요"), "주거")

    def test_returns_none_when_no_known_keyword_is_present(self):
        self.assertIsNone(extract_topic_keyword("나이 조건에 맞는 정책 알려줘"))


class IsOpenTest(unittest.TestCase):
    def test_true_when_apply_period_is_missing(self):
        self.assertTrue(_is_open({}, date(2026, 7, 15)))

    def test_false_once_deadline_has_passed(self):
        item = {"aplyYmd": "20200101 ~ 20200131"}
        self.assertFalse(_is_open(item, date(2026, 7, 15)))

    def test_false_before_apply_period_opens(self):
        item = {"aplyYmd": "20300101 ~ 20300131"}
        self.assertFalse(_is_open(item, date(2026, 7, 15)))


def _text_message(text: str) -> Mock:
    message = Mock()
    block = Mock()
    block.type = "text"
    block.text = text
    message.content = [block]
    return message


class ChatServiceTest(unittest.TestCase):
    def test_searches_by_topic_keyword_and_answers_using_only_open_policies(self):
        policy_service = Mock()
        policy_service.search.return_value = {
            "result": {
                "youthPolicyList": [
                    {"plcyNm": "청년월세지원", "aplyYmd": "20260101 ~ 20261231"},
                    {"plcyNm": "마감된 정책", "aplyYmd": "20200101 ~ 20200131"},
                ]
            }
        }
        anthropic_client = Mock()
        anthropic_client.messages.create.return_value = _text_message("주거지원 정책을 안내해드릴게요.")

        service = ChatService(policy_service, client=anthropic_client)
        result = service.ask(
            "주거지원이 궁금해요",
            {"region": "서울특별시", "enrollment_status": "재학", "age": 26},
        )

        policy_service.search.assert_called_once_with(topic="주거", size=10)
        self.assertEqual(result["answer"], "주거지원 정책을 안내해드릴게요.")
        self.assertEqual(result["policies"], [{"name": "청년월세지원", "period": "20260101 ~ 20261231"}])

        system_prompt = anthropic_client.messages.create.call_args.kwargs["system"]
        self.assertIn("청년월세지원", system_prompt)
        self.assertNotIn("마감된 정책", system_prompt)
        self.assertIn("서울특별시", system_prompt)

    def test_falls_back_to_region_search_when_no_keyword_is_found(self):
        policy_service = Mock()
        policy_service.search.return_value = {"result": {"youthPolicyList": []}}
        anthropic_client = Mock()
        anthropic_client.messages.create.return_value = _text_message("조건에 맞는 정책을 찾지 못했어요.")

        service = ChatService(policy_service, client=anthropic_client)
        service.ask("나이 조건에 맞는 정책 알려줘", {"region": "서울특별시"})

        policy_service.search.assert_called_once_with(name="서울특별시", size=10)


if __name__ == "__main__":
    unittest.main()
