import unittest
from unittest.mock import Mock, patch

from app.api.clients.supabase_auth import SupabaseAuthClient, SupabaseAuthError
from app.core.config import Settings


class SupabaseAuthClientTest(unittest.TestCase):
    def _client(self):
        settings = Settings(
            SUPABASE_URL="https://example.supabase.co",
            SUPABASE_ANON_KEY="pub-key",
            SUPABASE_SECRET_KEY="secret-key",
        )
        return SupabaseAuthClient(settings)

    @patch("app.api.clients.supabase_auth.requests.put")
    def test_admin_confirm_email_authenticates_with_the_secret_key(self, mock_put):
        mock_put.return_value = Mock(status_code=200, json=lambda: {"id": "user-1"})

        self._client().admin_confirm_email("user-1")

        _, kwargs = mock_put.call_args
        self.assertEqual(kwargs["headers"]["apikey"], "secret-key")
        self.assertEqual(kwargs["headers"]["Authorization"], "Bearer secret-key")
        self.assertEqual(kwargs["json"], {"email_confirm": True})

    @patch("app.api.clients.supabase_auth.requests.post")
    def test_sign_in_raises_supabase_auth_error_on_failure(self, mock_post):
        mock_post.return_value = Mock(
            status_code=400,
            json=lambda: {"error_description": "Invalid login credentials"},
        )

        with self.assertRaises(SupabaseAuthError) as ctx:
            self._client().sign_in("a@b.com", "wrong-password")
        self.assertEqual(ctx.exception.status_code, 400)
        self.assertEqual(ctx.exception.message, "Invalid login credentials")


if __name__ == "__main__":
    unittest.main()
