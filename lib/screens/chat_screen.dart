import 'package:flutter/material.dart';
import '../models/policy_item.dart';
import '../models/user_profile.dart';
import '../services/policy_api_service.dart';
import '../theme/toss_colors.dart';
import '../utils/chat_context.dart';
import '../utils/keyword_extractor.dart';

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

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.profile, this.policyApiService});

  final UserProfile profile;
  final PolicyApiService? policyApiService;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _messages = <_ChatMessage>[];
  final _history = <_ChatSession>[];
  late final _policyApi = widget.policyApiService ?? PolicyApiService();

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
      final keyword = extractTopicKeyword(question);
      if (keyword != null) {
        final result = await _policyApi.search(topic: keyword);
        final openItems = result.items.where((item) => item.isCurrentlyOpen).toList();
        replyText = openItems.isEmpty
            ? '"$keyword" 관련 신청 가능한 정책을 찾지 못했어요.'
            : '"$keyword" 관련 신청 가능한 정책 ${openItems.length}건이 있어요.\n${_formatResults(openItems)}';
      } else if (!looksLikeQuestion(question)) {
        replyText = '질문을 이해하지 못했어요. 주거, 취업, 창업, 교육, 복지 같은 키워드를 포함해서 다시 질문해주세요.';
      } else {
        final result = await _policyApi.search(name: widget.profile.region, size: 30);
        final matchedItems = result.items
            .where((item) => item.isCurrentlyOpen && item.matchesProfile(widget.profile))
            .toList();
        replyText = matchedItems.isEmpty
            ? '조건에 맞는 정책을 찾지 못했어요. 주거, 취업, 창업, 교육, 복지 같은 키워드를 포함해서 다시 질문해보세요.'
            : '${widget.profile.region}에서 내 조건에 맞는 정책 ${matchedItems.length}건이 있어요.\n${_formatResults(matchedItems)}';
      }
    } on PolicyApiException catch (e) {
      replyText = e.message;
    }

    if (!mounted) return;
    setState(() {
      _messages.removeLast();
      _messages.add(_ChatMessage(text: replyText, isUser: false, contextLabel: contextLabel));
    });
  }

  String _formatResults(List<PolicyItem> items) {
    return items
        .asMap()
        .entries
        .map((entry) => '${entry.key + 1}. ${entry.value.name}')
        .join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TossColors.background,
        elevation: 0,
        foregroundColor: TossColors.textPrimary,
        title: const Text('정책 어시스턴트'),
        actions: [
          IconButton(
            onPressed: _messages.isEmpty ? null : _startNewConversation,
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: '새 대화',
          ),
          IconButton(
            onPressed: _history.isEmpty ? null : _openHistory,
            icon: const Icon(Icons.history),
            tooltip: '대화 이력',
          ),
        ],
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
