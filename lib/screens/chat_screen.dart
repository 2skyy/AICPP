import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../theme/toss_colors.dart';
import '../utils/chat_context.dart';

const _suggestedQuestions = [
  '내 지역 청년 주거지원이 궁금해요',
  '재학생 대상 지원금이 있나요?',
  '나이 조건에 맞는 정책 알려줘',
];

class _ChatMessage {
  const _ChatMessage({required this.text, required this.isUser, this.contextLabel});

  final String text;
  final bool isUser;
  final String? contextLabel;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _messages = <_ChatMessage>[];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final question = (text ?? _controller.text).trim();
    if (question.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: question, isUser: true));
      _messages.add(_ChatMessage(
        text: 'AI 답변 연동은 아직 준비 중이에요. 이 질문은 아래 컨텍스트를 기반으로 답변될 예정이에요.',
        isUser: false,
        contextLabel: buildUserContextLabel(widget.profile),
      ));
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TossColors.background,
        elevation: 0,
        foregroundColor: TossColors.textPrimary,
        title: const Text('정책 어시스턴트'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? _SuggestedQuestions(onSelect: _send)
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) => _ChatBubble(message: _messages[index]),
                    ),
            ),
            _ChatInputBar(controller: _controller, onSend: () => _send()),
          ],
        ),
      ),
    );
  }
}

class _SuggestedQuestions extends StatelessWidget {
  const _SuggestedQuestions({required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '어떤 정책이 궁금하신가요?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: TossColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestedQuestions
                .map((question) => ActionChip(
                      label: Text(question),
                      backgroundColor: TossColors.fieldFill,
                      side: BorderSide.none,
                      onPressed: () => onSelect(question),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final alignment = message.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = message.isUser ? TossColors.primary : TossColors.fieldFill;
    final textColor = message.isUser ? Colors.white : TossColors.textPrimary;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.contextLabel != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '컨텍스트: ${message.contextLabel}',
                    style: const TextStyle(fontSize: 11, color: TossColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(message.text, style: TextStyle(fontSize: 15, color: textColor)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: '질문을 입력하세요',
                filled: true,
                fillColor: TossColors.fieldFill,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onSend,
            icon: const Icon(Icons.arrow_upward),
            color: Colors.white,
            style: IconButton.styleFrom(
              backgroundColor: TossColors.primary,
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
