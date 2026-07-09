class UserProfile {
  const UserProfile({
    required this.name,
    required this.email,
    required this.age,
    required this.gender,
    required this.school,
    required this.gpa,
    required this.enrollmentStatus,
    required this.region,
    required this.interestedRegions,
  });

  final String name;
  final String email;
  final int age;
  final String gender;
  final String school;
  final double gpa;
  final String enrollmentStatus;
  final String region;
  final List<String> interestedRegions;
}
