import unittest
from unittest.mock import Mock, patch

from app.api.clients.news_api import NewsApiClient
from app.services.news_service import NewsRecommendationService


class NewsApiClientTest(unittest.TestCase):
    @patch("app.api.clients.news_api.requests.Session")
    def test_searches_with_korean_language_and_api_key(self, mock_session):
        response = Mock()
        response.json.return_value = {"status": "ok", "articles": [{"title": "기사"}]}
        session = mock_session.return_value.__enter__.return_value
        session.get.return_value = response
        client = NewsApiClient(api_key="test-key")

        articles = client.search('"주거" OR "취업"', page_size=10)

        self.assertEqual(articles, [{"title": "기사"}])
        session.get.assert_called_once_with(
            "https://newsapi.org/v2/everything",
            params={
                "q": '"주거" OR "취업"',
                "language": "ko",
                "sortBy": "publishedAt",
                "pageSize": 10,
                "apiKey": "test-key",
            },
            timeout=10,
        )

    def test_requires_api_key(self):
        client = NewsApiClient(api_key=None)
        client.api_key = None

        with self.assertRaises(RuntimeError):
            client.search("주거")


def _text_message(text: str) -> Mock:
    message = Mock()
    block = Mock()
    block.type = "text"
    block.text = text
    message.content = [block]
    return message


class NewsRecommendationServiceTest(unittest.TestCase):
    def test_returns_empty_list_without_calling_apis_when_no_interests(self):
        news_client = Mock()
        anthropic_client = Mock()
        service = NewsRecommendationService(news_client, client=anthropic_client)

        result = service.recommend([])

        self.assertEqual(result, [])
        news_client.search.assert_not_called()
        anthropic_client.messages.create.assert_not_called()

    def test_maps_claude_picks_back_to_original_articles_only(self):
        news_client = Mock()
        news_client.search.return_value = [
            {
                "title": "청년 월세 지원 확대",
                "url": "https://news.example.com/1",
                "source": {"name": "뉴스원"},
                "publishedAt": "2026-07-10T00:00:00Z",
                "description": "월세 지원 소식",
            },
            {
                "title": "날씨 소식",
                "url": "https://news.example.com/2",
                "source": {"name": "뉴스투"},
                "publishedAt": "2026-07-11T00:00:00Z",
                "description": "오늘의 날씨",
            },
        ]
        anthropic_client = Mock()
        anthropic_client.messages.create.return_value = _text_message(
            '[{"index": 0, "reason": "관심사인 주거와 관련된 기사예요."}]'
        )

        service = NewsRecommendationService(news_client, client=anthropic_client)
        result = service.recommend(["주거"])

        news_client.search.assert_called_once_with('"주거"', page_size=20)
        self.assertEqual(
            result,
            [
                {
                    "title": "청년 월세 지원 확대",
                    "url": "https://news.example.com/1",
                    "source": "뉴스원",
                    "publishedAt": "2026-07-10T00:00:00Z",
                    "reason": "관심사인 주거와 관련된 기사예요.",
                }
            ],
        )

    def test_ignores_out_of_range_or_malformed_picks(self):
        news_client = Mock()
        news_client.search.return_value = [{"title": "기사", "url": "u", "source": {"name": "s"}}]
        anthropic_client = Mock()
        anthropic_client.messages.create.return_value = _text_message(
            'Here you go: [{"index": 5, "reason": "범위 밖"}, {"reason": "인덱스 없음"}]'
        )

        service = NewsRecommendationService(news_client, client=anthropic_client)
        result = service.recommend(["주거"])

        self.assertEqual(result, [])


if __name__ == "__main__":
    unittest.main()
