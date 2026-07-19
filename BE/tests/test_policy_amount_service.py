import unittest
from unittest.mock import MagicMock, patch

from app.services.policy_amount_service import PolicyAmountService


class PolicyAmountServiceTest(unittest.TestCase):
    def test_returns_empty_without_querying_when_no_db_url_is_configured(self):
        service = PolicyAmountService(db_url=None)

        self.assertEqual(service.amounts_for(["A1"]), {})

    def test_returns_empty_without_querying_when_policy_numbers_is_empty(self):
        service = PolicyAmountService(db_url="postgresql+psycopg://example")

        self.assertEqual(service.amounts_for([]), {})

    @patch("app.services.policy_amount_service.create_engine")
    def test_queries_by_plcy_no_and_keys_results_by_plcy_no(self, mock_create_engine):
        row = MagicMock()
        row.plcy_no = "A1"
        row._mapping = {"plcy_no": "A1", "sprt_amt_krw": 3000000}
        connection = MagicMock()
        connection.execute.return_value = [row]
        mock_create_engine.return_value.connect.return_value.__enter__.return_value = connection

        service = PolicyAmountService(db_url="postgresql+psycopg://example")
        result = service.amounts_for(["A1"])

        self.assertEqual(result, {"A1": {"plcy_no": "A1", "sprt_amt_krw": 3000000}})
        params = connection.execute.call_args.args[1]
        self.assertEqual(params, {"nos": ["A1"]})


if __name__ == "__main__":
    unittest.main()
