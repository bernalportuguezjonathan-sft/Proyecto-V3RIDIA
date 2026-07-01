import 'package:flutter/foundation.dart';
import '../models/desafio.dart';
import 'repositorioU.dart';

class ChallengeRepository {
  ChallengeRepository._();

  static final ChallengeRepository instance = ChallengeRepository._();

  final ValueNotifier<List<Challenge>> challenges =
      ValueNotifier<List<Challenge>>([]);

  void addChallenge(Challenge challenge) {
    challenges.value = [challenge, ...challenges.value];
  }

  void updateChallenge(Challenge challenge) {
    final index = challenges.value.indexWhere(
      (item) => item.id == challenge.id,
    );
    if (index >= 0) {
      final updated = List<Challenge>.from(challenges.value);
      updated[index] = challenge;
      challenges.value = updated;
    }
  }

  void deleteChallenge(String id) {
    challenges.value = challenges.value.where((item) => item.id != id).toList();
  }

  void updateProgress(String id, int newProgress) {
    final index = challenges.value.indexWhere((item) => item.id == id);
    if (index >= 0) {
      final challenge = challenges.value[index];
      final normalizedProgress = newProgress.clamp(0, challenge.targetGoal);
      final isCompleted = normalizedProgress >= challenge.targetGoal;
      final progressDelta = normalizedProgress - challenge.currentProgress;

      if (progressDelta > 0) {
        for (var step = 0; step < progressDelta; step++) {
          UserRepository.instance.addTokens(1);
        }
      }

      final updated = List<Challenge>.from(challenges.value);
      updated[index] = challenge.copyWith(
        currentProgress: normalizedProgress,
        isCompleted: isCompleted,
        tokensAwarded: challenge.tokensAwarded || isCompleted,
      );
      challenges.value = updated;
    }
  }
}
