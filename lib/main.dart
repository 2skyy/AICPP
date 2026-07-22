import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'config/naver_map_config.dart';
import 'screens/login_screen.dart';
import 'services/auth_api_service.dart';
import 'services/profile_api_service.dart';
import 'theme/toss_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (naverMapClientId.isNotEmpty && isNaverMapSupportedPlatform) {
    await FlutterNaverMap().init(clientId: naverMapClientId);
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.authApiService, this.profileApiService});

  final AuthApiService? authApiService;
  final ProfileApiService? profileApiService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '모아폴리',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: TossColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: TossColors.primary,
          primary: TossColors.primary,
        ),
        // Material 3 기본값은 로딩 스피너 뒤에 옅은 색 원형 트랙(테두리)을
        // 깔아주는데, 우리 배경(흰색)과 어긋나 보여서 꺼둔다 — 도는 호(arc)만
        // 보이는 예전 스타일로 통일.
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          circularTrackColor: Colors.transparent,
        ),
      ),
      home: LoginScreen(authApiService: authApiService, profileApiService: profileApiService),
    );
  }
}
