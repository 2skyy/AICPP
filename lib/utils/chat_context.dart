import '../models/user_profile.dart';

/// Short, human-readable summary of the profile fields used to scope
/// policy matching (shown as a tag under assistant replies).
String buildUserContextLabel(UserProfile profile) {
  final parts = <String>[
    profile.region,
    if (profile.enrollmentStatus.isNotEmpty) profile.enrollmentStatus,
    if (profile.age > 0) '${profile.age}세',
  ];
  return parts.join(' · ');
}

/// System prompt that will be sent to the LLM once it's wired up. It scopes
/// the assistant to the user's profile so it only answers with policies
/// that actually match them.
String buildSystemPrompt(UserProfile profile) {
  return '''
너는 청년 정책 안내 어시스턴트야. 아래 사용자 정보에 해당하는 정책만 근거로 답변해.
정보에 없는 내용은 추측하지 말고, 조건에 맞는 정책이 없으면 없다고 말해.

[사용자 정보]
- 지역: ${profile.region}
- 재학상태: ${profile.enrollmentStatus.isEmpty ? '미상' : profile.enrollmentStatus}
- 나이: ${profile.age > 0 ? '${profile.age}세' : '미상'}
- 학교: ${profile.school.isEmpty ? '미상' : profile.school}
- 관심지역: ${profile.interestedRegions.isEmpty ? '없음' : profile.interestedRegions.join(', ')}
''';
}
