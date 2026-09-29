import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import 'add_edit_shop_screen.dart';
import 'favorites_screen.dart';
import 'help_support_screen.dart';
import 'map_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'shop_details_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiService _aiService = AiService();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend([String? presetText]) async {
    final text = presetText ?? _textController.text;
    if (text.trim().isEmpty) return;

    if (presetText == null) {
      _textController.clear();
    }

    _scrollToBottom();
    await _aiService.sendMessage(text);
    _scrollToBottom();
  }

  Future<void> _handleClearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Conversation?'),
        content: const Text('This will clear all messages and reset the AI chat session.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _aiService.clearConversation();
    }
  }

  Future<void> _handleAction(ChatActionButton action) async {
    switch (action.type) {
      case ChatActionButtonType.viewShop:
        final shopId = action.payload?['shopId'] as String?;
        if (shopId != null) {
          final shop = DatabaseService().getShopById(shopId);
          if (shop != null && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ShopDetailsScreen(shop: shop)),
            );
          }
        }
        break;

      case ChatActionButtonType.openMap:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MapScreen()),
        );
        break;

      case ChatActionButtonType.getDirections:
        final lat = action.payload?['lat'] as double?;
        final lng = action.payload?['lng'] as double?;
        if (lat != null && lng != null) {
          final pos = LocationService().currentPosition;
          final originLat = pos?.latitude ?? LocationService.defaultIndiaLat;
          final originLng = pos?.longitude ?? LocationService.defaultIndiaLng;
          final mapUrl = Uri.parse(
            'https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLng&destination=$lat,$lng',
          );
          try {
            await launchUrl(mapUrl, mode: LaunchMode.externalNonBrowserApplication);
          } catch (_) {
            await launchUrl(mapUrl, mode: LaunchMode.platformDefault);
          }
        }
        break;

      case ChatActionButtonType.addShop:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddEditShopScreen()),
        );
        break;

      case ChatActionButtonType.switchRole:
        final roleStr = action.payload?['role'] as String?;
        final target = roleStr == 'shopOwner' ? UserRole.shopOwner : UserRole.customer;
        await AuthService().switchRole(target);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Switched to ${target.displayName} mode'),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() {});
        }
        break;

      case ChatActionButtonType.openSettings:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
        break;

      case ChatActionButtonType.openHelp:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
        );
        break;

      case ChatActionButtonType.openSearch:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SearchScreen()),
        );
        break;

      case ChatActionButtonType.openFavorites:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FavoritesScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = AuthService().currentUser;
    final isOwner = currentUser?.role == UserRole.shopOwner;

    final suggestionChips = isOwner
        ? [
            "How do I add a new shop?",
            "How do I temporarily close my shop?",
            "How do I set opening hours?",
            "How does PIN code auto-fill work?",
            "How do I use dark mode?",
          ]
        : [
            "Which shops are open near me?",
            "Are there any pharmacies open?",
            "Which shops are closing soon?",
            "How do I use dark mode?",
            "How do I reset my password?",
            "How do I get directions?",
          ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ShopCheck AI',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                Text(
                  isOwner ? 'Store Owner Assistant' : 'Customer Assistant',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear Chat',
            onPressed: _handleClearChat,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Suggestions header horizontal bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: suggestionChips.map((chipText) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF16A34A)),
                      label: Text(
                        chipText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                        ),
                      ),
                      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      side: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      onPressed: () => _handleSend(chipText),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Message bubbles
          Expanded(
            child: ValueListenableBuilder<List<ChatMessage>>(
              valueListenable: _aiService.messagesNotifier,
              builder: (context, messages, _) {
                return ValueListenableBuilder<bool>(
                  valueListenable: _aiService.isThinkingNotifier,
                  builder: (context, isThinking, _) {
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      itemCount: messages.length + (isThinking ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.length && isThinking) {
                          return _buildThinkingBubble(isDark);
                        }
                        final msg = messages[index];
                        return _buildMessageItem(msg, isDark);
                      },
                    );
                  },
                );
              },
            ),
          ),

          // Message Input Box
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSend(),
                      decoration: InputDecoration(
                        hintText: 'Ask me anything about ShopCheck...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<bool>(
                    valueListenable: _aiService.isThinkingNotifier,
                    builder: (context, isThinking, _) {
                      return CircleAvatar(
                        radius: 23,
                        backgroundColor: const Color(0xFF16A34A),
                        child: IconButton(
                          icon: isThinking
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                          tooltip: 'Send',
                          onPressed: isThinking ? null : () => _handleSend(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage msg, bool isDark) {
    if (msg.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14, left: 48),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(
              msg.text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    if (msg.isError) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14, right: 32),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg.text,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF991B1B), fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _aiService.retryLastMessage(),
                      icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFFDC2626)),
                      label: const Text('Retry', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700)),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // AI message bubble
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 13,
                  color: Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Attached Action Buttons
          if (msg.actions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: msg.actions.map((act) {
                  return ElevatedButton.icon(
                    onPressed: () => _handleAction(act),
                    icon: Icon(act.icon ?? Icons.arrow_forward_rounded, size: 14),
                    label: Text(act.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7),
                      foregroundColor: isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF16A34A) : const Color(0xFF86EFAC),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThinkingBubble(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, right: 60),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 13,
              color: Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'ShopCheck AI is typing...',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
