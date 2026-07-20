import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/chat_api_service.dart';
import '../services/news_api_service.dart';
import '../services/policy_api_service.dart';
import '../theme/toss_colors.dart';
import '../widgets/chat_panel.dart';
import 'main_screen.dart';
import 'profile_screen.dart';
import 'report_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.profile,
    this.mapPolicyApiService,
    this.reportPolicyApiService,
    this.reportNewsApiService,
    this.chatApiService,
  });

  final UserProfile profile;
  final PolicyApiService? mapPolicyApiService;
  final PolicyApiService? reportPolicyApiService;
  final NewsApiService? reportNewsApiService;
  final ChatApiService? chatApiService;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  bool _chatOpen = false;
  late UserProfile _profile = widget.profile;

  void _updateProfile(UserProfile updated) {
    setState(() => _profile = updated);
  }

  void _handleInterestedRegionsChanged(List<String> regions) {
    _updateProfile(_profile.copyWith(interestedRegions: regions));
  }

  void _toggleChat() {
    setState(() => _chatOpen = !_chatOpen);
  }

  @override
  Widget build(BuildContext context) {
    // Height of the bottom NavigationBar (Material 3 default) plus the
    // device's own bottom safe-area inset, so the floating chat button and
    // panel sit above it instead of overlapping.
    final navBarHeight = 80 + MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        // A nested Navigator so that screens pushed from any tab (policy
        // detail, interested-region management, profile edit, ...) stay
        // "inside" this Stack instead of covering it — that's what keeps
        // the floating chat button/panel visible on every screen.
        Navigator(
          onGenerateRoute: (settings) => MaterialPageRoute(
            builder: (_) => Scaffold(
              body: IndexedStack(
                index: _currentIndex,
                children: [
                  MainScreen(
                    profile: _profile,
                    onInterestedRegionsChanged: _handleInterestedRegionsChanged,
                    onProfileUpdated: _updateProfile,
                    policyApiService: widget.mapPolicyApiService,
                  ),
                  ReportScreen(
                    profile: _profile,
                    onProfileUpdated: _updateProfile,
                    policyApiService: widget.reportPolicyApiService,
                    newsApiService: widget.reportNewsApiService,
                  ),
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
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: '프로필',
                  ),
                ],
              ),
            ),
          ),
        ),
        // 프로필 탭에서는 채팅 버튼/패널을 아예 빼둔다.
        if (_currentIndex != 2) ...[
          Positioned(
            // 좌우를 같은 값으로 고정해서 여백이 대칭이 되게 하고, 위/아래도 둘 다
            // 고정해서 그 사이 세로 공간을 (버튼 위까지) 꽉 채운다.
            left: 16,
            right: 16,
            top: MediaQuery.of(context).padding.top + 16,
            bottom: navBarHeight + 16 + 56 + 12,
            child: Visibility(
              visible: _chatOpen,
              maintainState: true,
              child: ChatPanel(
                profile: _profile,
                chatApiService: widget.chatApiService,
                onClose: () => setState(() => _chatOpen = false),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: navBarHeight + 16,
            child: FloatingActionButton(
              heroTag: 'chat_toggle',
              backgroundColor: TossColors.primary,
              onPressed: _toggleChat,
              child: Icon(
                _chatOpen ? Icons.close : Icons.chat_bubble_outline,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
