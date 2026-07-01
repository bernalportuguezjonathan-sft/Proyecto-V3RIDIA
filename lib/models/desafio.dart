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
    this.assignedToUserId,
    this.assignedToDisplayName,
    this.assignedToEmail,
    this.assignedByAdmin,
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
  final String? assignedToUserId;
  final String? assignedToDisplayName;
  final String? assignedToEmail;
  final String? assignedByAdmin;
  final bool tokensAwarded;
  final int tokensReward;

  bool get isGlobal => assignedToUserId == null;

  Challenge copyWith({
    String? id,
    String? title,
    String? description,
    String? targetSpecies,
    int? targetGoal,
    DateTime? dueDate,
    DateTime? createdDate,
    int? currentProgress,
    bool? isCompleted,
    String? assignedToUserId,
    String? assignedToDisplayName,
    String? assignedToEmail,
    String? assignedByAdmin,
    bool? tokensAwarded,
    int? tokensReward,
  }) {
    return Challenge(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      targetSpecies: targetSpecies ?? this.targetSpecies,
      targetGoal: targetGoal ?? this.targetGoal,
      dueDate: dueDate ?? this.dueDate,
      createdDate: createdDate ?? this.createdDate,
      currentProgress: currentProgress ?? this.currentProgress,
      isCompleted: isCompleted ?? this.isCompleted,
      assignedToUserId: assignedToUserId ?? this.assignedToUserId,
      assignedToDisplayName:
          assignedToDisplayName ?? this.assignedToDisplayName,
      assignedToEmail: assignedToEmail ?? this.assignedToEmail,
      assignedByAdmin: assignedByAdmin ?? this.assignedByAdmin,
      tokensAwarded: tokensAwarded ?? this.tokensAwarded,
      tokensReward: tokensReward ?? this.tokensReward,
    );
  }
}
