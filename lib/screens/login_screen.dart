import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_api_service.dart';
import '../services/profile_api_service.dart';
import '../theme/toss_colors.dart';
import '../widgets/social_login_button.dart';
import '../widgets/toss_button.dart';
import '../widgets/toss_text_field.dart';
import 'home_shell.dart';
import 'profile_setup_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authApiService, this.profileApiService});

  final AuthApiService? authApiService;
  final ProfileApiService? profileApiService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final _authApiService = widget.authApiService ?? AuthApiService();
  late final _profileApiService = widget.profileApiService ?? ProfileApiService();

  bool _isSubmitting = false;

  bool get _canSubmit =>
      !_isSubmitting &&
      _emailController.text.isNotEmpty &&
      _passwordController.text.isNotEmpty;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _isSubmitting = true);
    try {
      final session = await _authApiService.login(
        _emailController.text,
        _passwordController.text,
      );
      final profile =
          await _profileApiService.fetchProfile(session.accessToken, email: session.email);
      if (!mounted) return;

      if (profile != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomeShell(profile: profile, profileApiService: widget.profileApiService),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ProfileSetupScreen(
              name: session.email.split('@').first,
              email: session.email,
              accessToken: session.accessToken,
              authApiService: widget.authApiService,
              profileApiService: widget.profileApiService,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
                      child: SvgPicture.asset(
                        'assets/icons/kakaotalk_logo.svg',
                        width: 26,
                        height: 26,
                        colorFilter: const ColorFilter.mode(Color(0xFF3C1E1E), BlendMode.srcIn),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SocialLoginButton(
                      backgroundColor: Colors.white,
                      semanticLabel: '구글로 로그인',
                      onTap: () => _showComingSoon('구글'),
                      child: SvgPicture.asset('assets/icons/google_logo.svg', width: 22, height: 22),
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
                      MaterialPageRoute(
                        builder: (_) => SignupScreen(
                          authApiService: widget.authApiService,
                          profileApiService: widget.profileApiService,
                        ),
                      ),
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
