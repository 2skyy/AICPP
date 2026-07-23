import unittest
from datetime import date
from unittest.mock import Mock

from app.services.chat_service import ChatService, _is_open
from app.services.keyword_extractor import extract_topic_keyword


class ExtractTopicKeywordTest(unittest.TestCase):
    def test_finds_a_known_keyword_inside_the_question(self):
        self.assertEqual(extract_topic_keyword("내 지역 청년 주거지원이 궁금해요"), "주거지원")

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

        policy_service.search.assert_called_once_with(topic="주거지원", size=10)
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

        policy_service.search.assert_called_once_with(region="서울특별시", size=10)

    def test_greeting_is_allowed_on_the_first_message_by_default(self):
        policy_service = Mock()
        policy_service.search.return_value = {"result": {"youthPolicyList": []}}
        anthropic_client = Mock()
        anthropic_client.messages.create.return_value = _text_message("안녕!")

        service = ChatService(policy_service, client=anthropic_client)
        service.ask("주거지원이 궁금해요", {"region": "서울특별시"})

        system_prompt = anthropic_client.messages.create.call_args.kwargs["system"]
        self.assertIn("첫 대화니까", system_prompt)

    def test_greeting_is_disabled_for_a_follow_up_message(self):
        policy_service = Mock()
        policy_service.search.return_value = {"result": {"youthPolicyList": []}}
        anthropic_client = Mock()
        anthropic_client.messages.create.return_value = _text_message("확인해드릴게요.")

        service = ChatService(policy_service, client=anthropic_client)
        service.ask("주거지원이 궁금해요", {"region": "서울특별시"}, is_first_message=False)

        system_prompt = anthropic_client.messages.create.call_args.kwargs["system"]
        self.assertIn("인사나 자기소개는 하지 말고", system_prompt)

    def test_strips_markdown_from_the_generated_answer(self):
        policy_service = Mock()
        policy_service.search.return_value = {"result": {"youthPolicyList": []}}
        anthropic_client = Mock()
        anthropic_client.messages.create.return_value = _text_message(
            "### 안내\n**청년월세지원**을 신청해보세요."
        )

        service = ChatService(policy_service, client=anthropic_client)
        result = service.ask("주거지원이 궁금해요", {"region": "서울특별시"})

        self.assertEqual(result["answer"], "안내\n청년월세지원을 신청해보세요.")

    def test_includes_interested_regions_gender_school_gpa_and_income_in_the_system_prompt(self):
        policy_service = Mock()
        policy_service.search.return_value = {"result": {"youthPolicyList": []}}
        anthropic_client = Mock()
        anthropic_client.messages.create.return_value = _text_message("확인해드릴게요.")

        service = ChatService(policy_service, client=anthropic_client)
        service.ask(
            "나에게 맞는 정책 알려줘",
            {
                "region": "서울특별시",
                "interested_regions": ["부산광역시", "경기도"],
                "gender": "여성",
                "school": "한국대학교",
                "gpa": 4.0,
                "income_percent": 85,
            },
        )

        system_prompt = anthropic_client.messages.create.call_args.kwargs["system"]
        self.assertIn("부산광역시, 경기도", system_prompt)
        self.assertIn("여성", system_prompt)
        self.assertIn("한국대학교", system_prompt)
        self.assertIn("4.0", system_prompt)
        self.assertIn("기준중위소득 약 85%", system_prompt)

    def test_includes_scrapped_policies_in_the_system_prompt(self):
        policy_service = Mock()
        policy_service.search.return_value = {"result": {"youthPolicyList": []}}
        anthropic_client = Mock()
        anthropic_client.messages.create.return_value = _text_message("네, 확인해드릴게요.")

        service = ChatService(policy_service, client=anthropic_client)
        service.ask(
            "내가 스크랩한 정책 신청기간 알려줘",
            {
                "region": "서울특별시",
                "scrapped_policies": [
                    {
                        "name": "청년월세지원",
                        "organization": "국토부",
                        "period": "20260101 ~ 20261231",
                        "support_content": "월 20만원 지원",
                    }
                ],
            },
        )

        system_prompt = anthropic_client.messages.create.call_args.kwargs["system"]
        self.assertIn("[스크랩한 정책]", system_prompt)
        self.assertIn("청년월세지원", system_prompt)
        self.assertIn("월 20만원 지원", system_prompt)

    def test_includes_the_apply_url_for_searched_and_scrapped_policies(self):
        policy_service = Mock()
        policy_service.search.return_value = {
            "result": {
                "youthPolicyList": [
                    {
                        "plcyNm": "청년내일캠프",
                        "aplyUrlAddr": "https://example.com/apply",
                    }
                ]
            }
        }
        anthropic_client = Mock()
        anthropic_client.messages.create.return_value = _text_message("확인해드릴게요.")

        service = ChatService(policy_service, client=anthropic_client)
        service.ask(
            "주거지원이 궁금해요",
            {
                "region": "서울특별시",
                "scrapped_policies": [
                    {"name": "청년월세지원", "apply_url": "https://example.com/scrapped"}
                ],
            },
        )

        system_prompt = anthropic_client.messages.create.call_args.kwargs["system"]
        self.assertIn("https://example.com/apply", system_prompt)
        self.assertIn("https://example.com/scrapped", system_prompt)

    def test_notes_no_scrapped_policies_when_the_list_is_empty(self):
        policy_service = Mock()
        policy_service.search.return_value = {"result": {"youthPolicyList": []}}
        anthropic_client = Mock()
        anthropic_client.messages.create.return_value = _text_message("스크랩한 정책이 없어요.")

        service = ChatService(policy_service, client=anthropic_client)
        service.ask("내가 스크랩한 정책 있어?", {"region": "서울특별시"})

        system_prompt = anthropic_client.messages.create.call_args.kwargs["system"]
        self.assertIn("(스크랩한 정책 없음)", system_prompt)


if __name__ == "__main__":
    unittest.main()
