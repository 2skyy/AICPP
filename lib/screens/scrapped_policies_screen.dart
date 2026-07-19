import 'package:flutter/material.dart';
import '../models/policy_item.dart';
import '../models/user_profile.dart';
import '../theme/toss_colors.dart';
import 'policy_detail_screen.dart';

class ScrappedPoliciesScreen extends StatefulWidget {
  const ScrappedPoliciesScreen({
    super.key,
    required this.profile,
    required this.onProfileUpdated,
  });

  final UserProfile profile;
  final ValueChanged<UserProfile> onProfileUpdated;

  @override
  State<ScrappedPoliciesScreen> createState() => _ScrappedPoliciesScreenState();
}

class _ScrappedPoliciesScreenState extends State<ScrappedPoliciesScreen> {
  late UserProfile _profile = widget.profile;

  // Kept in local state (not just widget.profile) because PolicyDetailScreen
  // is pushed on top of this screen — setState here still rebuilds it even
  // while covered, so un-scrapping from the detail page shows up right away
  // when the user comes back.
  void _updateProfile(UserProfile updated) {
    setState(() => _profile = updated);
    widget.onProfileUpdated(updated);
  }

  void _unscrap(PolicyItem policy) {
    final id = policy.policyNo ?? policy.name;
    final updated =
        _profile.scrappedPolicies.where((p) => (p.policyNo ?? p.name) != id).toList();
    _updateProfile(_profile.copyWith(scrappedPolicies: updated));
  }

  @override
  Widget build(BuildContext context) {
    final items = _profile.scrappedPolicies;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TossColors.background,
        elevation: 0,
        foregroundColor: TossColors.textPrimary,
        title: const Text('스크랩한 정책'),
      ),
      body: SafeArea(
        child: items.isEmpty
            ? const _EmptyScrapView()
            : ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _ScrappedPolicyCard(
                    item: item,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PolicyDetailScreen(
                          policy: item,
                          profile: _profile,
                          onProfileUpdated: _updateProfile,
                        ),
                      ),
                    ),
                    onUnscrap: () => _unscrap(item),
                  );
                },
              ),
      ),
    );
  }
}

class _EmptyScrapView extends StatelessWidget {
  const _EmptyScrapView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bookmark_border, size: 48, color: TossColors.textSecondary),
            const SizedBox(height: 16),
            const Text(
              '아직 스크랩한 정책이 없어요',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: TossColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '정책 상세 화면에서 북마크 아이콘을 누르면\n여기에 모아볼 수 있어요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: TossColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScrappedPolicyCard extends StatelessWidget {
  const _ScrappedPolicyCard({
    required this.item,
    required this.onTap,
    required this.onUnscrap,
  });

  final PolicyItem item;
  final VoidCallback onTap;
  final VoidCallback onUnscrap;

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
        child: Row(
          children: [
            Expanded(
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
            IconButton(
              onPressed: onUnscrap,
              icon: const Icon(Icons.bookmark, color: TossColors.primary),
              tooltip: '스크랩 해제',
            ),
          ],
        ),
      ),
    );
  }
}
