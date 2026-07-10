import 'package:flutter/material.dart';
import '../theme/toss_colors.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TossColors.background,
        elevation: 0,
        foregroundColor: TossColors.textPrimary,
        title: const Text('채팅'),
      ),
      body: const Center(
        child: Text(
          '채팅 기능은 준비 중이에요',
          style: TextStyle(color: TossColors.textSecondary),
        ),
      ),
    );
  }
}
