import 'package:flutter/material.dart';
import '../theme/toss_colors.dart';

Future<void> showIncomeBracketInfo(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('소득구간은 어떻게 계산되나요?'),
      content: const Text(
        '입력하신 가구원수와 월 소득을, 보건복지부가 매년 발표하는 '
        '"기준중위소득"(2026년 기준)과 비교해서 대략적인 소득구간을 '
        '자동으로 계산해드려요.\n\n'
        '예) 4인 가구 기준중위소득은 월 약 649만원이에요. 월 소득이 '
        '325만원이면 대략 50%, 974만원이면 대략 150%에 해당해요.\n\n'
        '가구원수가 6인을 넘으면 6인 기준으로 계산돼서 실제보다 다소 '
        '높게 나올 수 있어요. 소득을 입력하지 않으면 소득 조건과 상관없이 '
        '정책을 보여드려요.',
        style: TextStyle(color: TossColors.textSecondary, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('확인'),
        ),
      ],
    ),
  );
}
