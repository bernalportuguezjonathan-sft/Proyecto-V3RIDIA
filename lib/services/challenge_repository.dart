import 'package:flutter/foundation.dart';
import '../models/challenge.dart';
import 'user_repository.dart';

class ChallengeRepository {
  ChallengeRepository._();

  static final ChallengeRepository instance = ChallengeRepository._();

  final ValueNotifier<List<Challenge>> challenges = ValueNotifier<List<Challenge>>([]);

  void addChallenge(Challenge challenge) {
    challenges.value = [challenge, ...challenges.value];
  }

  void updateChallenge(Challenge challenge) {
    final index = challenges.value.indexWhere((item) => item.id == challenge.id);
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
      final isCompleted = newProgress >= challenge.targetGoal;
      
      // Award tokens only when challenge is first completed and not yet awarded
      bool shouldAwardTokens = isCompleted && !challenge.isCompleted && !challenge.tokensAwarded;
      if (shouldAwardTokens) {
        UserRepository.instance.addTokens(challenge.tokensReward);
      }

      final updated = List<Challenge>.from(challenges.value);
      updated[index] = Challenge(
        id: challenge.id,
        title: challenge.title,
        description: challenge.description,
        targetSpecies: challenge.targetSpecies,
        targetGoal: challenge.targetGoal,
        dueDate: challenge.dueDate,
        createdDate: challenge.createdDate,
        currentProgress: newProgress,
        isCompleted: isCompleted,
        tokensAwarded: shouldAwardTokens ? true : challenge.tokensAwarded,
        tokensReward: challenge.tokensReward,
      );
      challenges.value = updated;
    }
  }
}
