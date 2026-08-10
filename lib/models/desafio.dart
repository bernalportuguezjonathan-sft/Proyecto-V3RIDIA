/// Bono de Veridiums por CERRAR un desafío.
///
/// La economía es: cada foto verificada paga 1 Veridium, y completar el
/// desafío añade este extra — un 10% de la meta, acotado entre 1 y 10. Un
/// desafío de 5 fotos paga entonces 5 + 1 = 6 Veridiums en total.
int calcularBonoCompletar(int metaGoal) {
  if (metaGoal <= 1) return 1;
  return (metaGoal / 10).ceil().clamp(1, 10);
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

  /// Se DERIVA siempre de la meta, nunca se lee de Firestore. Hay desafíos
  /// antiguos con `tokensReward: 100` guardado en el documento; confiar en
  /// ese campo hacía que un desafío de 5 fotos pagara 100 Veridiums.
  int get tokensReward => calcularBonoCompletar(targetGoal);

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
          DateTime.tryParse(map['dueDate'] as String? ?? '') ?? DateTime.now(),
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
    );
  }
}
