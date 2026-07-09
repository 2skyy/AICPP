import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'config/naver_map_config.dart';
import 'screens/login_screen.dart';
import 'theme/toss_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (naverMapClientId.isNotEmpty && isNaverMapSupportedPlatform) {
    await FlutterNaverMap().init(clientId: naverMapClientId);
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AICPP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: TossColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: TossColors.primary,
          primary: TossColors.primary,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
