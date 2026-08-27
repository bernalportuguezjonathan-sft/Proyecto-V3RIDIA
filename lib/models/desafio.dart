import '../theme/veridia_theme.dart';

/// Bono de Veridiums por CERRAR un desafío.
///
/// La economía es: cada foto verificada paga 1 Veridium, y completar el
/// desafío añade este extra — un 10% de la meta, acotado entre 1 y 10. Un
/// desafío de 5 fotos paga entonces 5 + 1 = 6 Veridiums en total.
int calcularBonoCompletar(int metaGoal) {
  if (metaGoal <= 1) return 1;
  return (metaGoal / 10).ceil().clamp(1, 10);
}

/// Avance de UN explorador en UN desafío.
///
/// Vive en `users/{uid}/desafios/{challengeId}`, no dentro del desafío: el
/// progreso es personal. Antes un desafío global guardaba un único
/// `currentProgress` compartido, así que la foto de un explorador subía la
/// barra de todos y el bono se pagaba una sola vez para toda la app.
class ProgresoDesafio {
  const ProgresoDesafio({
    required this.challengeId,
    required this.progreso,
    required this.completado,
    required this.bonoPagado,
    this.actualizado,
  });

  /// Estado inicial de quien todavía no ha subido ninguna foto.
  const ProgresoDesafio.vacio(this.challengeId)
    : progreso = 0,
      completado = false,
      bonoPagado = false,
      actualizado = null;

  final String challengeId;
  final int progreso;
  final bool completado;

  /// Evita pagar dos veces el bono de cierre si el progreso se vuelve a tocar.
  final bool bonoPagado;

  final DateTime? actualizado;

  Map<String, dynamic> toMap() => {
    'progreso': progreso,
    'completado': completado,
    'bonoPagado': bonoPagado,
    'actualizado': aIsoUtc(actualizado ?? DateTime.now()),
  };

  factory ProgresoDesafio.fromMap(String id, Map<String, dynamic> map) {
    return ProgresoDesafio(
      challengeId: id,
      progreso: (map['progreso'] as num?)?.toInt() ?? 0,
      completado: map['completado'] as bool? ?? false,
      bonoPagado: map['bonoPagado'] as bool? ?? false,
      actualizado: deIso(map['actualizado'] as String? ?? ''),
    );
  }
}

/// Definición de un desafío. NO guarda progreso: eso es de cada explorador
/// (ver [ProgresoDesafio]).
class Challenge {
  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.targetSpecies,
    required this.targetGoal,
    required this.dueDate,
    required this.createdDate,
    this.assignedToUserId,
    this.assignedToDisplayName,
    this.assignedToEmail,
    this.assignedByAdmin,
    this.completadoPor = 0,
  });

  final String id;
  final String title;
  final String description;
  final String targetSpecies;
  final int targetGoal;
  final DateTime dueDate;
  final DateTime createdDate;
  final String? assignedToUserId;
  final String? assignedToDisplayName;
  final String? assignedToEmail;
  final String? assignedByAdmin;

  /// Cuántos exploradores lo han completado. Es un contador desnormalizado:
  /// contarlo de verdad exigiría leer la subcolección de cada usuario, que es
  /// caro y además el administrador no puede leer datos de todos.
  final int completadoPor;

  /// Se DERIVA siempre de la meta, nunca se lee de Firestore. Hay desafíos
  /// antiguos con `tokensReward: 100` guardado en el documento; confiar en
  /// ese campo hacía que un desafío de 5 fotos pagara 100 Veridiums.
  int get tokensReward => calcularBonoCompletar(targetGoal);

  bool get isGlobal => assignedToUserId == null;

  /// true si la fecha límite ya pasó.
  bool get vencido => DateTime.now().isAfter(dueDate);

  Challenge copyWith({
    String? id,
    String? title,
    String? description,
    String? targetSpecies,
    int? targetGoal,
    DateTime? dueDate,
    DateTime? createdDate,
    String? assignedToUserId,
    String? assignedToDisplayName,
    String? assignedToEmail,
    String? assignedByAdmin,
    int? completadoPor,
  }) {
    return Challenge(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      targetSpecies: targetSpecies ?? this.targetSpecies,
      targetGoal: targetGoal ?? this.targetGoal,
      dueDate: dueDate ?? this.dueDate,
      createdDate: createdDate ?? this.createdDate,
      assignedToUserId: assignedToUserId ?? this.assignedToUserId,
      assignedToDisplayName:
          assignedToDisplayName ?? this.assignedToDisplayName,
      assignedToEmail: assignedToEmail ?? this.assignedToEmail,
      assignedByAdmin: assignedByAdmin ?? this.assignedByAdmin,
      completadoPor: completadoPor ?? this.completadoPor,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'targetSpecies': targetSpecies,
      'targetGoal': targetGoal,
      'dueDate': aIsoUtc(dueDate),
      'createdDate': aIsoUtc(createdDate),
      'assignedToUserId': assignedToUserId,
      'assignedToDisplayName': assignedToDisplayName,
      'assignedToEmail': assignedToEmail,
      'assignedByAdmin': assignedByAdmin,
      'completadoPor': completadoPor,
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
      dueDate: deIso(map['dueDate'] as String? ?? '') ?? DateTime.now(),
      createdDate: deIso(map['createdDate'] as String? ?? '') ?? DateTime.now(),
      assignedToUserId: map['assignedToUserId'] as String?,
      assignedToDisplayName: map['assignedToDisplayName'] as String?,
      assignedToEmail: map['assignedToEmail'] as String?,
      assignedByAdmin: map['assignedByAdmin'] as String?,
      completadoPor: (map['completadoPor'] as num?)?.toInt() ?? 0,
    );
  }
}
