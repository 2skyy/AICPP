import 'package:flutter/material.dart';
import '../constants/regions.dart';
import '../models/user_profile.dart';
import '../theme/toss_colors.dart';
import '../utils/age.dart';
import '../utils/gpa_input_formatter.dart';
import '../utils/validators.dart';
import '../widgets/toss_button.dart';
import '../widgets/toss_chip_selector.dart';
import '../widgets/toss_text_field.dart';

const _genderOptions = ['남성', '여성'];
const _enrollmentOptions = ['재학', '휴학', '졸업', '졸업유예'];

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final _nameController = TextEditingController(text: widget.profile.name);
  late final _emailController = TextEditingController(text: widget.profile.email);
  late final _birthDateController = TextEditingController(text: _formatBirthDate(widget.profile.birthDate));
  late final _schoolController = TextEditingController(text: widget.profile.school);
  late final _gpaController =
      TextEditingController(text: widget.profile.gpa > 0 ? widget.profile.gpa.toStringAsFixed(2) : '');

  late DateTime? _birthDate = widget.profile.birthDate;
  late String? _gender = widget.profile.gender.isEmpty ? null : widget.profile.gender;
  late String? _enrollmentStatus =
      widget.profile.enrollmentStatus.isEmpty ? null : widget.profile.enrollmentStatus;
  late String? _region = widget.profile.region.isEmpty ? null : widget.profile.region;

  bool _showErrors = false;

  static String _formatBirthDate(DateTime? birthDate) {
    if (birthDate == null) return '';
    final age = calculateAge(birthDate);
    return '${birthDate.year}년 ${birthDate.month}월 ${birthDate.day}일 (만 $age세)';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _birthDateController.dispose();
    _schoolController.dispose();
    _gpaController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: '생년월일 선택',
    );
    if (picked == null) return;
    setState(() {
      _birthDate = picked;
      _birthDateController.text = _formatBirthDate(picked);
    });
  }

  String? get _nameError {
    if (!_showErrors) return null;
    return _nameController.text.trim().isEmpty ? '이름을 입력해주세요' : null;
  }

  String? get _emailError {
    if (!_showErrors) return null;
    if (_emailController.text.isEmpty) return '이메일을 입력해주세요';
    return Validators.isValidEmail(_emailController.text) ? null : '올바른 이메일 형식이 아니에요';
  }

  String? get _ageError {
    if (!_showErrors) return null;
    return _birthDate == null ? '생년월일을 선택해주세요' : null;
  }

  String? get _schoolError {
    if (!_showErrors) return null;
    return _schoolController.text.trim().isEmpty ? '학교를 입력해주세요' : null;
  }

  String? get _gpaError {
    if (!_showErrors) return null;
    if (_gpaController.text.isEmpty) return '학점을 입력해주세요';
    return Validators.isValidGpa(_gpaController.text) ? null : '0~4.5 사이로 입력해주세요';
  }

  String? get _genderError => (_showErrors && _gender == null) ? '성별을 선택해주세요' : null;

  String? get _enrollmentError =>
      (_showErrors && _enrollmentStatus == null) ? '재학상태를 선택해주세요' : null;

  String? get _regionError => (_showErrors && _region == null) ? '지역을 선택해주세요' : null;

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty &&
      Validators.isValidEmail(_emailController.text) &&
      _birthDate != null &&
      _schoolController.text.trim().isNotEmpty &&
      Validators.isValidGpa(_gpaController.text) &&
      _gender != null &&
      _enrollmentStatus != null &&
      _region != null;

  void _submit() {
    setState(() => _showErrors = true);
    if (!_canSubmit) return;

    final updated = widget.profile.copyWith(
      name: _nameController.text.trim(),
      email: _emailController.text,
      birthDate: _birthDate,
      gender: _gender,
      school: _schoolController.text.trim(),
      gpa: double.parse(_gpaController.text),
      enrollmentStatus: _enrollmentStatus,
      region: _region,
    );

    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TossColors.background,
        elevation: 0,
        foregroundColor: TossColors.textPrimary,
        title: const Text('프로필 수정'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
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
                label: '생년월일',
                controller: _birthDateController,
                readOnly: true,
                onTap: _pickBirthDate,
                errorText: _ageError,
              ),
              const SizedBox(height: 20),
              TossChipSelector(
                label: '성별',
                options: _genderOptions,
                selected: _gender == null ? {} : {_gender!},
                errorText: _genderError,
                onToggle: (value) => setState(() => _gender = value),
              ),
              const SizedBox(height: 20),
              TossTextField(
                label: '학교',
                controller: _schoolController,
                errorText: _schoolError,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              TossTextField(
                label: '학점 (4.5 만점)',
                controller: _gpaController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                errorText: _gpaError,
                onChanged: (_) => setState(() {}),
                inputFormatters: [GpaInputFormatter()],
              ),
              const SizedBox(height: 20),
              TossChipSelector(
                label: '재학상태',
                options: _enrollmentOptions,
                selected: _enrollmentStatus == null ? {} : {_enrollmentStatus!},
                errorText: _enrollmentError,
                onToggle: (value) => setState(() => _enrollmentStatus = value),
              ),
              const SizedBox(height: 20),
              TossChipSelector(
                label: '지역',
                options: kRegions,
                selected: _region == null ? {} : {_region!},
                errorText: _regionError,
                onToggle: (value) => setState(() => _region = value),
              ),
              const SizedBox(height: 40),
              TossButton(label: '저장', onPressed: _submit),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
