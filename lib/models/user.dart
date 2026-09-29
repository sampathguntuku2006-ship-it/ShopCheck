/// User roles within ShopCheck
enum UserRole {
  customer,
  shopOwner,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.shopOwner:
        return 'Shop Owner';
    }
  }
}

/// Represents an authenticated user profile with role and cryptographically salted password hash.
/// Passwords are NEVER stored in plain text.
class User {
  final String phone;
  final String salt;
  final String passwordHash;
  final DateTime createdAt;
  final UserRole role;
  final String? name;

  const User({
    required this.phone,
    required this.salt,
    required this.passwordHash,
    required this.createdAt,
    this.role = UserRole.customer,
    this.name,
  });

  String get effectiveName {
    if (name != null && name!.trim().isNotEmpty) {
      return name!.trim();
    }
    return role == UserRole.shopOwner ? 'Shop Owner' : 'Customer';
  }

  User copyWith({
    String? phone,
    String? salt,
    String? passwordHash,
    DateTime? createdAt,
    UserRole? role,
    String? name,
  }) {
    return User(
      phone: phone ?? this.phone,
      salt: salt ?? this.salt,
      passwordHash: passwordHash ?? this.passwordHash,
      createdAt: createdAt ?? this.createdAt,
      role: role ?? this.role,
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'salt': salt,
      'passwordHash': passwordHash,
      'createdAt': createdAt.toIso8601String(),
      'role': role.name,
      'name': name,
    };
  }

  /// Converts user to Firestore representation.
  /// Strictly excludes passwords and salt from Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name ?? effectiveName,
      'phone': phone,
      'role': role.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Reconstructs user profile from Firestore document.
  factory User.fromFirestore(Map<String, dynamic> data, [String? docId]) {
    final phoneStr = (data['phone'] as String?) ?? docId ?? '';
    final roleStr = (data['role'] as String?) ?? 'customer';
    final name = data['name'] as String?;
    DateTime cAt = DateTime.now();
    if (data['createdAt'] is String) {
      cAt = DateTime.tryParse(data['createdAt'] as String) ?? DateTime.now();
    }

    return User(
      phone: phoneStr,
      salt: '',
      passwordHash: '',
      createdAt: cAt,
      role: roleStr == 'shopOwner' ? UserRole.shopOwner : UserRole.customer,
      name: name,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      phone: json['phone'] as String,
      salt: json['salt'] as String,
      passwordHash: json['passwordHash'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      role: json['role'] == 'shopOwner' ? UserRole.shopOwner : UserRole.customer,
      name: json['name'] as String?,
    );
  }
}
