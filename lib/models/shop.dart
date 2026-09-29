import 'package:flutter/material.dart';

/// Represents the operating schedule for a single day of the week.
class DaySchedule {
  final bool isOpen;
  final bool is24Hours;
  final int openHour;
  final int openMinute;
  final int closeHour;
  final int closeMinute;

  const DaySchedule({
    this.isOpen = true,
    this.is24Hours = false,
    this.openHour = 9,
    this.openMinute = 0,
    this.closeHour = 21,
    this.closeMinute = 0,
  });

  const DaySchedule.closed()
      : isOpen = false,
        is24Hours = false,
        openHour = 0,
        openMinute = 0,
        closeHour = 0,
        closeMinute = 0;

  const DaySchedule.allDay()
      : isOpen = true,
        is24Hours = true,
        openHour = 0,
        openMinute = 0,
        closeHour = 23,
        closeMinute = 59;

  /// Formatted schedule text, e.g. "8:00 AM – 9:00 PM", "Open 24 Hours", or "Closed".
  String get formattedHours {
    if (!isOpen) return 'Closed';
    if (is24Hours) return 'Open 24 Hours';
    return '${formatTime(openHour, openMinute)} – ${formatTime(closeHour, closeMinute)}';
  }

  static String formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  Map<String, dynamic> toJson() {
    return {
      'isOpen': isOpen,
      'is24Hours': is24Hours,
      'openHour': openHour,
      'openMinute': openMinute,
      'closeHour': closeHour,
      'closeMinute': closeMinute,
    };
  }

  factory DaySchedule.fromJson(Map<String, dynamic> json) {
    return DaySchedule(
      isOpen: json['isOpen'] as bool? ?? true,
      is24Hours: json['is24Hours'] as bool? ?? false,
      openHour: json['openHour'] as int? ?? 9,
      openMinute: json['openMinute'] as int? ?? 0,
      closeHour: json['closeHour'] as int? ?? 21,
      closeMinute: json['closeMinute'] as int? ?? 0,
    );
  }
}

/// Represents the current calculated status of a shop.
class ShopStatus {
  final bool isOpen;
  final bool isTemporarilyClosed;
  final String statusText; // 'OPEN', 'CLOSED', or 'TEMPORARILY CLOSED'
  final String detailText; // e.g. 'Closes at 9:00 PM', 'Opens today at 8:00 AM', 'Renovation'

  const ShopStatus({
    required this.isOpen,
    this.isTemporarilyClosed = false,
    required this.statusText,
    required this.detailText,
  });

  // Modern clean status colors:
  // Green for OPEN, Amber for TEMPORARILY CLOSED, Red for CLOSED
  Color get statusColor {
    if (isTemporarilyClosed) return const Color(0xFFD97706);
    return isOpen ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
  }

  Color get backgroundColor {
    if (isTemporarilyClosed) return const Color(0xFFFEF3C7);
    return isOpen ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
  }

  Color get borderColor {
    if (isTemporarilyClosed) return const Color(0xFFFCD34D);
    return isOpen ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5);
  }
}

/// Represents a shop, its location, contact, weekly opening hours, and temporary closure state.
class Shop {
  final String id;
  final String ownerId;
  final String name;
  final String category;
  final IconData categoryIcon;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final double latitude;
  final double longitude;
  final String phone;
  final String distance;
  final String description;
  final bool isTemporarilyClosed;
  final String? temporaryClosureReason;

  /// Map of weekday (DateTime.monday = 1 to DateTime.sunday = 7) to DaySchedule.
  final Map<int, DaySchedule> weeklySchedule;

  const Shop({
    required this.id,
    this.ownerId = 'system_admin',
    required this.name,
    required this.category,
    required this.categoryIcon,
    required this.address,
    this.city = 'Hyderabad',
    this.state = 'Telangana',
    this.pincode = '500001',
    this.latitude = 17.3850,
    this.longitude = 78.4867,
    required this.phone,
    required this.distance,
    required this.description,
    required this.weeklySchedule,
    this.isTemporarilyClosed = false,
    this.temporaryClosureReason,
    this.createdAt,
    this.updatedAt,
  });

  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get shopId => id;
  String get pin => pincode;
  bool get temporaryClosed => isTemporarilyClosed;

  Shop copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? category,
    IconData? categoryIcon,
    String? address,
    String? city,
    String? state,
    String? pincode,
    double? latitude,
    double? longitude,
    String? phone,
    String? distance,
    String? description,
    Map<int, DaySchedule>? weeklySchedule,
    bool? isTemporarilyClosed,
    String? temporaryClosureReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Shop(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      category: category ?? this.category,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      phone: phone ?? this.phone,
      distance: distance ?? this.distance,
      description: description ?? this.description,
      weeklySchedule: weeklySchedule ?? this.weeklySchedule,
      isTemporarilyClosed: isTemporarilyClosed ?? this.isTemporarilyClosed,
      temporaryClosureReason: temporaryClosureReason ?? this.temporaryClosureReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Calculates the current OPEN, CLOSED, or TEMPORARILY CLOSED status based on [testTime] or [DateTime.now()].
  ShopStatus getStatus([DateTime? testTime]) {
    // 1. Check if shop is temporarily closed by owner
    if (isTemporarilyClosed) {
      return ShopStatus(
        isOpen: false,
        isTemporarilyClosed: true,
        statusText: 'TEMPORARILY CLOSED',
        detailText: temporaryClosureReason != null && temporaryClosureReason!.isNotEmpty
            ? temporaryClosureReason!
            : 'Temporarily closed by owner',
      );
    }

    final now = testTime ?? DateTime.now();
    final todayWeekday = now.weekday; // 1 = Mon, 7 = Sun
    final currentMinutes = now.hour * 60 + now.minute;

    // Check if shop is currently open from yesterday's overnight schedule
    final yesterdayWeekday = todayWeekday == 1 ? 7 : todayWeekday - 1;
    final yesterday = weeklySchedule[yesterdayWeekday];
    if (yesterday != null && yesterday.isOpen && !yesterday.is24Hours) {
      final yOpen = yesterday.openHour * 60 + yesterday.openMinute;
      final yClose = yesterday.closeHour * 60 + yesterday.closeMinute;
      if (yClose < yOpen && currentMinutes < yClose) {
        return ShopStatus(
          isOpen: true,
          statusText: 'OPEN',
          detailText: 'Closes at ${DaySchedule.formatTime(yesterday.closeHour, yesterday.closeMinute)}',
        );
      }
    }

    final today = weeklySchedule[todayWeekday] ?? const DaySchedule.closed();

    if (today.isOpen) {
      if (today.is24Hours) {
        return const ShopStatus(
          isOpen: true,
          statusText: 'OPEN',
          detailText: 'Open 24 Hours',
        );
      }

      final openMinutes = today.openHour * 60 + today.openMinute;
      final closeMinutes = today.closeHour * 60 + today.closeMinute;

      if (closeMinutes > openMinutes) {
        // Standard daytime hours
        if (currentMinutes >= openMinutes && currentMinutes < closeMinutes) {
          return ShopStatus(
            isOpen: true,
            statusText: 'OPEN',
            detailText: 'Closes at ${DaySchedule.formatTime(today.closeHour, today.closeMinute)}',
          );
        } else if (currentMinutes < openMinutes) {
          return ShopStatus(
            isOpen: false,
            statusText: 'CLOSED',
            detailText: 'Opens today at ${DaySchedule.formatTime(today.openHour, today.openMinute)}',
          );
        }
      } else {
        // Overnight hours (e.g. 18:00 to 02:00)
        if (currentMinutes >= openMinutes || currentMinutes < closeMinutes) {
          return ShopStatus(
            isOpen: true,
            statusText: 'OPEN',
            detailText: 'Closes at ${DaySchedule.formatTime(today.closeHour, today.closeMinute)}',
          );
        } else if (currentMinutes < openMinutes) {
          return ShopStatus(
            isOpen: false,
            statusText: 'CLOSED',
            detailText: 'Opens today at ${DaySchedule.formatTime(today.openHour, today.openMinute)}',
          );
        }
      }
    }

    // Shop is closed right now. Find next opening time.
    final nextOpeningText = _findNextOpening(todayWeekday);
    return ShopStatus(
      isOpen: false,
      statusText: 'CLOSED',
      detailText: nextOpeningText,
    );
  }

  String _findNextOpening(int todayWeekday) {
    for (int offset = 1; offset <= 7; offset++) {
      final nextWeekday = ((todayWeekday - 1 + offset) % 7) + 1;
      final schedule = weeklySchedule[nextWeekday];
      if (schedule != null && schedule.isOpen) {
        final timeStr = schedule.is24Hours
            ? '12:00 AM'
            : DaySchedule.formatTime(schedule.openHour, schedule.openMinute);
        if (offset == 1) {
          return 'Opens tomorrow at $timeStr';
        } else {
          return 'Opens ${_getDayName(nextWeekday)} at $timeStr';
        }
      }
    }
    return 'Temporarily Closed';
  }

  static String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return '';
    }
  }

  /// Helper to get day name for UI
  static String getWeekdayName(int weekday) => _getDayName(weekday);

  Map<String, dynamic> toJson() {
    final scheduleMap = <String, dynamic>{};
    weeklySchedule.forEach((key, value) {
      scheduleMap[key.toString()] = value.toJson();
    });

    return {
      'id': id,
      'ownerId': ownerId,
      'name': name,
      'category': category,
      'categoryIconCode': categoryIcon.codePoint,
      'categoryIconFontFamily': categoryIcon.fontFamily,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone,
      'distance': distance,
      'description': description,
      'isTemporarilyClosed': isTemporarilyClosed,
      'temporaryClosureReason': temporaryClosureReason,
      'weeklySchedule': scheduleMap,
    };
  }

  static IconData resolveCategoryIcon(String catStr) {
    if (catStr.contains('Grocery')) {
      return Icons.shopping_basket_rounded;
    } else if (catStr.contains('Pharmacy')) {
      return Icons.local_pharmacy_rounded;
    } else if (catStr.contains('Bakery')) {
      return Icons.bakery_dining_rounded;
    } else if (catStr.contains('Coffee')) {
      return Icons.coffee_rounded;
    } else if (catStr.contains('Electronics')) {
      return Icons.devices_rounded;
    } else if (catStr.contains('Restaurant')) {
      return Icons.restaurant_rounded;
    } else if (catStr.contains('Books')) {
      return Icons.menu_book_rounded;
    } else if (catStr.contains('Flowers')) {
      return Icons.local_florist_rounded;
    } else if (catStr.contains('Clothing')) {
      return Icons.checkroom_rounded;
    }
    return Icons.storefront_rounded;
  }

  /// Converts shop to Firestore document representation according to schema specifications.
  Map<String, dynamic> toFirestore() {
    final scheduleMap = <String, dynamic>{};
    weeklySchedule.forEach((key, value) {
      scheduleMap[key.toString()] = value.toJson();
    });

    return {
      'shopId': id,
      'ownerId': ownerId,
      'name': name,
      'category': category,
      'phone': phone,
      'address': address,
      'city': city,
      'state': state,
      'pin': pincode,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'openingHours': scheduleMap,
      'temporaryClosed': isTemporarilyClosed,
      'temporaryClosureReason': temporaryClosureReason,
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  /// Reconstructs shop from Firestore document data with backward compatibility.
  factory Shop.fromFirestore(Map<String, dynamic> data, [String? docId]) {
    final scheduleMap = <int, DaySchedule>{};
    final rawHours = data['openingHours'] ?? data['weeklySchedule'];
    if (rawHours is Map) {
      rawHours.forEach((key, val) {
        final parsedKey = int.tryParse(key.toString());
        if (parsedKey != null && val is Map) {
          scheduleMap[parsedKey] = DaySchedule.fromJson(Map<String, dynamic>.from(val));
        }
      });
    }

    final catStr = (data['category'] as String?) ?? '';
    final resolvedIcon = resolveCategoryIcon(catStr);

    final id = docId ?? (data['shopId'] as String?) ?? (data['id'] as String?) ?? '';
    final pin = (data['pin'] as String?) ?? (data['pincode'] as String?) ?? '500001';
    final tempClosed = (data['temporaryClosed'] as bool?) ?? (data['isTemporarilyClosed'] as bool?) ?? false;

    DateTime? cAt;
    if (data['createdAt'] is String) {
      cAt = DateTime.tryParse(data['createdAt'] as String);
    }
    DateTime? uAt;
    if (data['updatedAt'] is String) {
      uAt = DateTime.tryParse(data['updatedAt'] as String);
    }

    return Shop(
      id: id,
      ownerId: (data['ownerId'] as String?) ?? 'system_admin',
      name: (data['name'] as String?) ?? '',
      category: catStr,
      categoryIcon: resolvedIcon,
      address: (data['address'] as String?) ?? '',
      city: (data['city'] as String?) ?? 'Hyderabad',
      state: (data['state'] as String?) ?? 'Telangana',
      pincode: pin,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 17.3850,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 78.4867,
      phone: (data['phone'] as String?) ?? '',
      distance: (data['distance'] as String?) ?? '1.0 km',
      description: (data['description'] as String?) ?? '',
      weeklySchedule: scheduleMap,
      isTemporarilyClosed: tempClosed,
      temporaryClosureReason: data['temporaryClosureReason'] as String?,
      createdAt: cAt,
      updatedAt: uAt,
    );
  }

  factory Shop.fromJson(Map<String, dynamic> json) {
    final scheduleMap = <int, DaySchedule>{};
    if (json['weeklySchedule'] != null) {
      final rawMap = json['weeklySchedule'] as Map<String, dynamic>;
      rawMap.forEach((key, val) {
        scheduleMap[int.parse(key)] = DaySchedule.fromJson(val as Map<String, dynamic>);
      });
    }

    final catStr = json['category'] as String? ?? '';
    final resolvedIcon = resolveCategoryIcon(catStr);

    return Shop(
      id: json['id'] as String,
      ownerId: json['ownerId'] as String? ?? 'system_admin',
      name: json['name'] as String,
      category: json['category'] as String,
      categoryIcon: resolvedIcon,
      address: json['address'] as String,
      city: json['city'] as String? ?? 'Hyderabad',
      state: json['state'] as String? ?? 'Telangana',
      pincode: json['pincode'] as String? ?? '500001',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 17.3850,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 78.4867,
      phone: json['phone'] as String,
      distance: json['distance'] as String? ?? '1.0 km',
      description: json['description'] as String? ?? '',
      isTemporarilyClosed: json['isTemporarilyClosed'] as bool? ?? false,
      temporaryClosureReason: json['temporaryClosureReason'] as String?,
      weeklySchedule: scheduleMap,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
    );
  }
}
