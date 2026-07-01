import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class UserRepository {
  UserRepository._();

  static final UserRepository instance = UserRepository._();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  late ValueNotifier<UserProfile?> currentUser = ValueNotifier<UserProfile?>(
    null,
  );

  Future<List<UserProfile>> fetchAllUsers({String? role}) async {
    try {
      final query = await _firestore.collection('users').get();
      final users = query.docs
          .map((doc) {
            final data = doc.data();
            final createdDate = data['createdDate'] is String
                ? DateTime.tryParse(data['createdDate'] as String)
                : DateTime.now();
            return UserProfile(
              userId: doc.id,
              email: data['email'] as String? ?? '',
              displayName:
                  data['displayName'] as String? ??
                  (data['email'] as String? ?? '').split('@').first,
              photoURL: data['photoURL'] as String?,
              tokens: data['tokens'] as int? ?? 0,
              role: data['role'] as String? ?? 'Explorador',
              createdDate: createdDate ?? DateTime.now(),
            );
          })
          .where((user) => role == null || user.role == role)
          .toList();
      users.sort((a, b) => a.displayName.compareTo(b.displayName));
      return users;
    } catch (e) {
      debugPrint('UserRepository.fetchAllUsers error: $e');
      return [];
    }
  }

Future<void> initializeUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.reload();
      } catch (_) {}

      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser != null) {
        Map<String, dynamic>? data;
        try {
          final userDoc = await _firestore
              .collection('users')
              .doc(refreshedUser.uid)
              .get();
          data = userDoc.data();
        } catch (e) {
          // Firestore read failed (possibly permission-denied). Use cached data.
          debugPrint('Firestore user read error for ${refreshedUser.uid}: $e');
        }

        // Si data es null, intentar usar caché
        final cachedTokens = await _getCachedTokens(refreshedUser.uid);
        final cachedRole = await _getCachedRole(refreshedUser.uid);
        final cachedDisplayName = await _getCachedDisplayName(
          refreshedUser.uid,
        );

        final currentTokens = data != null
            ? (data['tokens'] as int? ?? cachedTokens)
            : cachedTokens;
        final currentRole = data != null
            ? (data['role'] as String? ?? cachedRole)
            : (cachedRole.isNotEmpty ? cachedRole : 'Explorador');
        final displayName = data != null && data['displayName'] != null
            ? data['displayName'] as String
            : (cachedDisplayName.isNotEmpty
                ? cachedDisplayName
                : (refreshedUser.displayName ??
                    refreshedUser.email?.split('@').first ??
                    'Usuario'));
        final currentCreatedDate = data != null && data['createdDate'] != null
            ? DateTime.tryParse(data['createdDate'] as String) ?? DateTime.now()
            : DateTime.now();

        final resolvedDisplayName = displayName.isNotEmpty
            ? displayName
            : refreshedUser.displayName ??
                refreshedUser.email?.split('@').first ??
                'Usuario';

        currentUser.value = UserProfile(
          userId: refreshedUser.uid,
          email: refreshedUser.email ?? '',
          displayName: resolvedDisplayName,
          photoURL: refreshedUser.photoURL,
          tokens: currentTokens,
          role: currentRole,
          createdDate: currentCreatedDate,
        );
      } else {
        currentUser.value = null;
      }
    } else {
      currentUser.value = null;
    }
  }

  Future<void> createUserProfile({
    required String userId,
    required String email,
    required String displayName,
    required String role,
  }) async {
    final now = DateTime.now();
    await _firestore.collection('users').doc(userId).set({
      'email': email,
      'displayName': displayName,
      'role': role,
      'tokens': 0,
      'createdDate': now.toIso8601String(),
      'photoURL': null,
    });
    await _cacheUserProfile(userId, 0, role, displayName);
  }

  Future<void> updateUserProfile({
    required String userId,
    required String displayName,
    String? photoURL,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'displayName': displayName,
        if (photoURL != null) 'photoURL': photoURL,
      });
    } catch (e) {
      debugPrint('Warning: failed to update profile in Firestore: $e');
    }
  }

  void addTokens(int amount) {
    if (currentUser.value != null) {
      final newTokens = (currentUser.value!.tokens + amount).toInt();
      currentUser.value = currentUser.value!.copyWith(tokens: newTokens);
      _cacheTokens(currentUser.value!.userId, newTokens);

      // Persist token change to Firestore; do not throw on failure
      try {
        final uid = currentUser.value!.userId;
        _firestore.collection('users').doc(uid).update({'tokens': newTokens});
      } catch (e) {
        debugPrint('Warning: failed to persist tokens for addTokens: $e');
      }
    }
  }

  void removeTokens(int amount) {
    if (currentUser.value != null) {
      final newTokens = (currentUser.value!.tokens - amount)
          .clamp(0, double.maxFinite)
          .toInt();
      currentUser.value = currentUser.value!.copyWith(tokens: newTokens);
      _cacheTokens(currentUser.value!.userId, newTokens);

      // Persist token change to Firestore; do not throw on failure
      try {
        final uid = currentUser.value!.userId;
        _firestore.collection('users').doc(uid).update({'tokens': newTokens});
      } catch (e) {
        debugPrint('Warning: failed to persist tokens for removeTokens: $e');
      }
    }
  }

  int getTokens() {
    return currentUser.value?.tokens ?? 0;
  }

  Future<void> _cacheTokens(String uid, int tokens) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('cached_tokens_$uid', tokens);
    } catch (e) {
      debugPrint('Warning: failed to cache tokens locally: $e');
    }
  }

  Future<int> _getCachedTokens(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('cached_tokens_$uid') ?? 0;
    } catch (e) {
      debugPrint('Warning: failed to read cached tokens locally: $e');
      return 0;
    }
  }

  Future<void> cacheUserProfile(
    String uid,
    int tokens,
    String role,
    String displayName,
  ) async {
    await _cacheUserProfile(uid, tokens, role, displayName);
  }

  Future<void> _cacheUserProfile(
    String uid,
    int tokens,
    String role,
    String displayName,
  ) async {
    await _cacheTokens(uid, tokens);
    await _cacheRole(uid, role);
    await _cacheDisplayName(uid, displayName);
  }

  Future<void> _cacheRole(String uid, String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_role_$uid', role);
    } catch (e) {
      debugPrint('Warning: failed to cache role locally: $e');
    }
  }

  Future<String> _getCachedRole(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('cached_role_$uid') ?? '';
    } catch (e) {
      debugPrint('Warning: failed to read cached role locally: $e');
      return '';
    }
  }

  Future<void> _cacheDisplayName(String uid, String displayName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_displayName_$uid', displayName);
    } catch (e) {
      debugPrint('Warning: failed to cache displayName locally: $e');
    }
  }

  Future<String> _getCachedDisplayName(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('cached_displayName_$uid') ?? '';
    } catch (e) {
      debugPrint('Warning: failed to read cached displayName locally: $e');
      return '';
    }
  }
}
