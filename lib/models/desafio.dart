/// Bono de Veridiums al completar un desafío: 10% de la meta, redondeado
/// hacia arriba, mínimo 1. Reemplaza el antiguo valor fijo (100 para
/// cualquier meta, sin relación con el esfuerzo pedido).
int calcularBonoCompletar(int metaGoal) {
  if (metaGoal <= 0) return 1;
  final bono = (metaGoal / 10).ceil();
  return bono < 1 ? 1 : bono;
}

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
    int? tokensReward,
  }) : tokensReward = tokensReward ?? calcularBonoCompletar(targetGoal);

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

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'targetSpecies': targetSpecies,
      'targetGoal': targetGoal,
      'dueDate': dueDate.toIso8601String(),
      'createdDate': createdDate.toIso8601String(),
      'currentProgress': currentProgress,
      'isCompleted': isCompleted,
      'assignedToUserId': assignedToUserId,
      'assignedToDisplayName': assignedToDisplayName,
      'assignedToEmail': assignedToEmail,
      'assignedByAdmin': assignedByAdmin,
      'tokensAwarded': tokensAwarded,
      'tokensReward': tokensReward,
    };
  }

  factory Challenge.fromMap(String id, Map<String, dynamic> map) {
    return Challenge(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      targetSpecies: map['targetSpecies'] as String? ?? '',
      targetGoal: (map['targetGoal'] as num?)?.toInt() ?? 1,
      dueDate:
          DateTime.tryParse(map['dueDate'] as String? ?? '') ??
          DateTime.now(),
      createdDate:
          DateTime.tryParse(map['createdDate'] as String? ?? '') ??
          DateTime.now(),
      currentProgress: (map['currentProgress'] as num?)?.toInt() ?? 0,
      isCompleted: map['isCompleted'] as bool? ?? false,
      assignedToUserId: map['assignedToUserId'] as String?,
      assignedToDisplayName: map['assignedToDisplayName'] as String?,
      assignedToEmail: map['assignedToEmail'] as String?,
      assignedByAdmin: map['assignedByAdmin'] as String?,
      tokensAwarded: map['tokensAwarded'] as bool? ?? false,
      tokensReward:
          (map['tokensReward'] as num?)?.toInt() ??
          calcularBonoCompletar((map['targetGoal'] as num?)?.toInt() ?? 1),
    );
  }
}
