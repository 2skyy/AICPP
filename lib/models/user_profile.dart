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

  int get age => birthDate == null ? 0 : calculateAge(birthDate!);

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
    );
  }
}
