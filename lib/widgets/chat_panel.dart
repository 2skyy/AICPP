import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/chat_api_service.dart';
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

class _ChatSession {
  _ChatSession({required this.startedAt, required this.messages});

  final DateTime startedAt;
  final List<_ChatMessage> messages;

  String get preview {
    final firstQuestion = messages.firstWhere(
      (message) => message.isUser,
      orElse: () => messages.first,
    );
    return firstQuestion.text;
  }
}

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inHours < 1) return '${diff.inMinutes}분 전';
  if (diff.inDays < 1) return '${diff.inHours}시간 전';
  return '${diff.inDays}일 전';
}

/// Small floating chat window that overlays the current screen instead of
/// navigating to a full page — the caller keeps whatever's behind it visible.
class ChatPanel extends StatefulWidget {
  const ChatPanel({
    super.key,
    required this.profile,
    required this.onClose,
    this.chatApiService,
  });

  final UserProfile profile;
  final VoidCallback onClose;
  final ChatApiService? chatApiService;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _controller = TextEditingController();
  final _messages = <_ChatMessage>[];
  final _history = <_ChatSession>[];
  late final _chatApi = widget.chatApiService ?? ChatApiService();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startNewConversation() {
    if (_messages.isEmpty) return;
    setState(() {
      _history.insert(0, _ChatSession(startedAt: DateTime.now(), messages: List.of(_messages)));
      _messages.clear();
    });
  }

  Future<void> _openHistory() async {
    final selected = await showModalBottomSheet<_ChatSession>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ChatHistorySheet(sessions: _history),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _history.remove(selected);
      if (_messages.isNotEmpty) {
        _history.insert(0, _ChatSession(startedAt: DateTime.now(), messages: List.of(_messages)));
      }
      _messages
        ..clear()
        ..addAll(selected.messages);
    });
  }

  Future<void> _send([String? text]) async {
    final question = (text ?? _controller.text).trim();
    if (question.isEmpty) return;

    final contextLabel = buildUserContextLabel(widget.profile);
    setState(() {
      _messages.add(_ChatMessage(text: question, isUser: true));
      _messages.add(_ChatMessage(text: '검색하고 있어요...', isUser: false));
    });
    _controller.clear();

    String replyText;
    try {
      replyText = await _chatApi.ask(question, widget.profile);
    } on ChatApiException catch (e) {
      replyText = e.message;
    }

    if (!mounted) return;
    setState(() {
      _messages.removeLast();
      _messages.add(_ChatMessage(text: replyText, isUser: false, contextLabel: contextLabel));
    });
  }

  @override
  Widget build(BuildContext context) {
    // 크기를 스스로 정하지 않는다 — home_shell.dart가 Positioned에
    // left/right/top/bottom을 모두 줘서 좌우 여백이 같고 세로도 남는 공간을
    // 꽉 채우도록 강제한다.
    return Material(
      elevation: 12,
      color: TossColors.background,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _PanelHeader(
            hasMessages: _messages.isNotEmpty,
            hasHistory: _history.isNotEmpty,
            onNewConversation: _startNewConversation,
            onOpenHistory: _openHistory,
          ),
          Expanded(
            child: _messages.isEmpty
                ? _SuggestedQuestions(onSelect: _send)
                : LayoutBuilder(
                    builder: (context, constraints) => ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) => _ChatBubble(
                        message: _messages[index],
                        maxWidth: constraints.maxWidth * 0.85,
                      ),
                    ),
                  ),
          ),
          _ChatInputBar(controller: _controller, onSend: () => _send()),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.hasMessages,
    required this.hasHistory,
    required this.onNewConversation,
    required this.onOpenHistory,
  });

  final bool hasMessages;
  final bool hasHistory;
  final VoidCallback onNewConversation;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: TossColors.fieldFill, width: 1)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '모아폴리 정책 어시스턴트',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: TossColors.textPrimary,
              ),
            ),
          ),
          _HeaderIconButton(
            onPressed: hasMessages ? onNewConversation : null,
            icon: Icons.edit_square,
            tooltip: '새 대화',
          ),
          _HeaderIconButton(
            onPressed: hasHistory ? onOpenHistory : null,
            icon: Icons.history,
            tooltip: '대화 이력',
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.onPressed, required this.icon, required this.tooltip});

  final VoidCallback? onPressed;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 18,
      tooltip: tooltip,
      color: TossColors.textPrimary,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(),
    );
  }
}

class _SuggestedQuestions extends StatelessWidget {
  const _SuggestedQuestions({required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '안녕, 난 폴리야! 🐸',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: TossColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '나한테 질문 줘서 고마워~ 어떤 정책이 궁금해?',
            style: TextStyle(
              fontSize: 13,
              color: TossColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestedQuestions
                .map((question) => ActionChip(
                      label: Text(question, style: const TextStyle(fontSize: 12)),
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
  const _ChatBubble({required this.message, required this.maxWidth});

  final _ChatMessage message;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final alignment = message.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = message.isUser ? TossColors.primary : TossColors.fieldFill;
    final textColor = message.isUser ? Colors.white : TossColors.textPrimary;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(14),
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
                    style: const TextStyle(fontSize: 10, color: TossColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(message.text, style: TextStyle(fontSize: 13, color: textColor)),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSend(),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: '질문을 입력하세요',
                hintStyle: const TextStyle(fontSize: 13),
                filled: true,
                fillColor: TossColors.fieldFill,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onSend,
            icon: const Icon(Icons.arrow_upward, size: 18),
            color: Colors.white,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
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

class _ChatHistorySheet extends StatelessWidget {
  const _ChatHistorySheet({required this.sessions});

  final List<_ChatSession> sessions;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '대화 이력',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: TossColors.textPrimary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(session),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: TossColors.fieldFill,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: TossColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _relativeTime(session.startedAt),
                            style: const TextStyle(fontSize: 12, color: TossColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
