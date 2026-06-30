// id_lock_serializer.dart

import 'package:zitf_system/database/id_lock.dart';

Map<String, dynamic> idLockToJson(IdLock lock) {
  return {
    'isLocked': lock.isLocked,
    'lockedAt': lock.lockedAt?.toIso8601String(),
    'lockedByClientId': lock.lockedByClientId,
    'lockedForCount': lock.lockedForCount,
  };
}

IdLock idLockFromJson(Map<String, dynamic> json) {
  return IdLock(
    isLocked: json['isLocked'] ?? false,
    lockedAt:
        json['lockedAt'] != null ? DateTime.parse(json['lockedAt']) : null,
    lockedByClientId: json['lockedByClientId'],
    lockedForCount: json['lockedForCount'],
  );
}

List<IdLock> idLocksFromJson(List<dynamic> jsonList) {
  return jsonList
      .map((json) => idLockFromJson(Map<String, dynamic>.from(json)))
      .toList();
}

List<Map<String, dynamic>> idLocksToJson(List<IdLock> locks) {
  return locks.map((lock) => idLockToJson(lock)).toList();
}
