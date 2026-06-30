import 'package:flutter_test/flutter_test.dart';
import 'package:veridia_app/models/desafio.dart';
import 'package:veridia_app/models/user.dart';
import 'package:veridia_app/services/repositorioD.dart';
import 'package:veridia_app/services/repositorioU.dart';

void main() {
  setUp(() {
    UserRepository.instance.currentUser.value = UserProfile(
      userId: 'user-1',
      email: 'user@test.com',
      displayName: 'Usuario',
      photoURL: null,
      tokens: 0,
      role: 'Explorador',
      createdDate: DateTime.now(),
    );
    ChallengeRepository.instance.challenges.value = [];
  });

  test('otorga monedas por cada avance y solo descuenta al eliminar si no está completado', () {
    final challenge = Challenge(
      id: 'challenge-1',
      title: 'Reto 1',
      description: 'Descripción',
      targetSpecies: 'Ave',
      targetGoal: 3,
      dueDate: DateTime.now().add(const Duration(days: 7)),
      createdDate: DateTime.now(),
      currentProgress: 0,
      isCompleted: false,
      tokensReward: 100,
    );

    ChallengeRepository.instance.addChallenge(challenge);
    ChallengeRepository.instance.updateProgress(challenge.id, 1);
    expect(UserRepository.instance.getTokens(), 34);

    ChallengeRepository.instance.updateProgress(challenge.id, 2);
    expect(UserRepository.instance.getTokens(), 67);

    ChallengeRepository.instance.updateProgress(challenge.id, 3);
    expect(UserRepository.instance.getTokens(), 100);

    ChallengeRepository.instance.deleteChallenge(challenge.id);
    expect(UserRepository.instance.getTokens(), 100);
  });

  test('no permite acumular más de 100 monedas por los desafíos', () {
    final firstChallenge = Challenge(
      id: 'challenge-1',
      title: 'Reto 1',
      description: 'Descripción',
      targetSpecies: 'Ave',
      targetGoal: 3,
      dueDate: DateTime.now().add(const Duration(days: 7)),
      createdDate: DateTime.now(),
      currentProgress: 0,
      isCompleted: false,
      tokensReward: 100,
    );
    final secondChallenge = Challenge(
      id: 'challenge-2',
      title: 'Reto 2',
      description: 'Descripción',
      targetSpecies: 'Flor',
      targetGoal: 3,
      dueDate: DateTime.now().add(const Duration(days: 7)),
      createdDate: DateTime.now(),
      currentProgress: 0,
      isCompleted: false,
      tokensReward: 100,
    );

    ChallengeRepository.instance.addChallenge(firstChallenge);
    ChallengeRepository.instance.addChallenge(secondChallenge);

    ChallengeRepository.instance.updateProgress(firstChallenge.id, 3);
    ChallengeRepository.instance.updateProgress(secondChallenge.id, 1);

    expect(UserRepository.instance.getTokens(), 100);
  });
}
