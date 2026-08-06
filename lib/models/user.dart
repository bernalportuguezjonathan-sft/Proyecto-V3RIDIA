class UserProfile {
  UserProfile({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.photoURL,
    required this.tokens,
    required this.role,
    required this.createdDate,
    required this.isBanned,
    this.banExpires,
    this.banReason,
  });

  final String userId;
  final String email;
  final String displayName;
  final String? photoURL;
  final int tokens;
  final String role;
  final DateTime createdDate;
  final bool isBanned;
  final DateTime? banExpires;
  final String? banReason;

  UserProfile copyWith({
    String? userId,
    String? email,
    String? displayName,
    String? photoURL,
    int? tokens,
    String? role,
    DateTime? createdDate,
    bool? isBanned,
    DateTime? banExpires,
    String? banReason,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      tokens: tokens ?? this.tokens,
      role: role ?? this.role,
      createdDate: createdDate ?? this.createdDate,
      isBanned: isBanned ?? this.isBanned,
      banExpires: banExpires ?? this.banExpires,
      banReason: banReason ?? this.banReason,
    );
  }
}
