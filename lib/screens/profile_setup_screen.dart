import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/regions.dart';
import '../models/user_profile.dart';
import '../theme/toss_colors.dart';
import '../utils/validators.dart';
import '../widgets/toss_button.dart';
import '../widgets/toss_chip_selector.dart';
import '../widgets/toss_text_field.dart';
import 'main_screen.dart';

const _genderOptions = ['남성', '여성'];
const _enrollmentOptions = ['재학', '휴학', '졸업', '졸업유예'];

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, required this.name, required this.email});

  final String name;
  final String email;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _birthDateController = TextEditingController();
  final _schoolController = TextEditingController();
  final _gpaController = TextEditingController();

  DateTime? _birthDate;
  String? _gender;
  String? _enrollmentStatus;
  String? _region;
  final Set<String> _interestedRegions = {};

  bool _showErrors = false;

  @override
  void dispose() {
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
      final age = _calculateAge(picked);
      _birthDateController.text =
          '${picked.year}년 ${picked.month}월 ${picked.day}일 (만 $age세)';
    });
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
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

  String? get _interestedRegionsError =>
      (_showErrors && _interestedRegions.isEmpty) ? '관심지역을 하나 이상 선택해주세요' : null;

  bool get _canSubmit =>
      _birthDate != null &&
      _schoolController.text.trim().isNotEmpty &&
      Validators.isValidGpa(_gpaController.text) &&
      _gender != null &&
      _enrollmentStatus != null &&
      _region != null &&
      _interestedRegions.isNotEmpty;

  void _submit() {
    setState(() => _showErrors = true);
    if (!_canSubmit) return;

    final profile = UserProfile(
      name: widget.name,
      email: widget.email,
      age: _calculateAge(_birthDate!),
      gender: _gender!,
      school: _schoolController.text.trim(),
      gpa: double.parse(_gpaController.text),
      enrollmentStatus: _enrollmentStatus!,
      region: _region!,
      interestedRegions: _interestedRegions.toList(),
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => MainScreen(profile: profile)),
    );
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
                '프로필을 완성해주세요',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: TossColors.textPrimary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 32),
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
                inputFormatters: [_GpaInputFormatter()],
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
              const SizedBox(height: 20),
              TossChipSelector(
                label: '관심지역 (복수 선택 가능)',
                options: kRegions,
                selected: _interestedRegions,
                multiSelect: true,
                errorText: _interestedRegionsError,
                onToggle: (value) => setState(() {
                  if (_interestedRegions.contains(value)) {
                    _interestedRegions.remove(value);
                  } else {
                    _interestedRegions.add(value);
                  }
                }),
              ),
              const SizedBox(height: 40),
              TossButton(label: '완료', onPressed: _submit),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _GpaInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(text)) return oldValue;

    final parsed = double.tryParse(text);
    if (parsed == null) return newValue;

    final decimalIndex = text.indexOf('.');
    final hasExtraDecimals =
        decimalIndex != -1 && text.length - decimalIndex - 1 > 2;
    final rounded =
        hasExtraDecimals ? double.parse(parsed.toStringAsFixed(2)) : parsed;

    if (rounded > 4.5) return oldValue;
    if (!hasExtraDecimals) return newValue;

    final formatted = rounded.toStringAsFixed(2);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
