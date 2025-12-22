import 'package:hive/hive.dart';

part 'sync_log.g.dart';

@HiveType(typeId: 50)
class SyncLog extends HiveObject {
  @HiveField(0)
  String timestamp;

  @HiveField(1)
  String model;

  @HiveField(2)
  String id;

  @HiveField(3)
  String error;

  SyncLog({
    required this.timestamp,
    required this.model,
    required this.id,
    required this.error,
  });
}
