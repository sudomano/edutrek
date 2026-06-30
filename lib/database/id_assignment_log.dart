import 'package:hive/hive.dart';

part 'id_assignment_log.g.dart';

@HiveType(typeId: 108)
class IdAssignmentLog extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  DateTime assignedAt;

  @HiveField(2)
  String assignedByClientId;

  @HiveField(3)
  String? paymentReceiptNumber;

  @HiveField(4)
  bool isUsed;

  @HiveField(5)
  DateTime? usedAt;

  IdAssignmentLog({
    required this.id,
    DateTime? assignedAt,
    required this.assignedByClientId,
    this.paymentReceiptNumber,
    this.isUsed = false,
    this.usedAt,
  }) : assignedAt = assignedAt ?? DateTime.now();
}
