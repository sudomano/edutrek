import 'package:hive/hive.dart';

part 'id_sync_status.g.dart';

@HiveType(typeId: 105)
class IdSyncStatus extends HiveObject {
  @HiveField(0)
  String deviceId;

  @HiveField(1)
  int lastSyncedId;

  @HiveField(2)
  DateTime lastSyncTime;

  @HiveField(3)
  int pendingIdsCount;

  IdSyncStatus({
    required this.deviceId,
    required this.lastSyncedId,
    DateTime? lastSyncTime,
    this.pendingIdsCount = 0,
  }) : lastSyncTime = lastSyncTime ?? DateTime.now();
}
