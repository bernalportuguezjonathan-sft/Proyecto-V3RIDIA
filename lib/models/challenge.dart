class Challenge {
  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.targetSpecies,
    required this.targetGoal,
    required this.dueDate,
    required this.createdDate,
    required this.currentProgress,
    required this.isCompleted,
    this.tokensAwarded = false,
    this.tokensReward = 100,
  });

  final String id;
  final String title;
  final String description;
  final String targetSpecies;
  final int targetGoal;
  final DateTime dueDate;
  final DateTime createdDate;
  final int currentProgress;
  final bool isCompleted;
  final bool tokensAwarded;
  final int tokensReward;
}
