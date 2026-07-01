class AssignmentRecord {
  AssignmentRecord({
    required this.id,
    required this.challengeId,
    required this.challengeTitle,
    required this.eventType,
    required this.note,
    required this.dateTime,
    this.targetUserId,
    this.targetUserDisplayName,
    this.targetUserEmail,
    this.assignedByAdmin,
  });

  final String id;
  final String challengeId;
  final String challengeTitle;
  final String eventType;
  final String note;
  final DateTime dateTime;
  final String? targetUserId;
  final String? targetUserDisplayName;
  final String? targetUserEmail;
  final String? assignedByAdmin;

  String get formattedDate {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
}
