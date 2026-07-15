import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/policy_item.dart';
import '../models/user_profile.dart';
import '../services/policy_api_service.dart';
import '../theme/toss_colors.dart';
import 'interested_region_screen.dart';
import 'policy_detail_screen.dart';

const _categoryColors = [
  TossColors.primary,
  Color(0xFFFF8B3D),
  Color(0xFF2ECC71),
  Color(0xFFE74C3C),
  Color(0xFF9B59B6),
  Color(0xFFF1C40F),
];

class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    required this.profile,
    required this.onProfileUpdated,
    this.policyApiService,
  });

  final UserProfile profile;
  final ValueChanged<UserProfile> onProfileUpdated;
  final PolicyApiService? policyApiService;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late final _policyApi = widget.policyApiService ?? PolicyApiService();
  List<PolicyItem>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.profile.interestedRegions.isNotEmpty) _load();
  }

  @override
  void didUpdateWidget(covariant ReportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hadNone = oldWidget.profile.interestedRegions.isEmpty;
    final hasNow = widget.profile.interestedRegions.isNotEmpty;
    if (hadNone && hasNow) _load();
  }

  Set<String> get _regions => {widget.profile.region, ...widget.profile.interestedRegions};

  Future<void> _load() async {
    setState(() {
      _items = null;
      _error = null;
    });
    try {
      final results = await Future.wait(_regions.map((r) => _policyApi.search(name: r, size: 30)));
      if (!mounted) return;
      final combined = <String, PolicyItem>{};
      for (final result in results) {
        for (final item in result.items) {
          if (!item.isCurrentlyOpen) continue;
          combined[item.policyNo ?? item.name] = item;
        }
      }
      setState(() => _items = combined.values.toList());
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
        child: widget.profile.interestedRegions.isEmpty
            ? _EmptyReportView(onAddRegions: _addInterestedRegions)
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: const TextStyle(color: TossColors.textSecondary)),
        ),
      );
    }
    if (_items == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = _items!;
    final matching = items.where((item) => item.matchesProfile(widget.profile)).length;
    final total = items.length;

    final categoryCounts = <String, int>{};
    for (final item in items) {
      final category = item.category ?? '기타';
      categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
    }

    final upcoming = items.where((item) => item.deadline != null).toList()
      ..sort((a, b) => a.deadline!.compareTo(b.deadline!));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
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
                '마감일이 확인된 정책이 없어요',
                style: TextStyle(fontSize: 14, color: TossColors.textSecondary),
              ),
            )
          else
            ...upcoming.take(5).map((item) => _DeadlineTile(
                  item: item,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PolicyDetailScreen(policy: item)),
                  ),
                )),
        ],
      ),
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
                      for (var i = 0; i < entries.length; i++)
                        PieChartSectionData(
                          value: entries[i].value.toDouble(),
                          color: _categoryColors[i % _categoryColors.length],
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
                      color: _categoryColors[i % _categoryColors.length],
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
