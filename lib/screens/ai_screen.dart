import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
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

  final List<String> _suggestions = [
    "Assess my health score",
    "How can I sleep better?",
    "Suggest a water target",
    "How to burn 500 kcal?",
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialGreeting();
  }

  Future<void> _loadInitialGreeting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedGreeting = prefs.getString('cached_ai_buddy_message');
      
      setState(() {
        _messages.add({
          'isUser': false,
          'text': cachedGreeting ?? "Hi! I'm your AI Buddy. ✨ I can analyze your health connect data, suggest active routines, or give you hydration tips. Ask me anything!",
          'time': "Just now",
        });
      });
    } catch (e) {
      debugPrint("Error loading initial greeting: $e");
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({
        'isUser': true,
        'text': text,
        'time': "Just now",
      });
      _messageController.clear();
    });

    _scrollToBottom();

    // Show thinking indicator while waiting
    final typingIndex = _messages.length;
    setState(() {
      _messages.add({
        'isUser': false,
        'text': "Thinking...",
        'time': "Just now",
      });
    });
    _scrollToBottom();

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('onboarding_data');
      String email = "";
      if (jsonStr != null) {
        final Map<String, dynamic> onboarding = jsonDecode(jsonStr);
        email = onboarding['auth']?['email'] ?? "";
      }
      
      final token = await AuthService.instance.getAccessToken();
      final url = '${AuthService.apiBaseUrl}/api/ai/chat/${Uri.encodeComponent(email)}';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'message': text,
        }),
      );

      // Debug log the full JSON response
      debugPrint("================ AI CHAT API RESPONSE ================");
      debugPrint("Status Code: ${response.statusCode}");
      debugPrint("Response Body: ${response.body}");
      debugPrint("======================================================");

      if (!mounted) return;

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final String reply = resData['reply'] ?? "I couldn't process that.";
        
        setState(() {
          _messages[typingIndex] = {
            'isUser': false,
            'text': reply,
            'time': "Just now",
          };
        });
      } else {
        setState(() {
          _messages[typingIndex] = {
            'isUser': false,
            'text': "I'm having trouble connecting to my brain right now. Please try again!",
            'time': "Just now",
          };
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages[typingIndex] = {
          'isUser': false,
          'text': "Connection lost. Please check your network and try again.",
          'time': "Just now",
        };
      });
    }
    _scrollToBottom();
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
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      body: Stack(
        children: [
          // Background Color & Glows
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
                // Header (AI Buddy Profile Header)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      // Avatar
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
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.greenAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
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
                    ],
                  ),
                ),
                
                const Divider(height: 1, color: Colors.white10),

                // Chat Messages Window
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg['isUser'] as bool;
                      return _buildChatBubble(msg['text'] as String, isUser, isDark);
                    },
                  ),
                ),

                // Suggestion Chips (Interactive quick actions)
                if (_messages.length == 1)
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
                            backgroundColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                            side: BorderSide(
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                            label: Text(
                              text,
                              style: TextStyle(
                                color: isDark ? Colors.tealAccent : Colors.teal[800],
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: () => _sendMessage(text),
                          ),
                        );
                      },
                    ),
                  ),
                
                const SizedBox(height: 8),

                // Message input box (Bottom bar)
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 96), // Clears floating bottom nav
                  child: Row(
                    children: [
                      Expanded(
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: TextField(
                            controller: _messageController,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                            ),
                            onSubmitted: _sendMessage,
                            decoration: InputDecoration(
                              hintText: "Type health questions here...",
                              hintStyle: TextStyle(
                                color: isDark ? Colors.white30 : Colors.black38,
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Send button
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Colors.tealAccent, Colors.blueAccent],
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                          onPressed: () => _sendMessage(_messageController.text),
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

  Widget _buildChatBubble(String text, bool isUser, bool isDark) {
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
              : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
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
        child: Text(
          text,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
