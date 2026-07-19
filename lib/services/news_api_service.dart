import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class NewsApiException implements Exception {
  NewsApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NewsArticle {
  const NewsArticle({
    required this.title,
    required this.url,
    required this.source,
    this.publishedAt,
    this.reason,
  });

  final String title;
  final String url;
  final String source;
  final String? publishedAt;
  final String? reason;
}

class NewsApiService {
  NewsApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Fetches Claude-curated news recommendations for [interests]. Returns an
  /// empty list without calling the backend if there are no interests set or
  /// [count] is 0 (e.g. there are no matched policies to pair news with).
  Future<List<NewsArticle>> fetchRecommendations(
    List<String> interests, {
    int? count,
  }) async {
    if (interests.isEmpty || count == 0) return const [];

    final uri = Uri.parse('$policyApiBaseUrl/api/news/recommendations').replace(
      queryParameters: {
        'interests': interests,
        if (count != null) 'count': '$count',
      },
    );

    http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 30));
    } catch (_) {
      throw NewsApiException('뉴스 서버에 연결할 수 없어요. 백엔드가 실행 중인지 확인해주세요.');
    }

    if (response.statusCode != 200) {
      throw NewsApiException(
        _extractErrorDetail(response.body) ?? '뉴스 추천에 실패했어요 (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return const [];
    final articles = decoded['articles'];
    if (articles is! List) return const [];

    return articles
        .whereType<Map<String, dynamic>>()
        .map((json) => NewsArticle(
              title: json['title'] as String? ?? '',
              url: json['url'] as String? ?? '',
              source: json['source'] as String? ?? '',
              publishedAt: json['publishedAt'] as String?,
              reason: json['reason'] as String?,
            ))
        .where((article) => article.title.isNotEmpty && article.url.isNotEmpty)
        .toList();
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
