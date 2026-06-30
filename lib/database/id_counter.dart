import 'package:hive/hive.dart';

part 'id_counter.g.dart';

@HiveType(typeId: 107) // Use a unique typeId not used elsewhere
class IdCounter extends HiveObject {
  @HiveField(0)
  int lastAssignedId;

  @HiveField(1)
  DateTime lastUpdated;

  @HiveField(2)
  int totalIdsAssigned;

  @HiveField(3)
  String? lastClientId;

  IdCounter({
    this.lastAssignedId = 0,
    DateTime? lastUpdated,
    this.totalIdsAssigned = 0,
    this.lastClientId,
  }) : lastUpdated = lastUpdated ?? DateTime.now();
}
