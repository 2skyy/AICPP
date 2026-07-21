import 'package:flutter/material.dart';
import '../constants/interests.dart';
import '../models/policy_item.dart';
import '../models/user_profile.dart';
import '../screens/policy_detail_screen.dart';
import '../services/policy_api_service.dart';
import '../theme/toss_colors.dart';

enum _SortMode { deadline, latest, amount }

/// Fixed display order for [PolicyItem.categoryLabel]'s values — the same
/// [kInterests] the profile's 관심사 selection uses — so the filter chips
/// don't jump around as different regions surface different subsets.
const _categoryOrder = kInterests;

class PolicyListSheet extends StatefulWidget {
  const PolicyListSheet({
    super.key,
    required this.region,
    required this.profile,
    required this.onProfileUpdated,
    this.policyApiService,
  });

  final String region;
  final UserProfile profile;
  final ValueChanged<UserProfile> onProfileUpdated;
  final PolicyApiService? policyApiService;

  @override
  State<PolicyListSheet> createState() => _PolicyListSheetState();
}

class _PolicyListSheetState extends State<PolicyListSheet> {
  late final _policyApi = widget.policyApiService ?? PolicyApiService();
  List<PolicyItem>? _items;
  String? _error;
  _SortMode _sortMode = _SortMode.deadline;
  String? _selectedCategory;
  bool _interestOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _items = null;
      _error = null;
    });
    try {
      final result = await _policyApi.searchAllPages(region: widget.region, size: 50);
      if (!mounted) return;
      setState(() => _items = result.items.where((item) => item.isCurrentlyOpen).toList());
    } on PolicyApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  /// The base list before category/interest filtering: only policies the
  /// user is actually eligible for (age + income), so the sheet defaults to
  /// "정책 내가 할 수 있는 것들" rather than making the user wade through
  /// ones they can't apply to. Category/interest chips narrow this further,
  /// they don't bring ineligible policies back.
  List<PolicyItem> get _eligibleItems =>
      (_items ?? const []).where((item) => item.matchesProfile(widget.profile)).toList();

  /// Categories present among the currently eligible policies, in
  /// [_categoryOrder]. Only categories that actually occur are offered as
  /// filter chips.
  List<String> get _availableCategories {
    final present = _eligibleItems.map((item) => item.categoryLabel).whereType<String>().toSet();
    return _categoryOrder.where(present.contains).toList();
  }

  List<PolicyItem> get _sortedItems {
    final items = _eligibleItems
        .where((item) => _selectedCategory == null || item.categoryLabel == _selectedCategory)
        .where((item) => !_interestOnly || item.matchesInterests(widget.profile))
        .toList();
    switch (_sortMode) {
      case _SortMode.deadline:
        items.sort((a, b) {
          if (a.deadline == null && b.deadline == null) return 0;
          if (a.deadline == null) return 1;
          if (b.deadline == null) return -1;
          return a.deadline!.compareTo(b.deadline!);
        });
        return items;
      case _SortMode.latest:
        items.sort((a, b) {
          if (a.registeredAt == null && b.registeredAt == null) return 0;
          if (a.registeredAt == null) return 1;
          if (b.registeredAt == null) return -1;
          return b.registeredAt!.compareTo(a.registeredAt!);
        });
        return items;
      case _SortMode.amount:
        items.sort((a, b) {
          final amountA = a.supportAmount;
          final amountB = b.supportAmount;
          if (amountA == null && amountB == null) return 0;
          if (amountA == null) return 1;
          if (amountB == null) return -1;
          return amountB.compareTo(amountA);
        });
        return items;
    }
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
                    _items == null
                        ? '${widget.region} 정책'
                        : '${widget.region} 정책 ${_eligibleItems.length}건',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: TossColors.textPrimary,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SortChip(
                      label: '마감임박순',
                      selected: _sortMode == _SortMode.deadline,
                      onTap: () => setState(() => _sortMode = _SortMode.deadline),
                    ),
                    _SortChip(
                      label: '최신등록순',
                      selected: _sortMode == _SortMode.latest,
                      onTap: () => setState(() => _sortMode = _SortMode.latest),
                    ),
                    _SortChip(
                      label: '지원금액 많은 순',
                      selected: _sortMode == _SortMode.amount,
                      onTap: () => setState(() => _sortMode = _SortMode.amount),
                    ),
                  ],
                ),
              ),
              if (_availableCategories.isNotEmpty || widget.profile.interests.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _CategoryChip(
                          label: '전체',
                          selected: _selectedCategory == null,
                          onTap: () => setState(() => _selectedCategory = null),
                        ),
                        if (widget.profile.interests.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _CategoryChip(
                            label: '내 관심사만',
                            selected: _interestOnly,
                            onTap: () => setState(() => _interestOnly = !_interestOnly),
                          ),
                        ],
                        for (final category in _availableCategories) ...[
                          const SizedBox(width: 8),
                          _CategoryChip(
                            label: category,
                            selected: _selectedCategory == category,
                            onTap: () => setState(() => _selectedCategory = category),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(child: _buildBody(scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(ScrollController scrollController) {
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: TossColors.textSecondary)),
      );
    }
    if (_items == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = _sortedItems;
    if (items.isEmpty) {
      return const Center(
        child: Text('조건에 맞는 정책이 없어요', style: TextStyle(color: TossColors.textSecondary)),
      );
    }
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _PolicyCard(
          item: item,
          profile: widget.profile,
          showInterestBadge: _interestOnly,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PolicyDetailScreen(
                policy: item,
                profile: widget.profile,
                onProfileUpdated: widget.onProfileUpdated,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? TossColors.primary : TossColors.fieldFill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : TossColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? TossColors.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? TossColors.primary : TossColors.textSecondary.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? TossColors.primary : TossColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({
    required this.item,
    required this.profile,
    required this.showInterestBadge,
    required this.onTap,
  });

  final PolicyItem item;
  final UserProfile profile;

  /// Only show the "관심사: ..." badge once the user has actually turned on
  /// "내 관심사만" — otherwise every card would call out interests before
  /// the user asked to see that distinction.
  final bool showInterestBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
            if (item.categoryLabel != null) ...[
              Text(
                item.categoryLabel!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: TossColors.primary,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              item.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: TossColors.textPrimary,
              ),
            ),
            if (item.period != null) ...[
              const SizedBox(height: 6),
              Text(
                item.period!,
                style: const TextStyle(fontSize: 13, color: TossColors.textSecondary),
              ),
            ],
            if (item.supportAmountLabel != null) ...[
              const SizedBox(height: 6),
              Text(
                item.supportAmountLabel!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: TossColors.primary,
                ),
              ),
            ],
            if (showInterestBadge && item.matchesInterests(profile)) ...[
              const SizedBox(height: 6),
              Text(
                '관심사: ${item.matchingInterests(profile).join(', ')}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFF8B3D),
                ),
              ),
            ],
            // 이 시트는 이제 matchesProfile(나이+소득 자격)을 만족하는 정책만 보여주므로
            // 이 뱃지가 뜰 일이 없지만, 나중에 다시 전체 보기로 바뀔 수도 있어 주석으로
            // 남겨둔다.
            // if (!item.ageMatches(profile)) ...[
            //   const SizedBox(height: 6),
            //   const Text(
            //     '나이 조건 미충족',
            //     style: TextStyle(
            //       fontSize: 12,
            //       fontWeight: FontWeight.w700,
            //       color: TossColors.error,
            //     ),
            //   ),
            // ],
          ],
        ),
      ),
    );
  }
}
