import 'package:flutter/material.dart';
import '../constants/interests.dart';
import '../constants/median_income.dart';
import '../constants/regions.dart';
import '../constants/universities.dart';
import '../models/user_profile.dart';
import '../services/auth_api_service.dart';
import '../services/profile_api_service.dart';
import '../theme/toss_colors.dart';
import '../utils/age.dart';
import '../utils/gpa_input_formatter.dart';
import '../utils/validators.dart';
import '../widgets/income_bracket_info_dialog.dart';
import '../widgets/toss_autocomplete_field.dart';
import '../widgets/toss_button.dart';
import '../widgets/toss_chip_selector.dart';
import '../widgets/toss_text_field.dart';
import 'login_screen.dart';

const _genderOptions = ['남성', '여성'];
const _enrollmentOptions = ['재학', '휴학', '졸업', '졸업유예', '해당없음'];
const _militaryServiceOptions = ['군필', '미필', '공익', '면제'];

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    required this.name,
    required this.email,
    required this.accessToken,
    this.authApiService,
    this.profileApiService,
  });

  final String name;
  final String email;
  final String accessToken;
  final AuthApiService? authApiService;
  final ProfileApiService? profileApiService;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _birthDateController = TextEditingController();
  final _schoolController = TextEditingController();
  final _schoolFocusNode = FocusNode();
  final _gpaController = TextEditingController();
  final _monthlyIncomeController = TextEditingController();

  DateTime? _birthDate;
  String? _gender;
  String? _militaryServiceStatus;
  String? _enrollmentStatus;
  String? _region;
  final Set<String> _interestedRegions = {};
  final Set<String> _interests = {};
  int? _householdSize;
  late final _profileApiService = widget.profileApiService ?? ProfileApiService();

  bool _showErrors = false;
  bool _isSubmitting = false;

  int? get _monthlyIncome => int.tryParse(_monthlyIncomeController.text);

  String? get _incomeBracketLabel {
    if (_householdSize == null || _monthlyIncome == null) return null;
    final median = medianIncomeFor(_householdSize!);
    if (median == null || median == 0) return null;
    final percent = ((_monthlyIncome! * 10000) / median * 100).round();
    return '기준중위소득 약 $percent%';
  }

  @override
  void dispose() {
    _birthDateController.dispose();
    _schoolController.dispose();
    _schoolFocusNode.dispose();
    _gpaController.dispose();
    _monthlyIncomeController.dispose();
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
      final age = calculateAge(picked);
      _birthDateController.text =
          '${picked.year}년 ${picked.month}월 ${picked.day}일 (만 $age세)';
    });
  }

  String? get _ageError {
    if (!_showErrors) return null;
    return _birthDate == null ? '생년월일을 선택해주세요' : null;
  }

  bool get _isSchoolApplicable => _enrollmentStatus != '해당없음';

  String? get _schoolError {
    if (!_showErrors || !_isSchoolApplicable) return null;
    return _schoolController.text.trim().isEmpty ? '학교를 입력해주세요' : null;
  }

  String? get _gpaError {
    if (!_showErrors || !_isSchoolApplicable) return null;
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
      (!_isSchoolApplicable ||
          (_schoolController.text.trim().isNotEmpty &&
              Validators.isValidGpa(_gpaController.text))) &&
      _gender != null &&
      _enrollmentStatus != null &&
      _region != null &&
      _interestedRegions.isNotEmpty;

  Future<void> _submit() async {
    setState(() => _showErrors = true);
    if (!_canSubmit || _isSubmitting) return;

    final profile = UserProfile(
      name: widget.name,
      email: widget.email,
      birthDate: _birthDate,
      gender: _gender!,
      school: _isSchoolApplicable ? _schoolController.text.trim() : '',
      gpa: _isSchoolApplicable ? double.parse(_gpaController.text) : 0,
      enrollmentStatus: _enrollmentStatus!,
      region: _region!,
      interestedRegions: _interestedRegions.toList(),
      interests: _interests.toList(),
      householdSize: _householdSize,
      monthlyIncome: _monthlyIncome,
      militaryServiceStatus: _gender == '남성' ? _militaryServiceStatus : null,
      accessToken: widget.accessToken,
    );

    setState(() => _isSubmitting = true);
    try {
      await _profileApiService.saveProfile(widget.accessToken, profile);
      await _profileApiService.saveInterestedRegions(widget.accessToken, profile.interestedRegions);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('프로필 저장 완료! 다시 로그인해주세요')));
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            authApiService: widget.authApiService,
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
              if (_gender == '남성') ...[
                const SizedBox(height: 20),
                TossChipSelector(
                  label: '병역',
                  options: _militaryServiceOptions,
                  selected: _militaryServiceStatus == null ? {} : {_militaryServiceStatus!},
                  onToggle: (value) => setState(() => _militaryServiceStatus = value),
                ),
              ],
              if (_isSchoolApplicable) ...[
                const SizedBox(height: 20),
                TossAutocompleteField(
                  label: '학교',
                  options: kUniversities,
                  controller: _schoolController,
                  focusNode: _schoolFocusNode,
                  errorText: _schoolError,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 6),
                const Text(
                  '대학에 다니지 않는다면, 아래 재학상태에서 "해당없음"을 선택하면 학교·학점 입력을 건너뛸 수 있어요',
                  style: TextStyle(fontSize: 12, color: TossColors.textSecondary),
                ),
                const SizedBox(height: 14),
                TossTextField(
                  label: '학점 (4.5 만점)',
                  controller: _gpaController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  errorText: _gpaError,
                  onChanged: (_) => setState(() {}),
                  inputFormatters: [GpaInputFormatter()],
                ),
              ],
              const SizedBox(height: 20),
              TossChipSelector(
                label: '재학상태',
                options: _enrollmentOptions,
                selected: _enrollmentStatus == null ? {} : {_enrollmentStatus!},
                errorText: _enrollmentError,
                onToggle: (value) => setState(() {
                  _enrollmentStatus = value;
                  if (value == '해당없음') {
                    _schoolController.clear();
                    _gpaController.clear();
                  }
                }),
              ),
              const SizedBox(height: 20),
              TossChipSelector(
                label: '지역',
                options: kRegions,
                selected: _region == null ? {} : {_region!},
                errorText: _regionError,
                onToggle: (value) => setState(() {
                  _region = value;
                  _interestedRegions.remove(value);
                }),
              ),
              const SizedBox(height: 20),
              TossChipSelector(
                label: '관심지역 (최대 2개)',
                options: kRegions,
                selected: _region == null ? _interestedRegions : {..._interestedRegions, _region!},
                disabled: {
                  ?_region,
                  // 너무 많은 관심지역을 고르면 지도/리포트에 정보가 한꺼번에
                  // 몰려 보여서 2개로 제한한다 — 다 채웠으면 나머지는 잠근다.
                  if (_interestedRegions.length >= 2)
                    ...kRegions.where((r) => !_interestedRegions.contains(r)),
                },
                multiSelect: true,
                errorText: _interestedRegionsError,
                onToggle: (value) => setState(() {
                  if (_interestedRegions.contains(value)) {
                    _interestedRegions.remove(value);
                  } else if (_interestedRegions.length < 2) {
                    _interestedRegions.add(value);
                  }
                }),
              ),
              const SizedBox(height: 20),
              TossChipSelector(
                label: '관심사 (복수 선택 가능)',
                options: kInterests,
                selected: _interests,
                multiSelect: true,
                onToggle: (value) => setState(() {
                  if (_interests.contains(value)) {
                    _interests.remove(value);
                  } else {
                    _interests.add(value);
                  }
                }),
              ),
              const SizedBox(height: 20),
              TossChipSelector(
                label: '가구원수',
                options: kHouseholdSizeLabels.values.toList(),
                selected: _householdSize == null ? {} : {kHouseholdSizeLabels[_householdSize]!},
                onToggle: (label) => setState(() {
                  _householdSize =
                      kHouseholdSizeLabels.entries.firstWhere((e) => e.value == label).key;
                }),
              ),
              const SizedBox(height: 20),
              TossTextField(
                label: '월 소득 (만원 단위)',
                controller: _monthlyIncomeController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              if (_incomeBracketLabel != null) ...[
                const SizedBox(height: 6),
                Text(
                  _incomeBracketLabel!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: TossColors.primary,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => showIncomeBracketInfo(context),
                child: const Text(
                  '소득구간은 어떻게 계산되나요?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: TossColors.textSecondary,
                  ),
                ),
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
