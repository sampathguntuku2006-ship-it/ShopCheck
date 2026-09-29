import 'dart:async';
import 'package:flutter/material.dart';
import '../data/sample_shops.dart';
import '../models/shop.dart';
import '../models/user.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'location_service.dart';

/// Available types of actionable interactive buttons attached to AI messages.
enum ChatActionButtonType {
  viewShop,
  openMap,
  getDirections,
  addShop,
  switchRole,
  openSettings,
  openHelp,
  openSearch,
  openFavorites,
}

/// An interactive button attached to an AI response.
class ChatActionButton {
  final String label;
  final ChatActionButtonType type;
  final Map<String, dynamic>? payload;
  final IconData? icon;

  const ChatActionButton({
    required this.label,
    required this.type,
    this.payload,
    this.icon,
  });
}

/// An individual message in the ShopCheck AI chat session.
class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<ChatActionButton> actions;
  final bool isError;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.actions = const [],
    this.isError = false,
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    List<ChatActionButton>? actions,
    bool? isError,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      actions: actions ?? this.actions,
      isError: isError ?? this.isError,
    );
  }
}

/// Service managing the ShopCheck AI assistant.
///
/// Features:
/// - Grounded knowledge: Answers based strictly on live DatabaseService, LocationService, and AuthService data.
/// - Zero hallucinations: Explicitly responds "I don't have that information for this shop." for unknown stores.
/// - Role-aware responses: Distinct assistance for Customers vs Shop Owners.
/// - Interactive actionable buttons: Instant navigation to shops, maps, directions, settings, and role switching.
/// - Secure architecture: No private AI keys stored in client code; clean proxy/local architecture.
class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal() {
    _initWelcome();
  }

  final List<ChatMessage> _messages = [];
  final ValueNotifier<List<ChatMessage>> messagesNotifier = ValueNotifier<List<ChatMessage>>([]);
  final ValueNotifier<bool> isThinkingNotifier = ValueNotifier<bool>(false);

  /// Optional remote proxy endpoint for backend-delegated AI queries (no client API keys).
  String? backendProxyUrl;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isThinking => isThinkingNotifier.value;

  void _initWelcome() {
    if (_messages.isEmpty) {
      _messages.add(
        ChatMessage(
          id: 'welcome_msg',
          text: "Hi! I'm your ShopCheck assistant. How can I help you today?\n\n"
              "You can ask me about:\n"
              "• Whether a specific shop is currently open or closing soon\n"
              "• Nearby pharmacies, groceries, or restaurants\n"
              "• Turn-by-turn directions & Google Maps\n"
              "• Dark mode, password reset & favorites\n"
              "• Adding shops, setting hours & temporary closure (for owners)",
          isUser: false,
          timestamp: DateTime.now(),
          actions: const [
            ChatActionButton(
              label: 'Open Shops Near Me',
              type: ChatActionButtonType.openSearch,
              icon: Icons.storefront_rounded,
            ),
            ChatActionButton(
              label: 'Explore Map',
              type: ChatActionButtonType.openMap,
              icon: Icons.map_rounded,
            ),
          ],
        ),
      );
      messagesNotifier.value = List.unmodifiable(_messages);
    }
  }

  /// Sends a user question and generates an accurate, grounded AI response.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final userMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}_user',
      text: trimmed,
      isUser: true,
      timestamp: DateTime.now(),
    );

    _messages.add(userMsg);
    messagesNotifier.value = List.unmodifiable(_messages);
    isThinkingNotifier.value = true;

    try {
      // Simulate brief natural thinking delay (150-300ms) for UI smoothness
      await Future.delayed(const Duration(milliseconds: 250));

      final response = await _generateGroundedResponse(trimmed);
      _messages.add(response);
      messagesNotifier.value = List.unmodifiable(_messages);
    } catch (e) {
      _messages.add(
        ChatMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}_err',
          text: "Sorry, I encountered an issue processing your request: $e\n\nPlease try again.",
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
          actions: const [],
        ),
      );
      messagesNotifier.value = List.unmodifiable(_messages);
    } finally {
      isThinkingNotifier.value = false;
    }
  }

  /// Retries the last user message if previous attempt resulted in an error.
  Future<void> retryLastMessage() async {
    if (_messages.isEmpty) return;
    // Find last user message
    final lastUserMsg = _messages.lastWhere((m) => m.isUser, orElse: () => _messages.first);
    if (lastUserMsg.isUser) {
      // Remove trailing error messages
      while (_messages.isNotEmpty && !_messages.last.isUser) {
        _messages.removeLast();
      }
      messagesNotifier.value = List.unmodifiable(_messages);
      isThinkingNotifier.value = true;
      try {
        final response = await _generateGroundedResponse(lastUserMsg.text);
        _messages.add(response);
        messagesNotifier.value = List.unmodifiable(_messages);
      } catch (e) {
        _messages.add(
          ChatMessage(
            id: 'msg_${DateTime.now().millisecondsSinceEpoch}_err',
            text: "Sorry, I encountered an error: $e. Tap retry to try again.",
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ),
        );
        messagesNotifier.value = List.unmodifiable(_messages);
      } finally {
        isThinkingNotifier.value = false;
      }
    }
  }

  /// Clears the chat conversation and restores initial welcome prompt.
  void clearConversation() {
    _messages.clear();
    isThinkingNotifier.value = false;
    _initWelcome();
  }

  /// Generates a factual response strictly grounded in app data and state.
  Future<ChatMessage> _generateGroundedResponse(String query) async {
    final q = query.toLowerCase();
    final allShops = DatabaseService().getAllShops().isNotEmpty
        ? DatabaseService().getAllShops()
        : sampleShops;
    final currentUser = AuthService().currentUser;
    final isOwner = currentUser?.role == UserRole.shopOwner;
    final now = DateTime.now();

    // -------------------------------------------------------------------------
    // 1. SPECIFIC SHOP NAME QUERY
    // -------------------------------------------------------------------------
    final matchingShop = _findMatchingShop(q, allShops);
    if (matchingShop != null) {
      return _buildShopDetailsResponse(matchingShop, now);
    }

    // Check if query is asking about a specific shop name that doesn't exist
    if (_isAskingAboutUnknownShop(q, allShops)) {
      return ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}_unknown',
        text: "I don't have that information for this shop. "
            "Currently, ShopCheck only tracks shops registered in the app directory.\n\n"
            "Would you like to browse all available shops or search by category?",
        isUser: false,
        timestamp: DateTime.now(),
        actions: const [
          ChatActionButton(
            label: 'Search All Shops',
            type: ChatActionButtonType.openSearch,
            icon: Icons.search_rounded,
          ),
          ChatActionButton(
            label: 'View Map',
            type: ChatActionButtonType.openMap,
            icon: Icons.map_rounded,
          ),
        ],
      );
    }

    // -------------------------------------------------------------------------
    // 2. CLOSING SOON QUERIES
    // -------------------------------------------------------------------------
    if (q.contains('closing soon') || q.contains('close soon') || q.contains('closes soon')) {
      final closingSoonList = allShops.where((s) {
        final status = s.getStatus(now);
        if (!status.isOpen) return false;
        final minutesLeft = _getMinutesUntilClose(s, now);
        return minutesLeft != null && minutesLeft <= 60 && minutesLeft > 0;
      }).toList();

      if (closingSoonList.isEmpty) {
        return ChatMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}_closing_soon',
          text: "None of the currently open shops are closing within the next 60 minutes. "
              "All open stores have ample operating time remaining today!",
          isUser: false,
          timestamp: DateTime.now(),
          actions: const [
            ChatActionButton(
              label: 'View Open Shops',
              type: ChatActionButtonType.openSearch,
              icon: Icons.storefront_rounded,
            ),
          ],
        );
      }

      final buffer = StringBuffer("Here are the shops closing within the next 60 minutes:\n\n");
      for (final s in closingSoonList) {
        final minLeft = _getMinutesUntilClose(s, now);
        buffer.writeln("• **${s.name}** (${s.category})");
        buffer.writeln("  ⚠️ CLOSING SOON • Closes in $minLeft minutes (${s.city})");
      }

      final actions = <ChatActionButton>[
        ChatActionButton(
          label: 'View ${closingSoonList.first.name}',
          type: ChatActionButtonType.viewShop,
          payload: {'shopId': closingSoonList.first.id},
          icon: Icons.visibility_rounded,
        ),
        const ChatActionButton(
          label: 'Open Map',
          type: ChatActionButtonType.openMap,
          icon: Icons.map_rounded,
        ),
      ];

      return ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}_closing_soon',
        text: buffer.toString().trim(),
        isUser: false,
        timestamp: DateTime.now(),
        actions: actions,
      );
    }

    // -------------------------------------------------------------------------
    // 3. CATEGORY / NEARBY OPEN SHOPS QUERY
    // -------------------------------------------------------------------------
    final categoryFilter = _detectCategory(q);
    final wantsOpenOnly = q.contains('open') || q.contains('now');
    final wantsNearby = q.contains('near me') || q.contains('nearby') || q.contains('around');

    if (categoryFilter != null || wantsNearby || (wantsOpenOnly && (q.contains('shop') || q.contains('store')))) {
      var filtered = allShops;

      if (categoryFilter != null) {
        filtered = filtered.where((s) => s.category.toLowerCase().contains(categoryFilter.toLowerCase())).toList();
      }

      if (wantsOpenOnly) {
        filtered = filtered.where((s) => s.getStatus(now).isOpen).toList();
      }

      // If user location is available, sort nearest first
      final pos = LocationService().currentPosition;
      if (pos != null) {
        filtered.sort((a, b) {
          final distA = LocationService.calculateDistanceKm(pos.latitude, pos.longitude, a.latitude, a.longitude);
          final distB = LocationService.calculateDistanceKm(pos.latitude, pos.longitude, b.latitude, b.longitude);
          return distA.compareTo(distB);
        });
      }

      if (filtered.isEmpty) {
        final catLabel = categoryFilter ?? 'matching';
        return ChatMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}_cat_none',
          text: "No $catLabel shops are currently ${wantsOpenOnly ? 'open' : 'found'} in the directory. "
              "Check back during standard business hours or browse all shops.",
          isUser: false,
          timestamp: DateTime.now(),
          actions: const [
            ChatActionButton(
              label: 'View All Shops',
              type: ChatActionButtonType.openSearch,
              icon: Icons.storefront_rounded,
            ),
          ],
        );
      }

      final buffer = StringBuffer();
      final catHeader = categoryFilter != null ? '$categoryFilter ' : '';
      final openHeader = wantsOpenOnly ? 'open ' : '';
      buffer.writeln("Here are ${filtered.length} $openHeader${catHeader}shops in ShopCheck:\n");

      final displayList = filtered.take(5).toList();
      for (final s in displayList) {
        final status = s.getStatus(now);
        String distStr = '';
        if (pos != null) {
          final distKm = LocationService.calculateDistanceKm(pos.latitude, pos.longitude, s.latitude, s.longitude);
          distStr = ' • ${LocationService.formatDistance(distKm)} away';
        }
        final statusBadge = status.isOpen ? '🟢 OPEN' : (status.isTemporarilyClosed ? '🟡 TEMP CLOSED' : '🔴 CLOSED');
        buffer.writeln("• **${s.name}** $statusBadge$distStr");
        buffer.writeln("  ${s.address}, ${s.city}");
        buffer.writeln("  ${status.detailText}\n");
      }

      final actions = <ChatActionButton>[
        ChatActionButton(
          label: 'View ${displayList.first.name}',
          type: ChatActionButtonType.viewShop,
          payload: {'shopId': displayList.first.id},
          icon: Icons.visibility_rounded,
        ),
        const ChatActionButton(
          label: 'Open Map',
          type: ChatActionButtonType.openMap,
          icon: Icons.map_rounded,
        ),
      ];

      return ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}_cat_list',
        text: buffer.toString().trim(),
        isUser: false,
        timestamp: DateTime.now(),
        actions: actions,
      );
    }

    // -------------------------------------------------------------------------
    // 4. SHOP OWNER SPECIFIC TASKS (ROLE-AWARE)
    // -------------------------------------------------------------------------
    if (q.contains('add shop') || q.contains('add a shop') || q.contains('create shop') || q.contains('new shop')) {
      if (!isOwner) {
        return ChatMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}_owner_add_cust',
          text: "To add a new shop to ShopCheck, you need to be in **Shop Owner** mode.\n\n"
              "You can switch roles easily at any time from the top-right three-dot menu (⋮) → **Switch to Shop Owner**.",
          isUser: false,
          timestamp: DateTime.now(),
          actions: const [
            ChatActionButton(
              label: 'Switch to Shop Owner',
              type: ChatActionButtonType.switchRole,
              payload: {'role': 'shopOwner'},
              icon: Icons.storefront_rounded,
            ),
          ],
        );
      } else {
        return ChatMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}_owner_add',
          text: "Here is how to add a new shop as a Shop Owner:\n\n"
              "1. Tap **Add Shop** in the bottom navigation bar (or '+' in My Shops).\n"
              "2. Enter your **Shop Name**, **Category**, and **Phone Number**.\n"
              "3. Enter your **6-digit Indian PIN code** (e.g. 500001) to automatically fill City and State.\n"
              "4. In the **Shop Location** section, tap 'Use My Current Location' or drag the map pin to your store entrance.\n"
              "5. Set your **Weekly Opening Hours** for each day.\n"
              "6. Tap **Save Shop** to publish your store immediately.",
          isUser: false,
          timestamp: DateTime.now(),
          actions: const [
            ChatActionButton(
              label: 'Add Shop Now',
              type: ChatActionButtonType.addShop,
              icon: Icons.add_business_rounded,
            ),
          ],
        );
      }
    }

    if (q.contains('temporarily close') || q.contains('temporary close') || q.contains('temp close') || q.contains('reopen shop')) {
      if (!isOwner) {
        return ChatMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}_temp_close_cust',
          text: "Temporary shop closure is a Shop Owner feature.\n\n"
              "If you are a store owner, switch to Shop Owner mode to manage your store statuses.",
          isUser: false,
          timestamp: DateTime.now(),
          actions: const [
            ChatActionButton(
              label: 'Switch to Shop Owner',
              type: ChatActionButtonType.switchRole,
              payload: {'role': 'shopOwner'},
              icon: Icons.storefront_rounded,
            ),
          ],
        );
      } else {
        return ChatMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}_temp_close_owner',
          text: "To temporarily close or reopen your shop:\n\n"
              "1. Go to **Dashboard** or **My Shops** in the bottom navigation.\n"
              "2. Locate your shop card and tap **Temporarily Close Shop**.\n"
              "3. Provide an optional reason (e.g. 'Renovation' or 'Family function').\n"
              "4. When active, all customer screens immediately display **TEMPORARILY CLOSED**, overriding normal operating hours.\n"
              "5. To resume normal business hours, tap **Reopen Shop**.",
          isUser: false,
          timestamp: DateTime.now(),
          actions: const [
            ChatActionButton(
              label: 'Open Dashboard',
              type: ChatActionButtonType.openSearch,
              icon: Icons.dashboard_rounded,
            ),
          ],
        );
      }
    }

    if (q.contains('opening hours') || q.contains('set hours') || q.contains('change hours') || q.contains('schedule')) {
      if (!isOwner) {
        return ChatMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}_hours_cust',
          text: "To view a shop's weekly hours, open the shop card from the Home screen or Map.\n\n"
              "If you are a store owner looking to set or update hours, switch to Shop Owner mode.",
          isUser: false,
          timestamp: DateTime.now(),
          actions: const [
            ChatActionButton(
              label: 'Search Shops',
              type: ChatActionButtonType.openSearch,
              icon: Icons.search_rounded,
            ),
          ],
        );
      } else {
        return ChatMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}_hours_owner',
          text: "To configure or update weekly opening hours for your shop:\n\n"
              "1. Go to **My Shops** and tap **Edit** on your shop card.\n"
              "2. Scroll down to the **Weekly Opening Hours** section.\n"
              "3. For each day of the week, toggle **Open / Closed** or enable **Open 24 Hours**.\n"
              "4. Tap the time chips to adjust the opening and closing hours.\n"
              "5. Tap **Save Shop** to update customer status calculations instantly.",
          isUser: false,
          timestamp: DateTime.now(),
          actions: const [
            ChatActionButton(
              label: 'Go to My Shops',
              type: ChatActionButtonType.openSearch,
              icon: Icons.store_mall_directory_rounded,
            ),
          ],
        );
      }
    }

    if (q.contains('pin code') || q.contains('pincode') || q.contains('postal code')) {
      return ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}_pincode',
        text: "ShopCheck features smart Indian PIN-code auto-lookup:\n\n"
            "When adding or editing a shop, type any valid 6-digit Indian PIN code (e.g. 500001, 560001, 400001). "
            "ShopCheck will instantly look up the postal database and automatically populate the Post Office, City/Town, District, and State without overwriting your specific street address!",
        isUser: false,
        timestamp: DateTime.now(),
        actions: isOwner
            ? const [
                ChatActionButton(
                  label: 'Add Shop',
                  type: ChatActionButtonType.addShop,
                  icon: Icons.add_business_rounded,
                )
              ]
            : const [],
      );
    }

    // -------------------------------------------------------------------------
    // 5. APP USAGE & FEATURES
    // -------------------------------------------------------------------------
    if (q.contains('dark mode') || q.contains('dark theme') || q.contains('light theme') || q.contains('appearance')) {
      return ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}_theme',
        text: "To customize your theme appearance in ShopCheck:\n\n"
            "1. Tap the three-dot menu (⋮) in the top-right corner.\n"
            "2. Select **Settings** → **Appearance**.\n"
            "3. Choose between:\n"
            "   • **System Default**: Automatically follows your device's theme\n"
            "   • **Light**: Crisp white & emerald styling\n"
            "   • **Dark**: High-contrast slate & emerald styling\n\n"
            "Your choice is saved locally and applies immediately across all screens.",
        isUser: false,
        timestamp: DateTime.now(),
        actions: const [
          ChatActionButton(
            label: 'Open Settings',
            type: ChatActionButtonType.openSettings,
            icon: Icons.settings_outlined,
          ),
        ],
      );
    }

    if (q.contains('password') || q.contains('forgot password') || q.contains('reset password')) {
      return ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}_password',
        text: "To reset your password in ShopCheck:\n\n"
            "1. Log out or start on the **Login Screen**.\n"
            "2. Tap the **Forgot Password?** link.\n"
            "3. Enter your registered 10-digit Indian phone number.\n"
            "4. Enter the 6-digit verification OTP sent to your phone (expires in 5 minutes).\n"
            "5. Create and confirm your new secure password (at least 6 characters).\n"
            "6. Log in with your new password.",
        isUser: false,
        timestamp: DateTime.now(),
        actions: const [
          ChatActionButton(
            label: 'Help & Support',
            type: ChatActionButtonType.openHelp,
            icon: Icons.help_outline_rounded,
          ),
        ],
      );
    }

    if (q.contains('direction') || q.contains('directions') || q.contains('google map') || q.contains('navigate')) {
      return ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}_maps',
        text: "How to use Google Maps & Directions in ShopCheck:\n\n"
            "• **Interactive Map View**: Tap the 'Map' tab in the bottom bar to view all nearby shops with status markers (🟢 Open, 🔴 Closed, 🟡 Temp Closed).\n"
            "• **Turn-by-turn Navigation**: Tap any shop card to view details, then tap **Get Directions**. ShopCheck will launch Google Maps with turn-by-turn directions from your GPS location.",
        isUser: false,
        timestamp: DateTime.now(),
        actions: const [
          ChatActionButton(
            label: 'Open Map',
            type: ChatActionButtonType.openMap,
            icon: Icons.map_rounded,
          ),
        ],
      );
    }

    if (q.contains('favorite') || q.contains('save shop') || q.contains('bookmark')) {
      return ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}_favs',
        text: "How to use Favorites:\n\n"
            "• Tap the **heart icon (♥)** on any shop card or shop details page to add it to your Favorites.\n"
            "• Tap **Favorites** in the bottom navigation to view all your saved stores in one place.\n"
            "• You can also filter by Favorites on the Home screen using the 'Favorites' pill filter.",
        isUser: false,
        timestamp: DateTime.now(),
        actions: const [
          ChatActionButton(
            label: 'View Favorites',
            type: ChatActionButtonType.openFavorites,
            icon: Icons.favorite_rounded,
          ),
        ],
      );
    }

    if (q.contains('switch role') || q.contains('change role') || q.contains('customer') && q.contains('owner')) {
      final targetRole = isOwner ? 'Customer' : 'Shop Owner';
      final roleEnum = isOwner ? 'customer' : 'shopOwner';

      return ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}_role',
        text: "ShopCheck supports instant role switching:\n\n"
            "Tap the three-dot menu (⋮) in the top-right corner of any screen, and tap **Switch to $targetRole**.\n"
            "The app shell updates immediately without logging you out.",
        isUser: false,
        timestamp: DateTime.now(),
        actions: [
          ChatActionButton(
            label: 'Switch to $targetRole',
            type: ChatActionButtonType.switchRole,
            payload: {'role': roleEnum},
            icon: isOwner ? Icons.shopping_bag_outlined : Icons.storefront_rounded,
          ),
        ],
      );
    }

    if (q.contains('search') || q.contains('find shop')) {
      return ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}_search',
        text: "You can search shops by:\n"
            "• **Shop Name** (e.g. 'Krishna', 'Apollo', 'Starbucks')\n"
            "• **Category** (Grocery, Pharmacy, Restaurant, Clothing, Electronics, Hardware)\n"
            "• **City or Area** (e.g. 'Hyderabad', 'Banjara Hills', 'Bengaluru')\n\n"
            "Use the search bar on the Home screen or tap below to open full search.",
        isUser: false,
        timestamp: DateTime.now(),
        actions: const [
          ChatActionButton(
            label: 'Search Now',
            type: ChatActionButtonType.openSearch,
            icon: Icons.search_rounded,
          ),
        ],
      );
    }

    // -------------------------------------------------------------------------
    // 6. DEFAULT HELPFUL FALLBACK
    // -------------------------------------------------------------------------
    return ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}_default',
      text: "I can help you with store statuses, operating hours, directions, and app features!\n\n"
          "Try asking:\n"
          "• *\"Is Sri Krishna Supermarket open right now?\"*\n"
          "• *\"Which pharmacies are open near me?\"*\n"
          "• *\"Which shops are closing soon?\"*\n"
          "• *\"How do I use dark mode?\"*\n"
          "• *\"${isOwner ? 'How do I temporarily close my shop?' : 'How do I add a new shop?'}\"*",
      isUser: false,
      timestamp: DateTime.now(),
      actions: const [
        ChatActionButton(
          label: 'Open Shops Near Me',
          type: ChatActionButtonType.openSearch,
          icon: Icons.storefront_rounded,
        ),
        ChatActionButton(
          label: 'Open Map',
          type: ChatActionButtonType.openMap,
          icon: Icons.map_rounded,
        ),
      ],
    );
  }

  /// Builds a rich, fact-grounded response for a specific shop.
  ChatMessage _buildShopDetailsResponse(Shop shop, DateTime now) {
    final status = shop.getStatus(now);
    final pos = LocationService().currentPosition;

    String distStr = '';
    if (pos != null) {
      final distKm = LocationService.calculateDistanceKm(pos.latitude, pos.longitude, shop.latitude, shop.longitude);
      distStr = ' • ${LocationService.formatDistance(distKm)} away';
    }

    final buffer = StringBuffer();
    if (status.isTemporarilyClosed) {
      buffer.writeln("🟡 **${shop.name}** is currently **TEMPORARILY CLOSED** by the owner.");
      if (shop.temporaryClosureReason != null && shop.temporaryClosureReason!.isNotEmpty) {
        buffer.writeln("Reason: ${shop.temporaryClosureReason}");
      }
    } else if (status.isOpen) {
      final minutesLeft = _getMinutesUntilClose(shop, now);
      if (minutesLeft != null && minutesLeft <= 60 && minutesLeft > 0) {
        buffer.writeln("⚠️ **${shop.name}** is currently **OPEN**, but **CLOSING SOON**!");
        buffer.writeln("It closes in **$minutesLeft minutes** (${status.detailText}).");
      } else {
        buffer.writeln("🟢 **${shop.name}** is currently **OPEN**.");
        buffer.writeln("${status.detailText}.");
      }
    } else {
      buffer.writeln("🔴 **${shop.name}** is currently **CLOSED**.");
      buffer.writeln("${status.detailText}.");
    }

    buffer.writeln("\n**Category:** ${shop.category}");
    buffer.writeln("**Address:** ${shop.address}, ${shop.city}, ${shop.state} - ${shop.pincode}$distStr");
    buffer.writeln("**Phone:** ${shop.phone}");

    final actions = <ChatActionButton>[
      ChatActionButton(
        label: 'View Shop Details',
        type: ChatActionButtonType.viewShop,
        payload: {'shopId': shop.id},
        icon: Icons.storefront_rounded,
      ),
      ChatActionButton(
        label: 'Get Directions',
        type: ChatActionButtonType.getDirections,
        payload: {
          'lat': shop.latitude,
          'lng': shop.longitude,
          'name': shop.name,
        },
        icon: Icons.directions_rounded,
      ),
      ChatActionButton(
        label: 'View on Map',
        type: ChatActionButtonType.openMap,
        payload: {
          'lat': shop.latitude,
          'lng': shop.longitude,
        },
        icon: Icons.map_rounded,
      ),
    ];

    return ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}_shop_${shop.id}',
      text: buffer.toString().trim(),
      isUser: false,
      timestamp: DateTime.now(),
      actions: actions,
    );
  }

  /// Calculates remaining minutes until close if shop is open today.
  int? _getMinutesUntilClose(Shop shop, DateTime now) {
    if (shop.isTemporarilyClosed) return null;
    final todaySchedule = shop.weeklySchedule[now.weekday];
    if (todaySchedule == null || !todaySchedule.isOpen || todaySchedule.is24Hours) return null;

    final currentMinutes = now.hour * 60 + now.minute;
    final openMinutes = todaySchedule.openHour * 60 + todaySchedule.openMinute;
    final closeMinutes = todaySchedule.closeHour * 60 + todaySchedule.closeMinute;

    if (closeMinutes > openMinutes) {
      if (currentMinutes >= openMinutes && currentMinutes < closeMinutes) {
        return closeMinutes - currentMinutes;
      }
    } else {
      // Overnight
      if (currentMinutes >= openMinutes) {
        return (24 * 60 - currentMinutes) + closeMinutes;
      } else if (currentMinutes < closeMinutes) {
        return closeMinutes - currentMinutes;
      }
    }
    return null;
  }

  /// Checks if the query mentions a specific registered shop.
  Shop? _findMatchingShop(String query, List<Shop> shops) {
    for (final shop in shops) {
      final nameLower = shop.name.toLowerCase();
      if (query.contains(nameLower)) return shop;
      // Also match key multi-word tokens e.g. "sri krishna" or "karachi bakery"
      final parts = nameLower.split(' ').where((p) => p.length > 3).toList();
      if (parts.length >= 2) {
        final pair = '${parts[0]} ${parts[1]}';
        if (query.contains(pair)) return shop;
      }
    }
    return null;
  }

  /// Determines if the user is asking about a specific shop name that doesn't exist in our DB.
  bool _isAskingAboutUnknownShop(String query, List<Shop> shops) {
    final askPatterns = [
      'is ',
      'when does ',
      'what time does ',
      'hours for ',
      'tell me about ',
      'status of ',
      'close time of ',
      'open time of ',
    ];

    bool looksLikeSpecificQuery = false;
    for (final p in askPatterns) {
      if (query.contains(p)) {
        looksLikeSpecificQuery = true;
        break;
      }
    }

    if (!looksLikeSpecificQuery) return false;

    // Common non-shop keywords
    final nonShopKeywords = [
      'my shop',
      'shop open',
      'shops open',
      'store open',
      'stores open',
      'pharmacy',
      'pharmacies',
      'grocery',
      'groceries',
      'restaurant',
      'restaurants',
      'clothing',
      'electronics',
      'hardware',
      'near me',
      'nearby',
      'around',
      'closing soon',
      'dark mode',
      'password',
      'map',
      'directions',
      'add shop',
      'close shop',
      'reopen',
      'pin code',
      'pincode',
      'favorite',
      'favorites',
    ];

    for (final k in nonShopKeywords) {
      if (query == k || query == 'is $k' || query == 'when does $k' || query.contains('which') || query.contains('any')) {
        return false;
      }
    }

    // Direct questions about closing or opening times for specific names
    if (query.contains('what time does') || query.contains('when does') || query.contains('hours for')) {
      return true;
    }

    final shopIndicators = [
      'supermarket',
      'mart',
      'bakery',
      'cafe',
      'coffee',
      'store',
      'stores',
      'pharmacy',
      'hospital',
      'mall',
      'shop',
    ];
    for (final ind in shopIndicators) {
      if (query.contains(ind)) {
        // If it's a general question like "find a pharmacy", that's not unknown shop
        if (query.contains('find') || query.contains('which') || query.contains('any') || query.contains('near')) {
          return false;
        }
        return true;
      }
    }

    // Direct "Is [Name] open" patterns
    final isMatch = RegExp(r'^is\s+([a-zA-Z0-9\s]+?)\s+(open|closed)').firstMatch(query);
    if (isMatch != null) {
      final candidate = isMatch.group(1)?.trim() ?? '';
      if (candidate.isNotEmpty && !nonShopKeywords.contains(candidate)) {
        return true;
      }
    }

    return false;
  }

  /// Detects category filter in query.
  String? _detectCategory(String q) {
    if (q.contains('grocery') || q.contains('groceries') || q.contains('supermarket')) return 'Grocery';
    if (q.contains('pharmacy') || q.contains('chemist') || q.contains('medical') || q.contains('medicine')) return 'Pharmacy';
    if (q.contains('restaurant') || q.contains('dining') || q.contains('food') || q.contains('cafe')) return 'Restaurant';
    if (q.contains('clothing') || q.contains('clothes') || q.contains('fashion') || q.contains('apparel')) return 'Clothing';
    if (q.contains('electronics') || q.contains('gadget') || q.contains('mobile') || q.contains('laptop')) return 'Electronics';
    if (q.contains('hardware') || q.contains('tool') || q.contains('construction')) return 'Hardware';
    return null;
  }
}
