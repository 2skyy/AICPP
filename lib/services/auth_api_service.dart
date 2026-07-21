import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class AuthApiException implements Exception {
  AuthApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthResult {
  const AuthResult({required this.accessToken, required this.userId, required this.email});

  final String accessToken;
  final String userId;
  final String email;
}

class AuthApiService {
  AuthApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AuthResult> signUp(String email, String password) =>
      _authenticate('/api/v1/auth/signup', email, password);

  Future<AuthResult> login(String email, String password) =>
      _authenticate('/api/v1/auth/login', email, password);

  Future<AuthResult> _authenticate(String path, String email, String password) async {
    final uri = Uri.parse('$policyApiBaseUrl$path');
    http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw AuthApiException('서버에 연결할 수 없어요. 잠시 후 다시 시도해주세요.');
    }

    final decoded = _tryDecode(response.body);
    if (response.statusCode != 200) {
      final detail = decoded is Map<String, dynamic> ? decoded['detail'] : null;
      throw AuthApiException(detail is String ? detail : '인증에 실패했어요 (${response.statusCode})');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['access_token'] is! String ||
        decoded['user_id'] is! String) {
      throw AuthApiException('서버 응답을 이해하지 못했어요.');
    }
    return AuthResult(
      accessToken: decoded['access_token'] as String,
      userId: decoded['user_id'] as String,
      email: decoded['email'] as String? ?? email,
    );
  }

  dynamic _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}
