import '../models/user_profile.dart';

DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// A single youth policy result from the 온통청년 API.
///
/// Field names below were verified against a live API response (not just
/// guessed): `result.youthPolicyList` items keyed by `plcyNm`, `plcyExplnCn`,
/// `sprvsnInstCdNm`, `aplyYmd`, `plcySprtCn`, `plcyAplyMthdCn`, `aplyUrlAddr`,
/// `sprtTrgtMinAge`/`sprtTrgtMaxAge`, `lclsfNm`, `frstRegDt`, `plcyNo`.
class PolicyItem {
  const PolicyItem({
    required this.name,
    this.policyNo,
    this.description,
    this.organization,
    this.period,
    this.supportContent,
    this.applyMethod,
    this.applyUrl,
    this.minAge,
    this.maxAge,
    this.category,
    this.registeredAt,
    this.applyStart,
    this.deadline,
  });

  final String name;
  final String? policyNo;
  final String? description;
  final String? organization;
  final String? period;
  final String? supportContent;
  final String? applyMethod;
  final String? applyUrl;
  final int? minAge;
  final int? maxAge;
  final String? category;
  final DateTime? registeredAt;
  final DateTime? applyStart;
  final DateTime? deadline;

  /// Soft eligibility check used for the map's "내게 맞는 것만" filter and the
  /// report tab's matching-rate gauge. Falls back to "matches" when the
  /// policy or the user's age is unknown, since we can't rule it out.
  bool matchesProfile(UserProfile profile) {
    if (profile.age <= 0) return true;
    if (minAge != null && profile.age < minAge!) return false;
    if (maxAge != null && profile.age > maxAge!) return false;
    return true;
  }

  /// Whether today falls inside the policy's application window. Policies
  /// with no parseable dates (e.g. "상시") are treated as always open.
  bool get isCurrentlyOpen {
    final today = _dateOnly(DateTime.now());
    if (deadline != null && deadline!.isBefore(today)) return false;
    if (applyStart != null && applyStart!.isAfter(today)) return false;
    return true;
  }

  static const _nameKeys = ['plcyNm', 'polyBizSjnm', 'title', 'name'];
  static const _descriptionKeys = ['plcyExplnCn', 'content', 'description'];
  static const _organizationKeys = ['sprvsnInstCdNm', 'operInstCdNm', 'rgtrInstCdNm'];
  static const _periodKeys = ['aplyYmd', 'bizPrdBgngYmd'];

  factory PolicyItem.fromJson(Map<String, dynamic> json) {
    String? findFirst(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      return null;
    }

    int? parseAge(dynamic value) {
      if (value is! String || value.trim().isEmpty) return null;
      return int.tryParse(value.trim());
    }

    DateTime? parseYmd(String? value) {
      if (value == null || value.length < 8) return null;
      final digits = value.substring(0, 8);
      final year = int.tryParse(digits.substring(0, 4));
      final month = int.tryParse(digits.substring(4, 6));
      final day = int.tryParse(digits.substring(6, 8));
      if (year == null || month == null || day == null) return null;
      try {
        return DateTime(year, month, day);
      } catch (_) {
        return null;
      }
    }

    final name = findFirst(_nameKeys) ??
        json.values.whereType<String>().firstWhere(
              (value) => value.trim().isNotEmpty,
              orElse: () => '이름 미상 정책',
            );

    final period = findFirst(_periodKeys);
    // aplyYmd looks like "20260707 ~ 20260731"; split into start/end so we
    // can tell whether the application window covers today.
    String? applyStartRaw;
    String? deadlineRaw;
    if (period != null && period.contains('~')) {
      final parts = period.split('~');
      applyStartRaw = parts.first.trim();
      deadlineRaw = parts.last.trim();
    } else {
      deadlineRaw = period;
    }

    return PolicyItem(
      name: name,
      policyNo: findFirst(['plcyNo']),
      description: findFirst(_descriptionKeys),
      organization: findFirst(_organizationKeys),
      period: period,
      supportContent: findFirst(['plcySprtCn']),
      applyMethod: findFirst(['plcyAplyMthdCn']),
      applyUrl: findFirst(['aplyUrlAddr', 'refUrlAddr1']),
      minAge: parseAge(json['sprtTrgtMinAge']),
      maxAge: parseAge(json['sprtTrgtMaxAge']),
      category: findFirst(['lclsfNm']),
      registeredAt: parseYmd(findFirst(['frstRegDt'])),
      applyStart: parseYmd(applyStartRaw),
      deadline: parseYmd(deadlineRaw),
    );
  }

  /// Locates the results list inside the raw API response.
  static List<PolicyItem> listFromResponse(Map<String, dynamic> body) {
    const candidatePaths = [
      ['result', 'youthPolicyList'],
      ['result', 'list'],
      ['resultList'],
      ['youthPolicyList'],
      ['list'],
      ['items'],
    ];

    for (final path in candidatePaths) {
      dynamic node = body;
      for (final key in path) {
        if (node is Map<String, dynamic>) {
          node = node[key];
        } else {
          node = null;
          break;
        }
      }
      if (node is List) {
        return node.whereType<Map<String, dynamic>>().map(PolicyItem.fromJson).toList();
      }
    }
    return const [];
  }

  /// Reads the total match count from the API's pagination envelope,
  /// falling back to the returned page's item count if that's missing.
  static int totalCountFromResponse(Map<String, dynamic> body) {
    final result = body['result'];
    if (result is Map<String, dynamic>) {
      final pagging = result['pagging'];
      if (pagging is Map<String, dynamic>) {
        final totCount = pagging['totCount'];
        if (totCount is int) return totCount;
      }
    }
    return listFromResponse(body).length;
  }
}
