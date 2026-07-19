import '../models/user_profile.dart';

DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// bizPrdEtcCn free-text values that all mean "no fixed deadline, always
/// accepting" — shown to users as one clear phrase instead of whichever
/// bureaucratic synonym ("연중", "계속" 등) the API happened to use.
const _ongoingPeriodSynonyms = {'상시', '연중', '계속', '연례반복', '매년', '수시'};

final _amountPattern = RegExp(r'(\d[\d,]*)(?:\.(\d+))?\s*(억|만)?\s*원');

/// Best-effort won amount parsed out of free-text support content (e.g.
/// "월 20만원 지원", "최대 300만원", "1,000,000원"). Takes the largest amount
/// mentioned in the text, since these descriptions often list several
/// figures (a monthly amount and a total cap) and the total is the more
/// useful one for comparing policies. Returns null when no amount is found.
int? _parseSupportAmount(String? text) {
  if (text == null) return null;
  int? maxAmount;
  for (final match in _amountPattern.allMatches(text)) {
    final integerPart = match.group(1)!.replaceAll(',', '');
    final decimalPart = match.group(2);
    final unit = match.group(3);
    final value = double.tryParse(decimalPart == null ? integerPart : '$integerPart.$decimalPart');
    if (value == null) continue;
    final multiplier = switch (unit) {
      '억' => 100000000,
      '만' => 10000,
      _ => 1,
    };
    final amount = (value * multiplier).round();
    if (maxAmount == null || amount > maxAmount) maxAmount = amount;
  }
  return maxAmount;
}

/// Formats a won amount for display, e.g. 1500000 -> "150만원",
/// 100000000 -> "1억원", 150000000 -> "1억 5천만원".
String _formatWon(int amount) {
  if (amount >= 100000000) {
    final eok = amount ~/ 100000000;
    final manRemainder = (amount % 100000000) ~/ 10000;
    return manRemainder == 0 ? '$eok억원' : '$eok억 $manRemainder만원';
  }
  if (amount >= 10000) {
    return '${amount ~/ 10000}만원';
  }
  return '$amount원';
}

final _incomePercentPattern = RegExp(r'중위\s*소득[의]?\s*(\d+)\s*%\s*이하');

/// Best-effort "기준중위소득 N% 이하" ceiling parsed out of free-text income
/// condition text. Many policies don't state one at all (income-agnostic,
/// or conditioned on a raw amount instead) — null then, treated as unknown.
int? _parseMaxIncomePercent(String? text) {
  if (text == null) return null;
  final match = _incomePercentPattern.firstMatch(text);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

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
    this.incomeInfo,
    this.preciseSupportAmount,
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

  /// Free-text income condition (`earnEtcCn`), e.g. "중위소득 150% 이하,
  /// 거래금액 2억원 이하 무주택 임차가구". Not every policy has one.
  final String? incomeInfo;

  /// Precise won amount (`sprtAmtKrw`) extracted offline by the support-amount
  /// pipeline (regex + LLM fallback + human review) and merged in server-side
  /// from Supabase. More reliable than [supportAmount]'s on-device regex
  /// guess, but only present for policies already covered by that pipeline's
  /// snapshot.
  final int? preciseSupportAmount;

  /// Soft eligibility check used by the report tab's matching-rate gauge and
  /// category donut. Composes [ageMatches] and [incomeMatches] so callers can
  /// also ask which specific condition excluded a policy.
  bool matchesProfile(UserProfile profile) => ageMatches(profile) && incomeMatches(profile);

  /// Defaults to "matches" when the user's age is unknown, since we can't
  /// rule it out.
  bool ageMatches(UserProfile profile) {
    if (profile.age <= 0) return true;
    if (minAge != null && profile.age < minAge!) return false;
    if (maxAge != null && profile.age > maxAge!) return false;
    return true;
  }

  /// Defaults to "matches" when either the user's income percent or the
  /// policy's income ceiling is unknown, since we can't rule it out.
  bool incomeMatches(UserProfile profile) {
    final userPercent = profile.incomePercent;
    final policyCeiling = maxIncomePercent;
    if (userPercent != null && policyCeiling != null && userPercent > policyCeiling) {
      return false;
    }
    return true;
  }

  /// Won amount used by the map's "지원금액 많은 순" sort. Prefers
  /// [preciseSupportAmount] (Supabase pipeline) when available, falling back
  /// to a best-effort regex parse of [supportContent] otherwise.
  int? get supportAmount => preciseSupportAmount ?? _parseSupportAmount(supportContent);

  /// Best-effort "기준중위소득 N% 이하" ceiling parsed from [incomeInfo].
  int? get maxIncomePercent => _parseMaxIncomePercent(incomeInfo);

  /// [supportAmount] formatted for display, e.g. "150만원". Null when no
  /// amount could be determined at all.
  String? get supportAmountLabel {
    final amount = supportAmount;
    return amount == null ? null : _formatWon(amount);
  }

  /// Whether [supportAmount] came from the verified Supabase pipeline
  /// ([preciseSupportAmount]) rather than the on-device regex guess — used to
  /// tell users whether the shown amount is confirmed or just an estimate.
  bool get supportAmountIsPrecise => preciseSupportAmount != null;

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

    int? parseIntValue(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value.trim());
      return null;
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

    // frstRegDt/lastMdfcnDt come as "2026-07-16 13:39:41" (dashes, with a
    // time part) — a different shape from aplyYmd's plain "YYYYMMDD", so it
    // needs its own parser rather than [parseYmd].
    DateTime? parseTimestamp(String? value) {
      if (value == null || value.length < 10) return null;
      final year = int.tryParse(value.substring(0, 4));
      final month = int.tryParse(value.substring(5, 7));
      final day = int.tryParse(value.substring(8, 10));
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

    // 절반가량의 정책은 aplyYmd(신청기간)가 아예 없는 "상시"/"연중" 모집이라
    // bizPrdBgngYmd~bizPrdEndYmd(사업기간)나 bizPrdEtcCn(기타 설명, "상시" 등)로
    // 대신 기간을 표시해야 한다. bizPrdBgngYmd만 단독으로 마감일 취급하면(과거
    // 로직) 사업 시작일을 마감일로 오인해 아직 진행 중인 정책이 마감된 것처럼
    // 잘못 판정되므로, 시작일과 종료일을 반드시 짝지어서만 사용한다.
    final aplyYmd = findFirst(['aplyYmd']);
    final bizPrdBgngYmd = findFirst(['bizPrdBgngYmd']);
    final bizPrdEndYmd = findFirst(['bizPrdEndYmd']);
    final bizPrdEtcCn = findFirst(['bizPrdEtcCn']);

    String? period;
    String? applyStartRaw;
    String? deadlineRaw;
    if (aplyYmd != null) {
      period = aplyYmd;
      if (aplyYmd.contains('~')) {
        final parts = aplyYmd.split('~');
        applyStartRaw = parts.first.trim();
        deadlineRaw = parts.last.trim();
      } else {
        deadlineRaw = aplyYmd;
      }
    } else if (bizPrdBgngYmd != null && bizPrdEndYmd != null) {
      period = '$bizPrdBgngYmd ~ $bizPrdEndYmd';
      applyStartRaw = bizPrdBgngYmd;
      deadlineRaw = bizPrdEndYmd;
    } else if (bizPrdEtcCn != null) {
      // 자유 텍스트("상시", "연중", "2026. 1. ~ 12." 등 형식이 제각각)라 날짜로
      // 파싱하지 않고 표시 문구로만 쓴다 — 마감일 없음(상시 취급)으로 남긴다.
      // "연중"/"계속" 등 여러 동의어는 하나의 명확한 문구로 통일해서 보여준다.
      period = _ongoingPeriodSynonyms.contains(bizPrdEtcCn) ? '상시모집' : bizPrdEtcCn;
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
      registeredAt: parseTimestamp(findFirst(['frstRegDt'])),
      applyStart: parseYmd(applyStartRaw),
      deadline: parseYmd(deadlineRaw),
      incomeInfo: findFirst(['earnEtcCn']),
      preciseSupportAmount: parseIntValue(json['sprtAmtKrw']),
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
