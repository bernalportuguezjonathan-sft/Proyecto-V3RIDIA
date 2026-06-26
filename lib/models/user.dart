class UserProfile {
  UserProfile({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.tokens,
    required this.createdDate,
  });

  final String userId;
  final String email;
  final String displayName;
  final int tokens;
  final DateTime createdDate;

  UserProfile copyWith({
    String? userId,
    String? email,
    String? displayName,
    int? tokens,
    DateTime? createdDate,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      tokens: tokens ?? this.tokens,
      createdDate: createdDate ?? this.createdDate,
    );
  }
}
