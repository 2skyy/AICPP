import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/policy_item.dart';

class PolicyApiException implements Exception {
  PolicyApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PolicySearchResult {
  const PolicySearchResult({required this.totalCount, required this.items});

  final int totalCount;
  final List<PolicyItem> items;
}

class PolicyApiService {
  PolicyApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// [query] does a free-text search (currently ignored by the upstream
  /// API — kept for forward-compatibility). [name] filters by policy name
  /// (`plcyNm`) and [topic] by policy topic keyword (`plcyKywdNm`) — both
  /// verified to actually work upstream.
  Future<PolicySearchResult> search({
    String? query,
    String? name,
    String? topic,
    int page = 1,
    int size = 10,
  }) async {
    final uri = Uri.parse('$policyApiBaseUrl/api/ontong-policy/search').replace(
      queryParameters: {
        if (query != null) 'query': query,
        if (name != null) 'name': name,
        if (topic != null) 'topic': topic,
        'page': '$page',
        'size': '$size',
      },
    );

    // 온통청년 API가 이따금 느리게 응답하거나 타임아웃되는 게 관찰되어,
    // 완전히 실패로 처리하기 전에 한 번 재시도한다.
    http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 20));
    } catch (_) {
      try {
        response = await _client.get(uri).timeout(const Duration(seconds: 20));
      } catch (_) {
        throw PolicyApiException('정책 서버에 연결할 수 없어요. 백엔드가 실행 중인지 확인해주세요.');
      }
    }

    if (response.statusCode != 200) {
      throw PolicyApiException(
        _extractErrorDetail(response.body) ?? '정책 서버 오류가 발생했어요 (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return const PolicySearchResult(totalCount: 0, items: []);
    }
    return PolicySearchResult(
      totalCount: PolicyItem.totalCountFromResponse(decoded),
      items: PolicyItem.listFromResponse(decoded),
    );
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
