import unittest
from unittest.mock import Mock

from app.services.auth_service import AuthService


class AuthServiceSignUpTest(unittest.TestCase):
    def test_confirms_email_then_signs_in_after_a_successful_signup(self):
        client = Mock()
        client.sign_up.return_value = {"id": "user-1", "email": "a@b.com"}
        client.sign_in.return_value = {"access_token": "tok", "refresh_token": "ref"}

        result = AuthService(client).sign_up("a@b.com", "pw123456")

        client.admin_confirm_email.assert_called_once_with("user-1")
        client.sign_in.assert_called_once_with("a@b.com", "pw123456")
        self.assertEqual(result, {"access_token": "tok", "refresh_token": "ref"})

    def test_reads_user_id_from_a_nested_user_object_when_present(self):
        client = Mock()
        client.sign_up.return_value = {"user": {"id": "user-2"}}
        client.sign_in.return_value = {}

        AuthService(client).sign_up("a@b.com", "pw123456")

        client.admin_confirm_email.assert_called_once_with("user-2")

    def test_raises_when_signup_response_has_no_user_id(self):
        client = Mock()
        client.sign_up.return_value = {}

        with self.assertRaises(Exception):
            AuthService(client).sign_up("a@b.com", "pw123456")
        client.admin_confirm_email.assert_not_called()


class AuthServiceSignInTest(unittest.TestCase):
    def test_delegates_straight_to_the_client(self):
        client = Mock()
        client.sign_in.return_value = {"access_token": "tok"}

        result = AuthService(client).sign_in("a@b.com", "pw123456")

        client.sign_in.assert_called_once_with("a@b.com", "pw123456")
        self.assertEqual(result, {"access_token": "tok"})


if __name__ == "__main__":
    unittest.main()
