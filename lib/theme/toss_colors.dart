import 'package:flutter/material.dart';

class TossColors {
  TossColors._();

  static const primary = Color(0xFF3182F6);

  /// 모아폴리 정책 어시스턴트(폴리) 전용 강조색 — 앱 아이콘/스플래시의 개구리
  /// 몸통 초록색과 맞췄다. 그 외 화면은 계속 [primary]를 쓴다.
  static const assistantPrimary = Color(0xFF40916C);
  static const background = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF191F28);
  static const textSecondary = Color(0xFF8B95A1);
  static const fieldFill = Color(0xFFF2F4F6);
  static const error = Color(0xFFF04452);
  static const disabled = Color(0xFFD1D6DB);
}
