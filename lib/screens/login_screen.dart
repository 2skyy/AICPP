import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../theme/toss_colors.dart';
import '../widgets/social_login_button.dart';
import '../widgets/toss_button.dart';
import '../widgets/toss_text_field.dart';
import 'main_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool get _canSubmit =>
      _emailController.text.isNotEmpty && _passwordController.text.isNotEmpty;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    final email = _emailController.text;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MainScreen(
          profile: UserProfile(
            name: email.split('@').first,
            email: email,
            age: 0,
            gender: '',
            school: '',
            gpa: 0,
            enrollmentStatus: '',
            region: '서울특별시',
            interestedRegions: const [],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$provider 로그인은 준비 중이에요')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              const Text(
                '안녕하세요!\n이메일로 로그인해주세요',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: TossColors.textPrimary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 40),
              TossTextField(
                label: '이메일',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              TossTextField(
                label: '비밀번호',
                controller: _passwordController,
                obscureText: true,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 40),
              TossButton(
                label: '로그인',
                onPressed: _canSubmit ? _login : null,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Divider(color: TossColors.disabled)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '또는',
                      style: TextStyle(fontSize: 13, color: TossColors.textSecondary),
                    ),
                  ),
                  Expanded(child: Divider(color: TossColors.disabled)),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SocialLoginButton(
                      backgroundColor: const Color(0xFFFEE500),
                      semanticLabel: '카카오톡으로 로그인',
                      onTap: () => _showComingSoon('카카오톡'),
                      child: const Icon(
                        Icons.chat_bubble,
                        color: Color(0xFF3C1E1E),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SocialLoginButton(
                      backgroundColor: Colors.white,
                      semanticLabel: '구글로 로그인',
                      onTap: () => _showComingSoon('구글'),
                      child: const Text(
                        'G',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4285F4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SocialLoginButton(
                      backgroundColor: Colors.black,
                      semanticLabel: 'iCloud로 로그인',
                      onTap: () => _showComingSoon('iCloud'),
                      child: const Icon(Icons.apple, color: Colors.white, size: 26),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                    );
                  },
                  child: const Text(
                    '회원가입',
                    style: TextStyle(
                      color: TossColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
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
