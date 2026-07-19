/// 2026년 기준 중위소득 (보건복지부 고시), 가구원수별 월 기준액(원).
/// 출처: 보건복지부 보도자료 "2026년도 기준 중위소득 6.51% 역대 최대로 인상".
const Map<int, int> kMedianIncomeByHouseholdSize2026 = {
  1: 2564238,
  2: 4199292,
  3: 5359036,
  4: 6494738,
  5: 7556719,
  6: 8555952,
};

/// [householdSize]의 월 기준 중위소득(원)을 반환한다. 1~6인만 공식 수치가
/// 있어서, 6인을 초과하면 6인 기준액으로 근사한다 (과소추정될 수 있음).
int? medianIncomeFor(int householdSize) {
  if (householdSize < 1) return null;
  final clamped = householdSize > 6 ? 6 : householdSize;
  return kMedianIncomeByHouseholdSize2026[clamped];
}

/// 가구원수 선택지 라벨. UI 칩 선택자에 그대로 쓰고, 선택된 라벨의 키(1~6)를
/// [householdSize]로 저장한다.
const Map<int, String> kHouseholdSizeLabels = {
  1: '1인',
  2: '2인',
  3: '3인',
  4: '4인',
  5: '5인',
  6: '6인 이상',
};
