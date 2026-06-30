import 'package:hive/hive.dart';

part 'id_range.g.dart';

@HiveType(typeId: 106)
class IdRange extends HiveObject {
  @HiveField(0)
  int startId;

  @HiveField(1)
  int endId;

  @HiveField(2)
  String assignedTo;

  @HiveField(3)
  DateTime assignedAt;

  @HiveField(4)
  bool isFullyUsed;

  IdRange({
    required this.startId,
    required this.endId,
    required this.assignedTo,
    DateTime? assignedAt,
    this.isFullyUsed = false,
  }) : assignedAt = assignedAt ?? DateTime.now();
}
