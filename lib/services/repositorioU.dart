import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart';

class UserRepository {
  UserRepository._();

  static final UserRepository instance = UserRepository._();

  late ValueNotifier<UserProfile?> currentUser = ValueNotifier<UserProfile?>(null);

  Future<void> initializeUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      currentUser.value = UserProfile(
        userId: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? user.email?.split('@').first ?? 'Usuario',
        tokens: 0,
        createdDate: DateTime.now(),
      );
    }
  }

  void addTokens(int amount) {
    if (currentUser.value != null) {
      currentUser.value = currentUser.value!.copyWith(
        tokens: currentUser.value!.tokens + amount,
      );
    }
  }

  void removeTokens(int amount) {
    if (currentUser.value != null) {
      final newTokens = (currentUser.value!.tokens - amount).clamp(0, double.maxFinite).toInt();
      currentUser.value = currentUser.value!.copyWith(
        tokens: newTokens,
      );
    }
  }

  int getTokens() {
    return currentUser.value?.tokens ?? 0;
  }
}
