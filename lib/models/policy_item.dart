import '../constants/interests.dart';
import '../models/user_profile.dart';

DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// bizPrdEtcCn free-text values that all mean "no fixed deadline, always
/// accepting" — shown to users as one clear phrase instead of whichever
/// bureaucratic synonym ("연중", "계속" 등) the API happened to use.
const _ongoingPeriodSynonyms = {'상시', '연중', '계속', '연례반복', '매년', '수시'};

// 정책 화면에 보여주는 지원금액은 이제 Supabase 파이프라인이 사람 검토까지 거쳐
// 확정한 값(preciseSupportAmount)만 쓴다 — 아래 정규식 기반 추정치는 실제 재정
// 결정에 쓰일 수 있는 화면에 검증 안 된 숫자를 "정확한 금액"처럼 보여줄 위험이
// 있어 더 이상 표시에 쓰지 않지만, 나중에 다시 필요할 수도 있어 주석으로 남겨둔다.
// final _amountPattern = RegExp(r'(\d[\d,]*)(?:\.(\d+))?\s*(억|만)?\s*원');
//
// /// Best-effort won amount parsed out of free-text support content (e.g.
// /// "월 20만원 지원", "최대 300만원", "1,000,000원"). Takes the largest amount
// /// mentioned in the text, since these descriptions often list several
// /// figures (a monthly amount and a total cap) and the total is the more
// /// useful one for comparing policies. Returns null when no amount is found.
// int? _parseSupportAmount(String? text) {
//   if (text == null) return null;
//   int? maxAmount;
//   for (final match in _amountPattern.allMatches(text)) {
//     final integerPart = match.group(1)!.replaceAll(',', '');
//     final decimalPart = match.group(2);
//     final unit = match.group(3);
//     final value = double.tryParse(decimalPart == null ? integerPart : '$integerPart.$decimalPart');
//     if (value == null) continue;
//     final multiplier = switch (unit) {
//       '억' => 100000000,
//       '만' => 10000,
//       _ => 1,
//     };
//     final amount = (value * multiplier).round();
//     if (maxAmount == null || amount > maxAmount) maxAmount = amount;
//   }
//   return maxAmount;
// }

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

/// The government API's `mclsfNm`(중분류) mapped directly to one of the
/// user's selectable interests (`kInterests`, `lib/constants/interests.dart`)
/// so the map/report category system and the profile's 관심사 system are
/// exactly the same 9 values — verified against a live pull of all ~2,649
/// policies. Sub-categories with no real interest counterpart (청년참여/
/// 정책인프라구축/권익보호 — civic-participation concepts, not a profile
/// interest) are deliberately left out rather than forced into an unrelated
/// bucket, so they end up with no category (there is no "참여권리" bucket).
const _subCategoryToInterest = {
  '취업': '취업',
  '재직자': '취업',
  '창업': '창업',
  '미래역량강화': '교육',
  '교육비지원': '교육',
  '온·오프라인교육': '교육',
  '온라인교육': '교육',
  '주택 및 거주지': '주거',
  '전월세 및 주거급여 지원': '주거',
  '기숙사': '주거',
  '건강': '건강',
  '문화활동': '문화',
  '예술인지원': '문화',
  '청년국제교류': '국제교류',
};

/// "취약계층 및 금융지원" names both a target group and a support type at
/// once, so 금융 vs 복지 can't be read off the label alone — checked against
/// live data (215 policies): only ~19% mention a financial keyword without
/// any welfare signal, so that's the only case treated as 금융; everything
/// else (including the ~43% where neither keyword appears) defaults to 복지,
/// same fallback spirit as the culture/welfare split below.
const _financialKeywords = ['대출', '이자', '보증금', '저축', '예금', '적금', '신용', '상환', '금융', '펀드'];
const _welfareSignalKeywords = ['생활비', '돌봄', '취약계층', '생계', '긴급지원', '한부모', '저소득'];

String _classifyFinancialOrWelfare(String haystack) {
  final hasFinance = _financialKeywords.any(haystack.contains);
  final hasWelfareSignal = _welfareSignalKeywords.any(haystack.contains);
  return (hasFinance && !hasWelfareSignal) ? '금융' : '복지';
}

/// "문화활동 및 생활지원" also names both concepts at once; disambiguated by
/// keyword the same way the old 복지문화 대분류 split used to be.
String _classifyCultureOrWelfare(String haystack) {
  final hasCulture = haystack.contains('문화') || haystack.contains('예술') || haystack.contains('여가');
  final hasWelfare = haystack.contains('복지') || haystack.contains('생활지원') || haystack.contains('생활비');
  if (hasCulture && !hasWelfare) return '문화';
  if (hasWelfare && !hasCulture) return '복지';
  return '복지';
}

String? _normalizeCategory(String? subCategory, {String haystack = ''}) {
  if (subCategory == null || subCategory.trim().isEmpty) return null;
  final first = subCategory.split(',').first.trim();
  if (first.isEmpty) return null;
  if (first == '취약계층 및 금융지원') return _classifyFinancialOrWelfare(haystack);
  if (first == '문화활동 및 생활지원') return _classifyCultureOrWelfare(haystack);
  return _subCategoryToInterest[first];
}

/// Some [kInterests] values (`lib/constants/interests.dart`) could be
/// compound words that won't literally appear in policy text as one token —
/// this expands those down to the words actually worth searching for.
/// Currently empty since every interest is a single plain word, but kept so
/// a future compound interest doesn't need this matching logic rebuilt.
const _interestKeywordGroups = <String, List<String>>{};

List<String> _keywordsForInterest(String interest) =>
    _interestKeywordGroups[interest] ?? [interest];

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
    this.subCategory,
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

  /// `mclsfNm` (중분류) — this is what [categoryLabel] actually classifies
  /// off of (see there); [category] (`lclsfNm`, 대분류) is only shown as a
  /// raw government tag, not used for our own category/interest grouping.
  final String? subCategory;

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
    // "0세 ~ 0세" is how the government API represents "no age limit" (전
    // 연령 대상), not a literal range that only a newborn could satisfy.
    if (minAge == 0 && maxAge == 0) return true;
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

  /// Won amount used by the map's "지원금액 많은 순" sort and shown to the
  /// user. Only the Supabase pipeline's human-reviewed [preciseSupportAmount]
  /// — no regex-guessed fallback, since users may make real decisions off
  /// this number and an unverified guess shouldn't be presented as fact.
  int? get supportAmount => preciseSupportAmount;

  /// Best-effort "기준중위소득 N% 이하" ceiling parsed from [incomeInfo].
  int? get maxIncomePercent => _parseMaxIncomePercent(incomeInfo);

  /// [subCategory] mapped down to one of [kInterests]'s 9 values (see
  /// `_subCategoryToInterest`), so this is literally the same taxonomy as the
  /// profile's 관심사 selection — not a separate government-category system.
  /// Null when [subCategory] doesn't map to any of them.
  String? get categoryLabel => _normalizeCategory(
        subCategory,
        haystack: [name, description, supportContent].whereType<String>().join(' '),
      );

  /// Which of [UserProfile.interests] this policy's name/description/support
  /// content actually mentions. Unlike [ageMatches]/[incomeMatches] (hard
  /// eligibility — can this user even apply), this is a soft "might this
  /// interest them" signal, so it's never used to hide policies, only to tag
  /// ones worth surfacing to a user who picked that interest.
  List<String> matchingInterests(UserProfile profile) {
    if (profile.interests.isEmpty) return const [];
    final haystack = [name, description, category, supportContent]
        .whereType<String>()
        .join(' ');
    return profile.interests
        .where((interest) =>
            _keywordsForInterest(interest).any(haystack.contains))
        .toList();
  }

  /// Whether this policy relates to any of the user's selected interests.
  bool matchesInterests(UserProfile profile) => matchingInterests(profile).isNotEmpty;

  /// [supportAmount] formatted for display, e.g. "150만원". Null when no
  /// amount could be determined at all.
  String? get supportAmountLabel {
    final amount = supportAmount;
    return amount == null ? null : _formatWon(amount);
  }

  // supportAmount는 이제 preciseSupportAmount만 쓰므로 이 값은 항상 참이라
  // 화면에서 더 안 쓰지만(추정치 구분이 필요 없어짐), 나중에 다시 추정치를
  // 보여주게 되면 필요할 수 있어 주석으로 남겨둔다.
  // bool get supportAmountIsPrecise => preciseSupportAmount != null;

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
      subCategory: findFirst(['mclsfNm']),
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
