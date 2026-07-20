import 'policy_item.dart';
import '../constants/median_income.dart';
import '../utils/age.dart';

class UserProfile {
  const UserProfile({
    required this.name,
    required this.email,
    required this.birthDate,
    required this.gender,
    required this.school,
    required this.gpa,
    required this.enrollmentStatus,
    required this.region,
    required this.interestedRegions,
    this.interests = const [],
    this.scrappedPolicies = const [],
    this.householdSize,
    this.monthlyIncome,
    this.militaryServiceStatus,
  });

  final String name;
  final String email;
  final DateTime? birthDate;
  final String gender;
  final String school;
  final double gpa;
  final String enrollmentStatus;
  final String region;
  final List<String> interestedRegions;
  final List<String> interests;
  final List<PolicyItem> scrappedPolicies;

  /// 가구원수 (1~6, 6은 "6인 이상"), null이면 아직 입력 안 함.
  final int? householdSize;

  /// 월 소득 (만원 단위), null이면 아직 입력 안 함.
  final int? monthlyIncome;

  /// 병역 이행 여부 ('군필' | '미필' | '공익' | '면제'). 남성일 때만 입력받으며,
  /// 그 외에는 null.
  final String? militaryServiceStatus;

  bool isScrapped(PolicyItem policy) {
    final id = policy.policyNo ?? policy.name;
    return scrappedPolicies.any((p) => (p.policyNo ?? p.name) == id);
  }

  int get age => birthDate == null ? 0 : calculateAge(birthDate!);

  /// 가구원수 + 월소득으로 계산한 기준중위소득 대비 비율(%). 둘 중 하나라도
  /// 입력 안 됐으면 null.
  int? get incomePercent {
    final size = householdSize;
    final income = monthlyIncome;
    if (size == null || income == null) return null;
    final median = medianIncomeFor(size);
    if (median == null || median == 0) return null;
    return ((income * 10000) / median * 100).round();
  }

  /// [incomePercent]를 사람이 읽기 쉬운 문장으로 표현한 것.
  String? get incomeBracketLabel {
    final percent = incomePercent;
    if (percent == null) return null;
    return '기준중위소득 약 $percent%';
  }

  UserProfile copyWith({
    String? name,
    String? email,
    DateTime? birthDate,
    String? gender,
    String? school,
    double? gpa,
    String? enrollmentStatus,
    String? region,
    List<String>? interestedRegions,
    List<String>? interests,
    List<PolicyItem>? scrappedPolicies,
    int? householdSize,
    int? monthlyIncome,
    String? militaryServiceStatus,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      school: school ?? this.school,
      gpa: gpa ?? this.gpa,
      enrollmentStatus: enrollmentStatus ?? this.enrollmentStatus,
      region: region ?? this.region,
      interestedRegions: interestedRegions ?? this.interestedRegions,
      interests: interests ?? this.interests,
      scrappedPolicies: scrappedPolicies ?? this.scrappedPolicies,
      householdSize: householdSize ?? this.householdSize,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      militaryServiceStatus: militaryServiceStatus ?? this.militaryServiceStatus,
    );
  }
}
