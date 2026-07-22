import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/policy_item.dart';
import '../models/user_profile.dart';
import '../services/news_api_service.dart';
import '../services/policy_api_service.dart';
import '../theme/toss_colors.dart';
import 'edit_profile_screen.dart';
import 'interested_region_screen.dart';
import 'policy_detail_screen.dart';

// 카테고리별로 항상 같은 색이 나오도록 이름에 고정 매핑한다 (건수 정렬 순서에
// 따라 색이 바뀌던 이전 방식 대신).
const _categoryColors = <String, Color>{
  '주거': TossColors.primary,
  '취업': Color(0xFFFF8B3D),
  '창업': Color(0xFF2ECC71),
  '교육': Color(0xFFE74C3C),
  '복지': Color(0xFF9B59B6),
  '문화': Color(0xFFF1C40F),
  '건강': Color(0xFF3498DB),
  '금융': Color(0xFF1ABC9C),
  '국제교류': Color(0xFFE67E22),
};
const _fallbackCategoryColor = Color(0xFF95A5A6);

class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    required this.profile,
    required this.onProfileUpdated,
    this.policyApiService,
    this.newsApiService,
  });

  final UserProfile profile;
  final ValueChanged<UserProfile> onProfileUpdated;
  final PolicyApiService? policyApiService;
  final NewsApiService? newsApiService;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late final _policyApi = widget.policyApiService ?? PolicyApiService();
  late final _newsApi = widget.newsApiService ?? NewsApiService();
  List<PolicyItem>? _items;
  String? _error;
  List<NewsArticle>? _newsArticles;
  String? _newsError;

  @override
  void initState() {
    super.initState();
    if (widget.profile.interestedRegions.isNotEmpty) _load();
    _loadNews();
  }

  @override
  void didUpdateWidget(covariant ReportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hadNone = oldWidget.profile.interestedRegions.isEmpty;
    final hasNow = widget.profile.interestedRegions.isNotEmpty;
    if (hadNone && hasNow) _load();

    final hadNoInterests = oldWidget.profile.interests.isEmpty;
    final hasInterestsNow = widget.profile.interests.isNotEmpty;
    if (hadNoInterests && hasInterestsNow) {
      final matching = _items?.where((item) => item.matchesProfile(widget.profile)).length;
      _loadNews(count: matching);
    }
  }

  Set<String> get _regions => {widget.profile.region, ...widget.profile.interestedRegions};

  Future<void> _load() async {
    setState(() {
      _items = null;
      _error = null;
    });
    try {
      final results =
          await Future.wait(_regions.map((r) => _policyApi.searchAllPages(region: r, size: 50)));
      if (!mounted) return;
      final combined = <String, PolicyItem>{};
      for (final result in results) {
        for (final item in result.items) {
          if (!item.isCurrentlyOpen) continue;
          combined[item.policyNo ?? item.name] = item;
        }
      }
      final items = combined.values.toList();
      setState(() => _items = items);
      // 뉴스 개수를 매칭된 정책 수에 맞추기 위해, 정책 로딩이 끝난 뒤
      // 정확한 개수로 다시 요청한다 (초기 로딩 중엔 기본 개수로 먼저 표시됨).
      final matching = items.where((item) => item.matchesProfile(widget.profile)).length;
      unawaited(_loadNews(count: matching));
    } on PolicyApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _addInterestedRegions() async {
    final updated = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => InterestedRegionScreen(
          initialRegions: widget.profile.interestedRegions,
          homeRegion: widget.profile.region,
        ),
      ),
    );
    if (updated != null) {
      widget.onProfileUpdated(widget.profile.copyWith(interestedRegions: updated));
    }
  }

  Future<void> _loadNews({int? count}) async {
    if (widget.profile.interests.isEmpty) {
      setState(() {
        _newsArticles = const [];
        _newsError = null;
      });
      return;
    }
    setState(() {
      _newsArticles = null;
      _newsError = null;
    });
    try {
      final articles =
          await _newsApi.fetchRecommendations(widget.profile.interests, count: count);
      if (!mounted) return;
      setState(() => _newsArticles = articles);
    } on NewsApiException catch (e) {
      if (!mounted) return;
      setState(() => _newsError = e.message);
    }
  }

  Future<void> _editInterests() async {
    final updated = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute(builder: (_) => EditProfileScreen(profile: widget.profile)),
    );
    if (updated != null) widget.onProfileUpdated(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TossColors.background,
        elevation: 0,
        foregroundColor: TossColors.textPrimary,
        title: const Text('리포트'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            if (widget.profile.interestedRegions.isNotEmpty) {
              // _load() itself refreshes the news with a matching count.
              await _load();
            } else {
              await _loadNews();
            }
          },
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (widget.profile.interestedRegions.isEmpty)
                _EmptyReportView(onAddRegions: _addInterestedRegions)
              else
                ..._buildPolicySection(),
              const SizedBox(height: 32),
              const Text(
                '추천 뉴스',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: TossColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildNewsSection(),
            ],
          ),
        ),
      ),
    );
  }

  // Independent of the news section below — a stuck/failed policy fetch (or
  // no interested regions yet) shouldn't hide the news, since news is keyed
  // off interests, not regions.
  List<Widget> _buildPolicySection() {
    if (_error != null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text(_error!, style: const TextStyle(color: TossColors.textSecondary)),
          ),
        ),
      ];
    }
    if (_items == null) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    final items = _items!;
    final matchedItems = items.where((item) => item.matchesProfile(widget.profile)).toList();
    final matching = matchedItems.length;
    final total = items.length;

    // 도넛은 자격 되는 정책 중, 사용자가 관심사로 고른 카테고리만 집계한다 —
    // 관심사를 프로필에서 추가/삭제하면 여기 분포도 그대로 따라 바뀐다.
    final categoryCounts = <String, int>{};
    for (final item in matchedItems) {
      final category = item.categoryLabel;
      if (category == null || !widget.profile.interests.contains(category)) continue;
      categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
    }

    // 마감이 몇 달씩(세 자리 D-day) 남은 정책까지 "임박"이라고 보여주면 의미가
    // 없어서, 30일 이내로 남은 것만 후보로 삼는다 (아래에서 그중 가까운 5건만
    // 표시).
    final today = DateUtils.dateOnly(DateTime.now());
    final upcoming = items
        .where((item) => item.deadline != null)
        .where((item) => item.deadline!.difference(today).inDays <= 30)
        .toList()
      ..sort((a, b) => a.deadline!.compareTo(b.deadline!));

    final hasGap = matching < total;
    var ageMismatchCount = 0;
    var incomeMismatchCount = 0;
    var hasUnassessedIncome = false;
    if (hasGap) {
      for (final item in items) {
        if (!item.ageMatches(widget.profile)) ageMismatchCount++;
        if (!item.incomeMatches(widget.profile)) incomeMismatchCount++;
        if (item.maxIncomePercent != null && widget.profile.incomePercent == null) {
          hasUnassessedIncome = true;
        }
      }
    }

    return [
      const Text(
        '나의 정책 리포트',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: TossColors.textPrimary,
        ),
      ),
      Text(
        '거주지역·관심지역 정책 $total건 기준',
        style: const TextStyle(fontSize: 13, color: TossColors.textSecondary),
      ),
      const SizedBox(height: 24),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _MatchGauge(matching: matching, total: total),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _CategoryDonut(categoryCounts: categoryCounts),
          ),
        ],
      ),
      const SizedBox(height: 32),
      const Text(
        '마감임박',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: TossColors.textPrimary,
        ),
      ),
      const SizedBox(height: 12),
      if (upcoming.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '30일 이내로 마감하는 정책이 없어요',
            style: TextStyle(fontSize: 14, color: TossColors.textSecondary),
          ),
        )
      else
        ...upcoming.take(5).map((item) => _DeadlineTile(
              item: item,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PolicyDetailScreen(
                    policy: item,
                    profile: widget.profile,
                    onProfileUpdated: widget.onProfileUpdated,
                  ),
                ),
              ),
            )),
      if (hasGap) ...[
        const SizedBox(height: 24),
        _MatchGapNotice(
          profile: widget.profile,
          onProfileUpdated: widget.onProfileUpdated,
          ageMismatchCount: ageMismatchCount,
          incomeMismatchCount: incomeMismatchCount,
          hasUnassessedIncomeConditions: hasUnassessedIncome,
          unmatchedItems: items.where((item) => !item.matchesProfile(widget.profile)).toList(),
        ),
      ],
    ];
  }

  Widget _buildNewsSection() {
    if (widget.profile.interests.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '관심사를 설정하면 맞춤 뉴스를 볼 수 있어요',
              style: TextStyle(fontSize: 14, color: TossColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _editInterests,
              child: const Text(
                '관심사 설정하기',
                style: TextStyle(color: TossColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }
    if (_newsError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(_newsError!, style: const TextStyle(fontSize: 14, color: TossColors.textSecondary)),
      );
    }
    if (_newsArticles == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_newsArticles!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('추천할 뉴스를 찾지 못했어요', style: TextStyle(fontSize: 14, color: TossColors.textSecondary)),
      );
    }
    return Column(
      children: _newsArticles!.map((article) => _NewsCard(article: article)).toList(),
    );
  }
}

class _MatchGauge extends StatelessWidget {
  const _MatchGauge({required this.matching, required this.total});

  final int matching;
  final int total;

  @override
  Widget build(BuildContext context) {
    final rate = total == 0 ? 0.0 : matching / total;
    final percent = (rate * 100).round();
    return Column(
      children: [
        SizedBox(
          height: 120,
          width: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  startDegreeOffset: -90,
                  sectionsSpace: 0,
                  centerSpaceRadius: 42,
                  sections: [
                    PieChartSectionData(
                      value: rate,
                      color: TossColors.primary,
                      showTitle: false,
                      radius: 18,
                    ),
                    PieChartSectionData(
                      value: 1 - rate,
                      color: TossColors.fieldFill,
                      showTitle: false,
                      radius: 18,
                    ),
                  ],
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: TossColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '매칭 자격 충족률',
          style: TextStyle(fontSize: 12, color: TossColors.textSecondary),
        ),
      ],
    );
  }
}

class _CategoryDonut extends StatelessWidget {
  const _CategoryDonut({required this.categoryCounts});

  final Map<String, int> categoryCounts;

  @override
  Widget build(BuildContext context) {
    final entries = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.value);

    return Column(
      children: [
        SizedBox(
          height: 120,
          width: 120,
          child: total == 0
              ? const Center(
                  child: Text('데이터 없음', style: TextStyle(fontSize: 12, color: TossColors.textSecondary)),
                )
              : PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 32,
                    sections: [
                      for (final entry in entries)
                        PieChartSectionData(
                          value: entry.value.toDouble(),
                          color: _categoryColors[entry.key] ?? _fallbackCategoryColor,
                          showTitle: false,
                          radius: 24,
                        ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 8),
        const Text(
          '카테고리 분포',
          style: TextStyle(fontSize: 12, color: TossColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < entries.length && i < 4; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _categoryColors[entries[i].key] ?? _fallbackCategoryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    entries[i].key,
                    style: const TextStyle(fontSize: 11, color: TossColors.textSecondary),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _MatchGapNotice extends StatelessWidget {
  const _MatchGapNotice({
    required this.profile,
    required this.onProfileUpdated,
    required this.ageMismatchCount,
    required this.incomeMismatchCount,
    required this.hasUnassessedIncomeConditions,
    required this.unmatchedItems,
  });

  final UserProfile profile;
  final ValueChanged<UserProfile> onProfileUpdated;
  final int ageMismatchCount;
  final int incomeMismatchCount;
  final bool hasUnassessedIncomeConditions;
  final List<PolicyItem> unmatchedItems;

  void _showUnmatchedPolicies(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UnmatchedPoliciesSheet(
        items: unmatchedItems,
        profile: profile,
        onProfileUpdated: onProfileUpdated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ageText = profile.age > 0 ? '회원님 나이(만 ${profile.age}세) 기준으로 ' : '';
    final incomeText = profile.incomePercent != null ? '회원님 소득(중위소득 약 ${profile.incomePercent}%) 기준으로 ' : '';
    final reasons = <String>[
      if (ageMismatchCount > 0) '$ageText나이 조건이 맞지 않는 정책 $ageMismatchCount건이 있어요',
      if (incomeMismatchCount > 0) '$incomeText소득 조건이 맞지 않는 정책 $incomeMismatchCount건이 있어요',
      if (hasUnassessedIncomeConditions)
        '소득 정보를 입력하지 않아 일부 정책의 소득 조건은 판단하지 못했어요 (프로필에서 가구원수·월소득을 입력하면 정확해져요)',
    ];
    if (reasons.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TossColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '충족률이 100%가 아닌 이유',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: TossColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...reasons.map((reason) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '· $reason',
                  style: const TextStyle(fontSize: 12, color: TossColors.textSecondary),
                ),
              )),
          if (unmatchedItems.isNotEmpty) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _showUnmatchedPolicies(context),
              child: Text(
                '해당 정책 ${unmatchedItems.length}건 보기 →',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: TossColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnmatchedPoliciesSheet extends StatelessWidget {
  const _UnmatchedPoliciesSheet({
    required this.items,
    required this.profile,
    required this.onProfileUpdated,
  });

  final List<PolicyItem> items;
  final UserProfile profile;
  final ValueChanged<UserProfile> onProfileUpdated;

  String _reasonFor(PolicyItem item) {
    final reasons = <String>[
      if (!item.ageMatches(profile)) '나이 조건',
      if (!item.incomeMatches(profile)) '소득 조건',
    ];
    return '${reasons.join(', ')} 불충족';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: TossColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '충족 안 되는 정책 ${items.length}건',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: TossColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: TossColors.textPrimary),
                        ),
                        subtitle: Text(
                          _reasonFor(item),
                          style: const TextStyle(fontSize: 12, color: TossColors.error),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: TossColors.textSecondary),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PolicyDetailScreen(
                              policy: item,
                              profile: profile,
                              onProfileUpdated: onProfileUpdated,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DeadlineTile extends StatelessWidget {
  const _DeadlineTile({required this.item, required this.onTap});

  final PolicyItem item;
  final VoidCallback onTap;

  String get _ddayLabel {
    final days = item.deadline!.difference(DateUtils.dateOnly(DateTime.now())).inDays;
    if (days < 0) return '마감';
    if (days == 0) return 'D-DAY';
    return 'D-$days';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: TossColors.fieldFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: TossColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _ddayLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: TossColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.article});

  final NewsArticle article;

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(article.url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('뉴스 페이지를 열 수 없어요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TossColors.fieldFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              article.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: TossColors.textPrimary,
              ),
            ),
            if (article.reason != null && article.reason!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                article.reason!,
                style: const TextStyle(fontSize: 12, color: TossColors.textSecondary),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              article.source,
              style: const TextStyle(fontSize: 11, color: TossColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyReportView extends StatelessWidget {
  const _EmptyReportView({required this.onAddRegions});

  final VoidCallback onAddRegions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart_outlined, size: 48, color: TossColors.textSecondary),
            const SizedBox(height: 16),
            const Text(
              '아직 등록된 관심지역이 없어요',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: TossColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '관심지역을 등록하면 그 지역 정책들의\n매칭 현황을 리포트로 볼 수 있어요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: TossColors.textSecondary),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: onAddRegions,
              child: const Text(
                '관심지역 추가하기',
                style: TextStyle(color: TossColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
