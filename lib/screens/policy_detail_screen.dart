import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/policy_item.dart';
import '../theme/toss_colors.dart';

class PolicyDetailScreen extends StatelessWidget {
  const PolicyDetailScreen({super.key, required this.policy});

  final PolicyItem policy;

  String get _ageRangeText {
    if (policy.minAge == null && policy.maxAge == null) return '-';
    if (policy.minAge != null && policy.maxAge != null) {
      return '만 ${policy.minAge}세 ~ ${policy.maxAge}세';
    }
    return '만 ${policy.minAge ?? policy.maxAge}세 이상';
  }

  Future<void> _openApplyUrl(BuildContext context) async {
    final url = policy.applyUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('신청 페이지를 열 수 없어요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TossColors.background,
        elevation: 0,
        foregroundColor: TossColors.textPrimary,
        title: const Text('정책 상세'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (policy.category != null) ...[
                Chip(
                  label: Text(policy.category!),
                  backgroundColor: TossColors.fieldFill,
                  side: BorderSide.none,
                ),
                const SizedBox(height: 12),
              ],
              Text(
                policy.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: TossColors.textPrimary,
                  height: 1.35,
                ),
              ),
              if (policy.organization != null) ...[
                const SizedBox(height: 8),
                Text(
                  policy.organization!,
                  style: const TextStyle(fontSize: 14, color: TossColors.textSecondary),
                ),
              ],
              const SizedBox(height: 32),
              _DetailSection(label: '지원대상', content: _ageRangeText),
              _DetailSection(label: '신청기간', content: policy.period ?? '상시'),
              if (policy.supportContent != null)
                _DetailSection(label: '지원내용', content: policy.supportContent!),
              if (policy.applyMethod != null)
                _DetailSection(label: '신청방법', content: policy.applyMethod!),
              if (policy.description != null)
                _DetailSection(label: '정책설명', content: policy.description!),
              if (policy.applyUrl != null) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => _openApplyUrl(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TossColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      '신청 페이지로 이동',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.label, required this.content});

  final String label;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: TossColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              color: TossColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
