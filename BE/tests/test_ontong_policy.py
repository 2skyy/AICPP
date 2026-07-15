import unittest
from unittest.mock import Mock, patch

from app.api.clients.ontong_policy import OntongPolicyClient
from app.services.ontong_policy_service import OntongPolicyService


class OntongPolicyClientTest(unittest.TestCase):
    @patch("app.api.clients.ontong_policy.requests.Session")
    def test_uses_official_url_and_api_key_parameter(self, mock_session):
        response = Mock()
        response.is_redirect = False
        response.json.return_value = {"result": "ok"}
        session = mock_session.return_value.__enter__.return_value
        session.get.return_value = response
        client = OntongPolicyClient(api_key="test-key")

        result = client.get_policies(query="청년취업")

        self.assertEqual(result, {"result": "ok"})
        self.assertFalse(session.trust_env)
        session.get.assert_called_once_with(
            "https://www.youthcenter.go.kr/go/ythip/getPlcy",
            params={"apiKeyNm": "test-key", "query": "청년취업"},
            timeout=10,
            allow_redirects=False,
        )
        response.raise_for_status.assert_called_once()

    def test_requires_api_key(self):
        client = OntongPolicyClient(api_key=None)
        client.api_key = None

        with self.assertRaises(RuntimeError):
            client.get_policies()


class OntongPolicyServiceTest(unittest.TestCase):
    def test_converts_lists_to_api_query_parameters(self):
        client = Mock()
        client.get_policies.return_value = {"items": []}
        service = OntongPolicyService(client)

        result = service.search(
            query="청년취업",
            keywords=["채용", "구직"],
            business_types=["023010", "023020"],
            region_codes=["003002001"],
            page=2,
            size=20,
        )

        self.assertEqual(result, {"items": []})
        client.get_policies.assert_called_once_with(
            pageNum=2,
            pageSize=20,
            rtnType="json",
            query="청년취업",
            plcyNm=None,
            plcyKywdNm=None,
            keyword="채용,구직",
            bizTycdSel="023010,023020",
            srchPolyBizSecd="003002001",
        )

    def test_maps_name_to_plcyNm(self):
        client = Mock()
        client.get_policies.return_value = {"items": []}
        service = OntongPolicyService(client)

        service.search(name="서울", page=1, size=1)

        client.get_policies.assert_called_once_with(
            pageNum=1,
            pageSize=1,
            rtnType="json",
            query=None,
            plcyNm="서울",
            plcyKywdNm=None,
            keyword=None,
            bizTycdSel=None,
            srchPolyBizSecd=None,
        )

    def test_maps_topic_to_plcyKywdNm(self):
        client = Mock()
        client.get_policies.return_value = {"items": []}
        service = OntongPolicyService(client)

        service.search(topic="주거", page=1, size=1)

        client.get_policies.assert_called_once_with(
            pageNum=1,
            pageSize=1,
            rtnType="json",
            query=None,
            plcyNm=None,
            plcyKywdNm="주거",
            keyword=None,
            bizTycdSel=None,
            srchPolyBizSecd=None,
        )


if __name__ == "__main__":
    unittest.main()
