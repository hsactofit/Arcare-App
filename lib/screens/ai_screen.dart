import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';

class AIScreen extends StatefulWidget {
  const AIScreen({super.key});

  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = [];
  int? _conversationId;
  bool _isSending = false;
  bool _isLoadingHistory = false;
  /// When true, the next send uses `new_conversation: true` so the server
  /// does not resume the previous open thread.
  bool _pendingNewConversation = false;

  final List<String> _suggestions = [
    "Assess my health score",
    "How can I sleep better?",
    "Suggest a water target",
    "How to burn 500 kcal?",
  ];

  @override
  void initState() {
    super.initState();
    _bootstrapChat();
  }

  Future<void> _bootstrapChat() async {
    setState(() => _isLoadingHistory = true);
    try {
      final email = await ApiService.instance.getUserEmail();
      final list = await ApiService.instance.listChatConversations(email, limit: 1);
      final conversations = (list['conversations'] as List?) ?? [];

      if (conversations.isNotEmpty) {
        final latest = Map<String, dynamic>.from(conversations.first as Map);
        final id = latest['id'] as int?;
        if (id != null) {
          final history = await ApiService.instance.getChatHistory(email, id);
          final items = (history['messages'] as List?) ?? [];
          if (items.isNotEmpty && mounted) {
            setState(() {
              _conversationId = id;
              _messages
                ..clear()
                ..addAll(items.map((raw) {
                  final m = Map<String, dynamic>.from(raw as Map);
                  final role = (m['role'] as String? ?? '').toLowerCase();
                  final actions = m['actions'];
                  return {
                    'isUser': role == 'user',
                    'text': m['content'] as String? ?? '',
                    'time': _formatTime(m['created_at'] as String?),
                    'loggedActions': actions is List
                        ? actions
                            .map((a) => Map<String, dynamic>.from(a as Map))
                            .toList()
                        : null,
                  };
                }));
            });
            _scrollToBottom();
            return;
          }
        }
      }
    } catch (e) {
      debugPrint("Chat history bootstrap failed: $e");
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }

    await _loadInitialGreeting();
  }

  Future<void> _loadInitialGreeting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedGreeting = prefs.getString('cached_ai_buddy_message');

      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..add({
            'isUser': false,
            'text': cachedGreeting ??
                "Hi! I'm your AI Buddy. ✨ I can analyze your health data, suggest routines, log water or steps for you, or give hydration tips. Ask me anything!",
            'time': "Just now",
          });
      });
    } catch (e) {
      debugPrint("Error loading initial greeting: $e");
    }
  }

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return "Just now";
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return "$h:$m";
    } catch (_) {
      return "Just now";
    }
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return;

    final startNew = _pendingNewConversation;

    setState(() {
      _isSending = true;
      _messages.add({
        'isUser': true,
        'text': trimmed,
        'time': "Just now",
      });
      _messageController.clear();
    });

    _scrollToBottom();

    final typingIndex = _messages.length;
    setState(() {
      _messages.add({
        'isUser': false,
        'text': "Thinking...",
        'time': "Just now",
        'isTyping': true,
      });
    });
    _scrollToBottom();

    try {
      final email = await ApiService.instance.getUserEmail();
      final resData = await ApiService.instance.sendChatMessage(
        email: email,
        message: trimmed,
        conversationId: startNew ? null : _conversationId,
        newConversation: startNew,
      );

      if (!mounted) return;

      final String reply =
          resData['reply'] as String? ?? "I couldn't process that.";
      final int? convId = resData['conversation_id'] as int?;
      final loggedRaw = resData['logged_actions'];
      final List<Map<String, dynamic>>? loggedActions = loggedRaw is List
          ? loggedRaw
              .map((a) => Map<String, dynamic>.from(a as Map))
              .toList()
          : null;

      setState(() {
        if (convId != null) _conversationId = convId;
        _pendingNewConversation = false;
        _messages[typingIndex] = {
          'isUser': false,
          'text': reply,
          'time': "Just now",
          'loggedActions': loggedActions,
        };
        _isSending = false;
      });
    } catch (e) {
      debugPrint("AI chat error: $e");
      if (!mounted) return;
      setState(() {
        _messages[typingIndex] = {
          'isUser': false,
          'text':
              "I'm having trouble connecting right now. Please check your network and try again.",
          'time': "Just now",
        };
        _isSending = false;
      });
    }
    _scrollToBottom();
  }

  /// Clears the UI and marks the next send as a new server conversation.
  Future<void> _startNewConversation() async {
    if (_isSending) return;
    setState(() {
      _conversationId = null;
      _pendingNewConversation = true;
      _messages.clear();
    });
    await _loadInitialGreeting();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF6F8FC),
            ),
          ),
          Positioned(
            top: 150,
            right: -100,
            width: 300,
            height: 300,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.teal.withOpacity(isDark ? 0.12 : 0.08),
                    Colors.teal.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.tealAccent.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/ai_buddy.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "AI Buddy",
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const Row(
                              children: [
                                SizedBox(
                                  width: 8,
                                  height: 8,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.greenAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  "Online & Ready",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: "New chat",
                        onPressed: _isSending ? null : _startNewConversation,
                        icon: Icon(
                          Icons.edit_square,
                          color: isDark ? Colors.white70 : Colors.black54,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Colors.white10),

                // Messages
                Expanded(
                  child: _isLoadingHistory
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          physics: const BouncingScrollPhysics(),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isUser = msg['isUser'] as bool;
                            final logged = msg['loggedActions']
                                as List<Map<String, dynamic>>?;
                            return _buildChatBubble(
                              msg['text'] as String,
                              isUser,
                              isDark,
                              loggedActions: logged,
                              isTyping: msg['isTyping'] == true,
                            );
                          },
                        ),
                ),

                // Suggestion chips (only before first user message)
                if (!_isLoadingHistory &&
                    _messages.where((m) => m['isUser'] == true).isEmpty)
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final text = _suggestions[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            elevation: 0,
                            pressElevation: 0,
                            backgroundColor: isDark
                                ? Colors.white.withOpacity(0.04)
                                : Colors.black.withOpacity(0.03),
                            side: BorderSide(
                              color:
                                  isDark ? Colors.white10 : Colors.black12,
                            ),
                            label: Text(
                              text,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.tealAccent
                                    : Colors.teal[800],
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: _isSending
                                ? null
                                : () => _sendMessage(text),
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 8),

                // Input
                Padding(
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, bottom: 96),
                  child: Row(
                    children: [
                      Expanded(
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: TextField(
                            controller: _messageController,
                            enabled: !_isSending,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                            ),
                            onSubmitted: (v) => _sendMessage(v),
                            decoration: InputDecoration(
                              hintText: "Ask about health, or log water/steps…",
                              hintStyle: TextStyle(
                                color:
                                    isDark ? Colors.white30 : Colors.black38,
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Colors.tealAccent, Colors.blueAccent],
                          ),
                        ),
                        child: IconButton(
                          icon: _isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded,
                                  color: Colors.white, size: 20),
                          onPressed: _isSending
                              ? null
                              : () =>
                                  _sendMessage(_messageController.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(
    String text,
    bool isUser,
    bool isDark, {
    List<Map<String, dynamic>>? loggedActions,
    bool isTyping = false,
  }) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Colors.teal.withOpacity(0.2)
              : (isDark
                  ? Colors.white.withOpacity(0.04)
                  : Colors.black.withOpacity(0.03)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: Border.all(
            color: isUser
                ? Colors.teal.withOpacity(0.4)
                : (isDark ? Colors.white10 : Colors.black12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isTyping)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isDark ? Colors.tealAccent : Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              )
            else
              Text(
                text,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            if (loggedActions != null && loggedActions.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...loggedActions.map((action) {
                final status =
                    (action['status'] as String? ?? '').toLowerCase();
                final detail = action['detail'] as String? ?? '';
                final type = action['type'] as String? ?? '';
                final ok = status == 'success';
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: ok
                          ? Colors.green.withOpacity(isDark ? 0.15 : 0.1)
                          : Colors.orange.withOpacity(isDark ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ok
                            ? Colors.green.withOpacity(0.4)
                            : Colors.orange.withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          ok
                              ? Icons.check_circle_outline
                              : Icons.info_outline,
                          size: 14,
                          color: ok ? Colors.greenAccent : Colors.orangeAccent,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            detail.isNotEmpty
                                ? detail
                                : "$type · $status",
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
