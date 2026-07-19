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
  /// (`plcyNm`) — a literal title search, NOT a region filter (a policy
  /// whose title doesn't mention a region can still apply there). [topic]
  /// filters by policy topic keyword (`plcyKywdNm`). [region] filters by
  /// where the policy actually applies (`zipCd`, resolved server-side from
  /// the 시도 name) — this is the right param for "정책이 이 지역에 적용되는가".
  Future<PolicySearchResult> search({
    String? query,
    String? name,
    String? topic,
    String? region,
    int page = 1,
    int size = 10,
  }) async {
    final uri = Uri.parse('$policyApiBaseUrl/api/ontong-policy/search').replace(
      queryParameters: {
        if (query != null) 'query': query,
        if (name != null) 'name': name,
        if (topic != null) 'topic': topic,
        if (region != null) 'region': region,
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

    // 502/503/504는 정부 온통청년 API 자체가 순간적으로 불안정해서 우리 백엔드가
    // 그대로 전달하는 경우가 대부분이고(이 세션에서 재시도로 실제 확인됨), 완전히
    // 실패로 처리하기 전에 한 번 더 시도해서 지도의 "조회 실패" 표시를 줄인다.
    if (_isTransientServerError(response.statusCode)) {
      try {
        response = await _client.get(uri).timeout(const Duration(seconds: 20));
      } catch (_) {
        // 재시도에서도 네트워크 자체가 실패하면, 원래 받은 응답으로 계속 진행해서
        // 아래에서 상태코드 기반 에러 메시지를 만들도록 한다.
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

  /// Same filters as [search], but pages through results (up to [maxPages])
  /// so counts/lists aren't silently capped at one page's worth. A region
  /// search can easily return hundreds of matches (nationwide policies
  /// match every region), so a single page under-counts how many are
  /// actually open.
  Future<PolicySearchResult> searchAllPages({
    String? query,
    String? name,
    String? topic,
    String? region,
    int size = 50,
    int maxPages = 3,
  }) async {
    final items = <PolicyItem>[];
    var totalCount = 0;
    for (var page = 1; page <= maxPages; page++) {
      final result = await search(
        query: query,
        name: name,
        topic: topic,
        region: region,
        page: page,
        size: size,
      );
      totalCount = result.totalCount;
      items.addAll(result.items);
      if (result.items.isEmpty || items.length >= totalCount) break;
    }
    return PolicySearchResult(totalCount: totalCount, items: items);
  }

  static bool _isTransientServerError(int statusCode) =>
      statusCode == 502 || statusCode == 503 || statusCode == 504;

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
