import 'package:hive/hive.dart';

part 'id_lock.g.dart';

@HiveType(typeId: 104)
class IdLock extends HiveObject {
  @HiveField(0)
  bool isLocked;

  @HiveField(1)
  DateTime? lockedAt;

  @HiveField(2)
  String? lockedByClientId;

  @HiveField(3)
  int? lockedForCount;

  IdLock({
    this.isLocked = false,
    this.lockedAt,
    this.lockedByClientId,
    this.lockedForCount,
  });
}
