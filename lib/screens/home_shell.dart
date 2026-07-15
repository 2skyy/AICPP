import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/policy_api_service.dart';
import '../theme/toss_colors.dart';
import 'chat_screen.dart';
import 'main_screen.dart';
import 'profile_screen.dart';
import 'report_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.profile,
    this.mapPolicyApiService,
    this.reportPolicyApiService,
    this.chatPolicyApiService,
  });

  final UserProfile profile;
  final PolicyApiService? mapPolicyApiService;
  final PolicyApiService? reportPolicyApiService;
  final PolicyApiService? chatPolicyApiService;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  late UserProfile _profile = widget.profile;

  void _updateProfile(UserProfile updated) {
    setState(() => _profile = updated);
  }

  void _handleInterestedRegionsChanged(List<String> regions) {
    _updateProfile(_profile.copyWith(interestedRegions: regions));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          MainScreen(
            profile: _profile,
            onInterestedRegionsChanged: _handleInterestedRegionsChanged,
            policyApiService: widget.mapPolicyApiService,
          ),
          ReportScreen(
            profile: _profile,
            onProfileUpdated: _updateProfile,
            policyApiService: widget.reportPolicyApiService,
          ),
          ChatScreen(profile: _profile, policyApiService: widget.chatPolicyApiService),
          ProfileScreen(profile: _profile, onProfileUpdated: _updateProfile),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: TossColors.background,
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: '지도',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '리포트',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: '채팅',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '프로필',
          ),
        ],
      ),
    );
  }
}
