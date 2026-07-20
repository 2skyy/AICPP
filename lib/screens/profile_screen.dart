import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../theme/toss_colors.dart';
import 'edit_profile_screen.dart';
// 관심지역 섹션과 함께 안 쓰지만, 나중에 다시 쓸 수도 있어 주석으로 남겨둔다.
// import 'interested_region_screen.dart';
import 'login_screen.dart';
import 'scrapped_policies_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.onProfileUpdated,
  });

  final UserProfile profile;
  final ValueChanged<UserProfile> onProfileUpdated;

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('로그아웃 하시겠어요?'),
        content: const Text('다시 로그인해야 이용할 수 있어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('로그아웃', style: TextStyle(color: TossColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // rootNavigator: true — HomeShell wraps its tabs in a nested Navigator
    // (so the floating chat button survives pushes like policy detail).
    // Logging out needs to replace the whole app, including that shell.
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
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

  // 관심지역 섹션과 함께 안 쓰지만, 나중에 다시 쓸 수도 있어 주석으로 남겨둔다.
  // Future<void> _editInterestedRegions(BuildContext context) async {
  //   final updated = await Navigator.of(context).push<List<String>>(
  //     MaterialPageRoute(
  //       builder: (_) => InterestedRegionScreen(
  //         initialRegions: profile.interestedRegions,
  //         homeRegion: profile.region,
  //       ),
  //     ),
  //   );
  //   if (updated != null) onProfileUpdated(profile.copyWith(interestedRegions: updated));
  // }

  void _openScrappedPolicies(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScrappedPoliciesScreen(
          profile: profile,
          onProfileUpdated: onProfileUpdated,
        ),
      ),
    );
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
              if (profile.gender == '남성')
                _ProfileInfoRow(
                  label: '병역',
                  value: profile.militaryServiceStatus ?? '-',
                ),
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
              _ProfileInfoRow(
                label: '기준중위소득 구간',
                value: profile.incomeBracketLabel ?? '-',
              ),
              // 관심지역 섹션: 지도 탭에서 이미 지역별로 색/건수를 충분히 구분해서
              // 보여주므로 중복이라 뺐다. 나중에 다시 쓸 수도 있어 주석으로 남겨둔다.
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //   children: [
              //     const Text(
              //       '관심지역',
              //       style: TextStyle(
              //         fontSize: 14,
              //         fontWeight: FontWeight.w600,
              //         color: TossColors.textSecondary,
              //       ),
              //     ),
              //     GestureDetector(
              //       onTap: () => _editInterestedRegions(context),
              //       child: const Text(
              //         '관리',
              //         style: TextStyle(
              //           fontSize: 13,
              //           fontWeight: FontWeight.w600,
              //           color: TossColors.primary,
              //         ),
              //       ),
              //     ),
              //   ],
              // ),
              // const SizedBox(height: 8),
              // profile.interestedRegions.isEmpty
              //     ? const Text(
              //         '설정된 관심지역이 없어요',
              //         style: TextStyle(fontSize: 14, color: TossColors.textSecondary),
              //       )
              //     : Wrap(
              //         spacing: 8,
              //         runSpacing: 8,
              //         children: profile.interestedRegions
              //             .map((region) => Chip(
              //                   label: Text(region),
              //                   backgroundColor: TossColors.fieldFill,
              //                   side: BorderSide.none,
              //                 ))
              //             .toList(),
              //       ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '관심사',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: TossColors.textSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _editProfile(context),
                    child: const Text(
                      '관리',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: TossColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              profile.interests.isEmpty
                  ? const Text(
                      '설정된 관심사가 없어요',
                      style: TextStyle(fontSize: 14, color: TossColors.textSecondary),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: profile.interests
                          .map((interest) => Chip(
                                label: Text(interest),
                                backgroundColor: TossColors.fieldFill,
                                side: BorderSide.none,
                              ))
                          .toList(),
                    ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => _openScrappedPolicies(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '스크랩한 정책',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: TossColors.textSecondary,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${profile.scrappedPolicies.length}건',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: TossColors.primary,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: TossColors.textSecondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Center(
                child: TextButton(
                  onPressed: () => _confirmLogout(context),
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
