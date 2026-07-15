import 'package:flutter/material.dart';
import '../models/policy_item.dart';
import '../models/user_profile.dart';
import '../screens/policy_detail_screen.dart';
import '../services/policy_api_service.dart';
import '../theme/toss_colors.dart';

enum _SortMode { deadline, latest, matching }

class PolicyListSheet extends StatefulWidget {
  const PolicyListSheet({
    super.key,
    required this.region,
    required this.profile,
    this.policyApiService,
  });

  final String region;
  final UserProfile profile;
  final PolicyApiService? policyApiService;

  @override
  State<PolicyListSheet> createState() => _PolicyListSheetState();
}

class _PolicyListSheetState extends State<PolicyListSheet> {
  late final _policyApi = widget.policyApiService ?? PolicyApiService();
  List<PolicyItem>? _items;
  String? _error;
  _SortMode _sortMode = _SortMode.deadline;

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
      final result = await _policyApi.search(name: widget.region, size: 30);
      if (!mounted) return;
      setState(() => _items = result.items.where((item) => item.isCurrentlyOpen).toList());
    } on PolicyApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  List<PolicyItem> get _sortedItems {
    final items = List<PolicyItem>.from(_items ?? const []);
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
      case _SortMode.matching:
        return items.where((item) => item.matchesProfile(widget.profile)).toList();
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
                        : '${widget.region} 정책 ${_items!.length}건',
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
                      label: '내게 맞는 것만',
                      selected: _sortMode == _SortMode.matching,
                      onTap: () => setState(() => _sortMode = _SortMode.matching),
                    ),
                  ],
                ),
              ),
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
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PolicyDetailScreen(policy: item)),
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

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({required this.item, required this.onTap});

  final PolicyItem item;
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
          ],
        ),
      ),
    );
  }
}
