import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/user_profile.dart';

class ChatApiException implements Exception {
  ChatApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ChatApiService {
  ChatApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Sends [question] + [profile] to the backend, which looks up relevant
  /// policies and asks Claude to answer using only those as context.
  Future<String> ask(String question, UserProfile profile) async {
    final uri = Uri.parse('$policyApiBaseUrl/api/chat/ask');
    final body = jsonEncode({
      'question': question,
      'profile': {
        'region': profile.region,
        'enrollment_status': profile.enrollmentStatus,
        'age': profile.age > 0 ? profile.age : null,
        'interested_regions': profile.interestedRegions,
      },
    });

    http.Response response;
    try {
      response = await _client
          .post(uri, headers: {'content-type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw ChatApiException('정책 서버에 연결할 수 없어요. 백엔드가 실행 중인지 확인해주세요.');
    }

    if (response.statusCode != 200) {
      throw ChatApiException(
        _extractErrorDetail(response.body) ?? '어시스턴트 응답 생성에 실패했어요 (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['answer'] is! String) {
      throw ChatApiException('어시스턴트 응답을 이해하지 못했어요.');
    }
    return decoded['answer'] as String;
  }

  String? _extractErrorDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } catch (_) {
      // Not JSON — fall through to the generic message.
    }
    return null;
  }
}
