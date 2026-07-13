import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../theme/toss_colors.dart';
import 'chat_screen.dart';
import 'main_screen.dart';
import 'profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.profile});

  final UserProfile profile;

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
          ),
          ChatScreen(profile: _profile),
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
