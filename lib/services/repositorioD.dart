import 'package:flutter/foundation.dart';
import '../models/desafio.dart';
import 'repositorioU.dart';

class ChallengeRepository {
  ChallengeRepository._();

  static final ChallengeRepository instance = ChallengeRepository._();

  final ValueNotifier<List<Challenge>> challenges = ValueNotifier<List<Challenge>>([]);
  final Map<String, List<int>> _rewardHistoryByChallenge = {};

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
    final challenge = challenges.value.firstWhere(
      (item) => item.id == id,
      orElse: () => Challenge(
        id: '',
        title: '',
        description: '',
        targetSpecies: '',
        targetGoal: 0,
        dueDate: DateTime.now(),
        createdDate: DateTime.now(),
        currentProgress: 0,
        isCompleted: false,
        tokensAwarded: false,
        tokensReward: 0,
      ),
    );

    final rewards = _rewardHistoryByChallenge.remove(id);
    if (challenge.id.isNotEmpty && rewards != null && rewards.isNotEmpty && !challenge.isCompleted) {
      final awardedTokens = rewards.fold<int>(0, (sum, reward) => sum + reward);
      UserRepository.instance.removeTokens(awardedTokens);
    }

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
        final rewards = _rewardHistoryByChallenge.putIfAbsent(challenge.id, () => <int>[]);
        var awardedSoFar = rewards.fold<int>(0, (sum, reward) => sum + reward);

        for (var step = 0; step < progressDelta; step++) {
          final remainingSteps = (challenge.targetGoal - (challenge.currentProgress + step))
              .clamp(1, 1000000);
          final reward = ((100 - awardedSoFar) / remainingSteps).ceil();
          final finalReward = reward.clamp(0, 100 - awardedSoFar);

          if (finalReward > 0) {
            rewards.add(finalReward);
            awardedSoFar += finalReward;
            UserRepository.instance.addTokens(finalReward);
          }
        }
      } else if (progressDelta < 0) {
        final rewards = _rewardHistoryByChallenge[challenge.id];
        if (rewards != null) {
          for (var step = 0; step < (-progressDelta); step++) {
            if (rewards.isNotEmpty) {
              final reward = rewards.removeLast();
              UserRepository.instance.removeTokens(reward);
            }
          }
        }
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
        currentProgress: normalizedProgress,
        isCompleted: isCompleted,
        tokensAwarded: challenge.tokensAwarded || isCompleted,
        tokensReward: challenge.tokensReward,
      );
      challenges.value = updated;
    }
  }
}
