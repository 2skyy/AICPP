/// Curated list of common youth-policy topic keywords. Order matters: more
/// specific terms are listed before broader ones they could be confused
/// with (e.g. `장학금` before `교육`).
const _topicKeywords = [
  '전세', '월세', '주거', '주택', '기숙사',
  '취업', '일자리', '채용', '인턴', '구직',
  '창업', '사업화',
  '장학금', '등록금', '학자금', '교육',
  '지원금', '생활비', '수당', '복지',
  '문화', '여가', '동아리',
  '건강', '의료', '상담',
  '대출', '저축', '금융',
  '참여', '권리',
];

/// Finds the first known policy-topic keyword that appears as a substring
/// of [question]. Returns null if no known keyword is found.
String? extractTopicKeyword(String question) {
  for (final keyword in _topicKeywords) {
    if (question.contains(keyword)) return keyword;
  }
  return null;
}

final _hasLetters = RegExp(r'[가-힣a-zA-Z]');

/// Whether [text] is long enough and contains real letters, as opposed to
/// noise like "." or "1" that shouldn't trigger a search.
bool looksLikeQuestion(String text) {
  return text.length >= 2 && _hasLetters.hasMatch(text);
}
