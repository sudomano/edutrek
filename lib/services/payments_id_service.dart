// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import 'package:zitf_system/database/id_assignment_log.dart';
// import 'package:zitf_system/database/id_client_reservation.dart';
// import 'dart:async';

// import 'package:zitf_system/database/id_counter.dart';
// import 'package:zitf_system/database/id_lock.dart';
// import 'package:zitf_system/database/id_range.dart';
// import 'package:zitf_system/database/id_sync_status.dart';
// import 'package:zitf_system/database/student_payments.dart';

// class IdService {
//   static final IdService _instance = IdService._internal();
//   factory IdService() => _instance;
//   IdService._internal();

//   // Box references
//   late Box<IdCounter> _counterBox;
//   late Box<IdLock> _lockBox;
//   late Box<IdAssignmentLog> _assignmentLogBox;
//   late Box<ClientIdReservation> _reservationBox;
//   late Box<IdRange> _rangeBox;
//   late Box<IdSyncStatus> _syncStatusBox;

//   bool _initialized = false;

//   static const int maxLockAttempts = 20;
//   static const Duration lockRetryDelay = Duration(milliseconds: 50);
//   static const int defaultReserveBatchSize = 10;

//   Future<void> initialize() async {
//     if (_initialized) return;

//     try {
//       // Open all boxes
//       _counterBox = await Hive.openBox<IdCounter>('id_counter');
//       _lockBox = await Hive.openBox<IdLock>('id_lock');
//       _assignmentLogBox =
//           await Hive.openBox<IdAssignmentLog>('id_assignment_log');
//       _reservationBox =
//           await Hive.openBox<ClientIdReservation>('id_reservations');
//       _rangeBox = await Hive.openBox<IdRange>('id_ranges');
//       _syncStatusBox = await Hive.openBox<IdSyncStatus>('id_sync_status');

//       // Initialize counter if empty
//       if (_counterBox.isEmpty) {
//         final counter = IdCounter(
//           lastAssignedId: 0,
//           lastUpdated: DateTime.now(),
//           totalIdsAssigned: 0,
//         );
//         await _counterBox.add(counter);
//         debugPrint('✅ ID Counter initialized with 0');
//       }

//       // Initialize lock if empty
//       if (_lockBox.isEmpty) {
//         final lock = IdLock(isLocked: false);
//         await _lockBox.add(lock);
//         debugPrint('✅ ID Lock initialized');
//       }

//       // Sync counter with existing payments
//       await _syncCounterWithPayments();

//       _initialized = true;
//       debugPrint('✅ ID Service fully initialized. Current ID: ${getLastId()}');
//     } catch (e) {
//       debugPrint('❌ Failed to initialize ID Service: $e');
//       rethrow;
//     }
//   }

//   // Sync counter with existing payments
//   Future<void> _syncCounterWithPayments() async {
//     try {
//       final paymentBox = await Hive.openBox<StudentPayment>('student_payments');
//       if (paymentBox.isNotEmpty) {
//         int maxPaymentId = paymentBox.values
//             .map((p) => p.id ?? 0)
//             .reduce((curr, next) => curr > next ? curr : next);

//         final counter = _counterBox.getAt(0);
//         if (counter != null && maxPaymentId > counter.lastAssignedId) {
//           counter.lastAssignedId = maxPaymentId;
//           counter.lastUpdated = DateTime.now();
//           await counter.save();
//           debugPrint('✅ ID Counter synced with payments: $maxPaymentId');
//         }
//       }
//     } catch (e) {
//       debugPrint('⚠️ Failed to sync counter with payments: $e');
//     }
//   }

//   // Get last assigned ID
//   int getLastId() {
//     if (!_initialized) {
//       throw Exception('ID Service not initialized');
//     }
//     final counter = _counterBox.getAt(0);
//     return counter?.lastAssignedId ?? 0;
//   }

//   // Reserve multiple IDs atomically
//   Future<List<int>> reserveIds(int count, {String? clientId}) async {
//     if (!_initialized) await initialize();
//     if (count <= 0) return [];

//     // Acquire lock
//     bool lockAcquired = false;
//     int attempts = 0;
//     IdLock? lock;

//     while (attempts < maxLockAttempts && !lockAcquired) {
//       lock = _lockBox.getAt(0);

//       if (lock != null && !lock.isLocked) {
//         lock.isLocked = true;
//         lock.lockedAt = DateTime.now();
//         lock.lockedByClientId = clientId ?? 'unknown';
//         lock.lockedForCount = count;
//         await lock.save();
//         lockAcquired = true;
//         debugPrint('🔒 Lock acquired for ID reservation (count: $count)');
//       } else {
//         await Future.delayed(lockRetryDelay);
//         attempts++;
//       }
//     }

//     if (!lockAcquired) {
//       throw Exception(
//           'Could not acquire ID lock after $maxLockAttempts attempts');
//     }

//     try {
//       // Atomic read and increment
//       final counter = _counterBox.getAt(0)!;
//       final int currentId = counter.lastAssignedId;
//       final List<int> newIds = [];

//       for (int i = 1; i <= count; i++) {
//         newIds.add(currentId + i);
//       }

//       // Update counter
//       counter.lastAssignedId = currentId + count;
//       counter.lastUpdated = DateTime.now();
//       counter.totalIdsAssigned += count;
//       counter.lastClientId = clientId ?? 'unknown';
//       await counter.save();

//       // Log assignments
//       for (int id in newIds) {
//         final log = IdAssignmentLog(
//           id: id,
//           assignedAt: DateTime.now(),
//           assignedByClientId: clientId ?? 'unknown',
//           isUsed: false,
//         );
//         await _assignmentLogBox.add(log);
//       }

//       debugPrint(
//           '✅ Reserved ${newIds.length} IDs (${newIds.first} - ${newIds.last})');
//       return newIds;
//     } finally {
//       // Release lock
//       if (lock != null) {
//         lock.isLocked = false;
//         lock.lockedAt = null;
//         lock.lockedByClientId = null;
//         lock.lockedForCount = null;
//         await lock.save();
//         debugPrint('🔓 Lock released');
//       }
//     }
//   }

//   // Reserve a single ID
//   Future<int> reserveSingleId({String? clientId}) async {
//     final ids = await reserveIds(1, clientId: clientId);
//     return ids.isNotEmpty ? ids.first : 0;
//   }

//   // Mark an ID as used
//   Future<void> markIdAsUsed(int id, String receiptNumber) async {
//     try {
//       // Find the assignment log
//       final logs = _assignmentLogBox.values
//           .where((log) => log.id == id && !log.isUsed)
//           .toList();

//       if (logs.isNotEmpty) {
//         final log = logs.first;
//         log.isUsed = true;
//         log.usedAt = DateTime.now();
//         log.paymentReceiptNumber = receiptNumber;
//         await log.save();
//         debugPrint('✅ ID $id marked as used with receipt: $receiptNumber');
//       } else {
//         debugPrint('⚠️ No pending assignment found for ID: $id');
//       }
//     } catch (e) {
//       debugPrint('❌ Failed to mark ID $id as used: $e');
//     }
//   }

//   // Get all pending IDs (assigned but not used)
//   List<int> getPendingIds() {
//     return _assignmentLogBox.values
//         .where((log) => !log.isUsed)
//         .map((log) => log.id)
//         .toList();
//   }

//   // Check if an ID is already used
//   bool isIdUsed(int id) {
//     return _assignmentLogBox.values.any((log) => log.id == id && log.isUsed);
//   }

//   // Get ID status
//   Map<String, dynamic> getStatus() {
//     if (!_initialized) {
//       return {'initialized': false};
//     }

//     final counter = _counterBox.getAt(0);
//     final lock = _lockBox.getAt(0);
//     final totalAssigned = _assignmentLogBox.values.length;
//     final usedIds = _assignmentLogBox.values.where((log) => log.isUsed).length;
//     final pendingIds =
//         _assignmentLogBox.values.where((log) => !log.isUsed).length;

//     return {
//       'initialized': _initialized,
//       'lastAssignedId': counter?.lastAssignedId ?? 0,
//       'totalIdsAssigned': counter?.totalIdsAssigned ?? 0,
//       'lastUpdated': counter?.lastUpdated.toIso8601String(),
//       'isLocked': lock?.isLocked ?? false,
//       'lockedByClientId': lock?.lockedByClientId,
//       'totalLogs': totalAssigned,
//       'usedIds': usedIds,
//       'pendingIds': pendingIds,
//       'pendingIdList': getPendingIds().take(10).toList(),
//     };
//   }

//   // Sync client ID manager with server
//   Future<Map<String, dynamic>> syncClient({required String clientId}) async {
//     try {
//       // Get last synced status for this client
//       final syncStatus =
//           _syncStatusBox.values.where((s) => s.deviceId == clientId).toList();

//       late IdSyncStatus status;
//       if (syncStatus.isNotEmpty) {
//         status = syncStatus.first;
//       } else {
//         status = IdSyncStatus(
//           deviceId: clientId,
//           lastSyncedId: 0,
//           lastSyncTime: DateTime.now(),
//         );
//         await _syncStatusBox.add(status);
//       }

//       final currentId = getLastId();

//       // Check for unassigned IDs that might have been missed
//       final pendingIds = getPendingIds();
//       final missedIds =
//           pendingIds.where((id) => id <= status.lastSyncedId).toList();

//       status.lastSyncedId = currentId;
//       status.lastSyncTime = DateTime.now();
//       status.pendingIdsCount = pendingIds.length - missedIds.length;
//       await status.save();

//       debugPrint(
//           '🔄 Synced client $clientId. Last ID: $currentId, Pending: ${status.pendingIdsCount}');

//       return {
//         'success': true,
//         'lastId': currentId,
//         'pendingIdsCount': status.pendingIdsCount,
//         'syncedAt': status.lastSyncTime.toIso8601String(),
//       };
//     } catch (e) {
//       debugPrint('❌ Failed to sync client $clientId: $e');
//       return {
//         'success': false,
//         'error': e.toString(),
//       };
//     }
//   }

//   // Clean up old logs (older than 30 days)
//   Future<void> cleanupOldLogs() async {
//     try {
//       final cutoffDate = DateTime.now().subtract(const Duration(days: 30));

//       final logsToRemove = _assignmentLogBox.values
//           .where((log) => log.assignedAt.isBefore(cutoffDate))
//           .toList();

//       for (var log in logsToRemove) {
//         await log.delete();
//       }

//       if (logsToRemove.isNotEmpty) {
//         debugPrint('🧹 Cleaned up ${logsToRemove.length} old ID logs');
//       }
//     } catch (e) {
//       debugPrint('⚠️ Failed to clean up old logs: $e');
//     }
//   }
// }
