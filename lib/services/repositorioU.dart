import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart';

class UserRepository {
  UserRepository._();

  static final UserRepository instance = UserRepository._();

  late ValueNotifier<UserProfile?> currentUser = ValueNotifier<UserProfile?>(
    null,
  );

  Future<void> initializeUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.reload();
      } catch (_) {}

      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser != null) {
        final currentTokens = currentUser.value?.tokens ?? 0;
        final currentCreatedDate =
            currentUser.value?.createdDate ?? DateTime.now();

        currentUser.value = UserProfile(
          userId: refreshedUser.uid,
          email: refreshedUser.email ?? '',
          displayName:
              refreshedUser.displayName ??
              refreshedUser.email?.split('@').first ??
              'Usuario',
          tokens: currentTokens,
          createdDate: currentCreatedDate,
          photoURL: refreshedUser.photoURL,
        );
      } else {
        currentUser.value = null;
      }
    } else {
      currentUser.value = null;
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
      final newTokens = (currentUser.value!.tokens - amount)
          .clamp(0, double.maxFinite)
          .toInt();
      currentUser.value = currentUser.value!.copyWith(tokens: newTokens);
    }
  }

  int getTokens() {
    return currentUser.value?.tokens ?? 0;
  }
}
