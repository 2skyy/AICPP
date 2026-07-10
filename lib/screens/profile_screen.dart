import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../theme/toss_colors.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.onProfileUpdated,
  });

  final UserProfile profile;
  final ValueChanged<UserProfile> onProfileUpdated;

  void _logout(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _editProfile(BuildContext context) async {
    final updated = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute(builder: (_) => EditProfileScreen(profile: profile)),
    );
    if (updated != null) onProfileUpdated(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TossColors.background,
        elevation: 0,
        foregroundColor: TossColors.textPrimary,
        title: const Text('프로필'),
        actions: [
          IconButton(
            onPressed: () => _editProfile(context),
            icon: const Icon(Icons.edit_outlined),
            tooltip: '프로필 수정',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: TossColors.fieldFill,
                      child: Text(
                        profile.name.isNotEmpty ? profile.name[0] : '?',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: TossColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: TossColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.email,
                      style: const TextStyle(fontSize: 14, color: TossColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _ProfileInfoRow(label: '나이', value: profile.age > 0 ? '${profile.age}세' : '-'),
              _ProfileInfoRow(label: '성별', value: profile.gender.isEmpty ? '-' : profile.gender),
              _ProfileInfoRow(label: '학교', value: profile.school.isEmpty ? '-' : profile.school),
              _ProfileInfoRow(
                label: '학점',
                value: profile.gpa > 0 ? profile.gpa.toStringAsFixed(2) : '-',
              ),
              _ProfileInfoRow(
                label: '재학상태',
                value: profile.enrollmentStatus.isEmpty ? '-' : profile.enrollmentStatus,
              ),
              _ProfileInfoRow(label: '지역', value: profile.region),
              const SizedBox(height: 24),
              const Text(
                '관심지역',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: TossColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              profile.interestedRegions.isEmpty
                  ? const Text(
                      '설정된 관심지역이 없어요',
                      style: TextStyle(fontSize: 14, color: TossColors.textSecondary),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: profile.interestedRegions
                          .map((region) => Chip(
                                label: Text(region),
                                backgroundColor: TossColors.fieldFill,
                                side: BorderSide.none,
                              ))
                          .toList(),
                    ),
              const SizedBox(height: 40),
              Center(
                child: TextButton(
                  onPressed: () => _logout(context),
                  child: const Text(
                    '로그아웃',
                    style: TextStyle(color: TossColors.error, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: TossColors.textSecondary)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: TossColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
