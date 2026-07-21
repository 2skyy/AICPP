import 'package:flutter/material.dart';
import '../services/auth_api_service.dart';
import '../services/profile_api_service.dart';
import '../theme/toss_colors.dart';
import '../utils/validators.dart';
import '../widgets/toss_button.dart';
import '../widgets/toss_text_field.dart';
import 'profile_setup_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, this.authApiService, this.profileApiService});

  final AuthApiService? authApiService;
  final ProfileApiService? profileApiService;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  late final _authApiService = widget.authApiService ?? AuthApiService();

  bool _showErrors = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  String? get _nameError {
    if (!_showErrors) return null;
    return _nameController.text.trim().isEmpty ? '이름을 입력해주세요' : null;
  }

  String? get _emailError {
    if (!_showErrors || _emailController.text.isEmpty) return null;
    return Validators.isValidEmail(_emailController.text)
        ? null
        : '올바른 이메일 형식이 아니에요';
  }

  String? get _passwordError {
    if (!_showErrors || _passwordController.text.isEmpty) return null;
    return Validators.isValidPassword(_passwordController.text)
        ? null
        : '비밀번호는 8자 이상이어야 해요';
  }

  String? get _passwordConfirmError {
    if (!_showErrors || _passwordConfirmController.text.isEmpty) return null;
    return _passwordConfirmController.text == _passwordController.text
        ? null
        : '비밀번호가 일치하지 않아요';
  }

  bool get _canSubmit =>
      !_isSubmitting &&
      _nameController.text.trim().isNotEmpty &&
      Validators.isValidEmail(_emailController.text) &&
      Validators.isValidPassword(_passwordController.text) &&
      _passwordConfirmController.text == _passwordController.text;

  Future<void> _submit() async {
    setState(() => _showErrors = true);
    if (!_canSubmit) return;

    setState(() => _isSubmitting = true);
    try {
      final session = await _authApiService.signUp(
        _emailController.text,
        _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProfileSetupScreen(
            name: _nameController.text.trim(),
            email: session.email,
            accessToken: session.accessToken,
            profileApiService: widget.profileApiService,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TossColors.background,
        elevation: 0,
        foregroundColor: TossColors.textPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '반가워요!\n먼저 회원 정보를 입력해주세요',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: TossColors.textPrimary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 32),
              TossTextField(
                label: '이름',
                controller: _nameController,
                errorText: _nameError,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              TossTextField(
                label: '이메일',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                errorText: _emailError,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              TossTextField(
                label: '비밀번호',
                controller: _passwordController,
                obscureText: true,
                errorText: _passwordError,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              TossTextField(
                label: '비밀번호 확인',
                controller: _passwordConfirmController,
                obscureText: true,
                errorText: _passwordConfirmError,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 40),
              TossButton(label: '가입하기', onPressed: _submit),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
