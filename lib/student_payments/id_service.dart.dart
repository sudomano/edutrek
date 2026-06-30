// id_service.dart - SIMPLIFIED VERSION (No reservations, no skipping)
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:zitf_system/database/id_assignment_log.dart';
import 'package:zitf_system/database/id_client_reservation.dart';
import 'package:zitf_system/database/id_counter.dart';
import 'package:zitf_system/database/id_lock.dart';
import 'package:zitf_system/database/id_range.dart';
import 'package:zitf_system/database/id_sync_status.dart';
import 'package:zitf_system/database/student_payments.dart';

// ============================================================
// CLIENT ID MANAGER - SIMPLIFIED (No reservations)
// ============================================================
class ClientIdManager {
  final SharedPreferences _prefs;
  final String _hostIp;
  final String _clientId;

  bool _isInitialized = false;
  int _currentId = 0;

  ClientIdManager(this._prefs, this._hostIp) : _clientId = _generateClientId();

  static String _generateClientId() {
    return '${kIsWeb ? 'web' : Platform.isAndroid ? 'android' : 'windows'}_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Get current ID from local storage
      _currentId = _prefs.getInt('current_id') ?? 0;

      // Sync with server to get latest ID
      final serverId = await _fetchLastIdFromServer();
      if (serverId > _currentId) {
        _currentId = serverId;
        await _prefs.setInt('current_id', _currentId);
      }

      _isInitialized = true;
      debugPrint('✅ Client ID Manager initialized. Current ID: $_currentId');
    } catch (e) {
      debugPrint('⚠️ Failed to initialize client ID manager: $e');
      _isInitialized = true;
    }
  }

  Future<int> _fetchLastIdFromServer() async {
    try {
      final response = await http.get(
        Uri.parse('http://$_hostIp:8080/api/ids/last'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['lastId'] as int;
      }
      throw Exception('Failed to fetch last ID');
    } catch (e) {
      debugPrint('⚠️ Could not fetch last ID from server: $e');
      return _prefs.getInt('current_id') ?? 0;
    }
  }

  // ============================================================
  // GET CURRENT ID - WITHOUT INCREMENTING
  // ============================================================
  Future<int> getCurrentId() async {
    if (!_isInitialized) await initialize();
    return _currentId;
  }

  // ============================================================
  // GET NEXT ID - Increments and returns the NEW ID
  // ============================================================
  Future<int> getNextId() async {
    if (!_isInitialized) await initialize();

    // Increment ID
    _currentId = _currentId + 1;
    await _prefs.setInt('current_id', _currentId);

    // Sync with server (async, don't wait)
    unawaited(_syncWithServer());

    debugPrint('🔢 Generated ID: $_currentId');
    return _currentId;
  }

  Future<void> _syncWithServer() async {
    try {
      final response = await http.post(
        Uri.parse('http://$_hostIp:8080/api/ids/reserve'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'count': 1,
          'clientId': _clientId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final ids = List<int>.from(data['ids']);
          if (ids.isNotEmpty) {
            // Update local ID to match server
            _currentId = ids.first;
            await _prefs.setInt('current_id', _currentId);
            debugPrint('✅ Synced ID with server: $_currentId');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to sync with server: $e');
    }
  }

  Map<String, dynamic> getStatus() {
    return {
      'clientId': _clientId,
      'isInitialized': _isInitialized,
      'currentId': _currentId,
      'localCounter': _prefs.getInt('current_id') ?? 0,
    };
  }
}

// ============================================================
// HOST ID SERVICE - SIMPLIFIED (No reservations)
// ============================================================
class IdService {
  static final IdService _instance = IdService._internal();
  factory IdService() => _instance;
  IdService._internal();

  // Box references
  late Box<IdCounter> _counterBox;
  late Box<IdLock> _lockBox;
  late Box<IdAssignmentLog> _assignmentLogBox;

  bool _initialized = false;
  int _cachedCurrentId = 0;

  static const int maxLockAttempts = 20;
  static const Duration lockRetryDelay = Duration(milliseconds: 50);

  // ============================================================
  // INITIALIZATION
  // ============================================================
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Open boxes
      _counterBox = await _openBox<IdCounter>('id_counter');
      _lockBox = await _openBox<IdLock>('id_lock');
      _assignmentLogBox = await _openBox<IdAssignmentLog>('id_assignment_log');

      // Initialize counter if empty
      if (_counterBox.isEmpty) {
        final counter = IdCounter(
          lastAssignedId: 0,
          lastUpdated: DateTime.now(),
          totalIdsAssigned: 0,
        );
        await _counterBox.add(counter);
        debugPrint('✅ ID Counter initialized with 0');
      }

      // Initialize lock if empty
      if (_lockBox.isEmpty) {
        final lock = IdLock(isLocked: false);
        await _lockBox.add(lock);
        debugPrint('✅ ID Lock initialized');
      }

      // Cache current ID
      _cachedCurrentId = _counterBox.getAt(0)?.lastAssignedId ?? 0;

      // Sync counter with existing payments
      await _syncCounterWithPayments();

      _initialized = true;
      debugPrint(
          '✅ ID Service fully initialized. Current ID: $_cachedCurrentId');
    } catch (e) {
      debugPrint('❌ Failed to initialize ID Service: $e');
      rethrow;
    }
  }

  Future<Box<T>> _openBox<T>(String name) async {
    if (Hive.isBoxOpen(name)) {
      return Hive.box<T>(name);
    }
    return await Hive.openBox<T>(name);
  }

  // ============================================================
  // COUNTER SYNC
  // ============================================================
  Future<void> _syncCounterWithPayments() async {
    try {
      final paymentBox = await _openBox<StudentPayment>('student_payments');
      if (paymentBox.isNotEmpty) {
        int maxPaymentId = paymentBox.values
            .map((p) => p.id ?? 0)
            .reduce((curr, next) => curr > next ? curr : next);

        final counter = _counterBox.getAt(0);
        if (counter != null && maxPaymentId > counter.lastAssignedId) {
          counter.lastAssignedId = maxPaymentId;
          counter.lastUpdated = DateTime.now();
          await counter.save();
          _cachedCurrentId = maxPaymentId;
          debugPrint('✅ ID Counter synced with payments: $maxPaymentId');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to sync counter with payments: $e');
    }
  }

  // ============================================================
  // GETTERS - CURRENT ID WITHOUT INCREMENTING
  // ============================================================
  int getLastId() {
    if (!_initialized) {
      throw Exception('ID Service not initialized');
    }
    return _cachedCurrentId;
  }

  Future<int> getCurrentId() async {
    if (!_initialized) await initialize();
    return _cachedCurrentId;
  }

  // ============================================================
  // RESERVE SINGLE ID - Atomic increment
  // ============================================================
  Future<int> reserveSingleId({String? clientId}) async {
    if (!_initialized) await initialize();

    // Acquire lock
    bool lockAcquired = false;
    int attempts = 0;
    IdLock? lock;

    while (attempts < maxLockAttempts && !lockAcquired) {
      lock = _lockBox.getAt(0);

      if (lock != null && !lock.isLocked) {
        lock.isLocked = true;
        lock.lockedAt = DateTime.now();
        lock.lockedByClientId = clientId ?? 'unknown';
        lock.lockedForCount = 1;
        await lock.save();
        lockAcquired = true;
        debugPrint('🔒 Lock acquired for ID reservation');
      } else {
        await Future.delayed(lockRetryDelay);
        attempts++;
      }
    }

    if (!lockAcquired) {
      throw Exception(
          'Could not acquire ID lock after $maxLockAttempts attempts');
    }

    try {
      final counter = _counterBox.getAt(0)!;

      // Increment the counter by 1
      final int newId = counter.lastAssignedId + 1;
      counter.lastAssignedId = newId;
      counter.lastUpdated = DateTime.now();
      counter.totalIdsAssigned += 1;
      counter.lastClientId = clientId ?? 'unknown';
      await counter.save();

      // Update cache
      _cachedCurrentId = newId;

      // Log the assignment
      final log = IdAssignmentLog(
        id: newId,
        assignedAt: DateTime.now(),
        assignedByClientId: clientId ?? 'unknown',
        isUsed: false,
      );
      await _assignmentLogBox.add(log);

      debugPrint('✅ Reserved ID: $newId');
      return newId;
    } finally {
      if (lock != null) {
        lock.isLocked = false;
        lock.lockedAt = null;
        lock.lockedByClientId = null;
        lock.lockedForCount = null;
        await lock.save();
        debugPrint('🔓 Lock released');
      }
    }
  }

  // ============================================================
  // RESERVE MULTIPLE IDs - Atomic increment by count
  // ============================================================
  Future<List<int>> reserveIds(int count, {String? clientId}) async {
    if (!_initialized) await initialize();
    if (count <= 0) return [];

    // Acquire lock
    bool lockAcquired = false;
    int attempts = 0;
    IdLock? lock;

    while (attempts < maxLockAttempts && !lockAcquired) {
      lock = _lockBox.getAt(0);

      if (lock != null && !lock.isLocked) {
        lock.isLocked = true;
        lock.lockedAt = DateTime.now();
        lock.lockedByClientId = clientId ?? 'unknown';
        lock.lockedForCount = count;
        await lock.save();
        lockAcquired = true;
        debugPrint('🔒 Lock acquired for ID reservation (count: $count)');
      } else {
        await Future.delayed(lockRetryDelay);
        attempts++;
      }
    }

    if (!lockAcquired) {
      throw Exception(
          'Could not acquire ID lock after $maxLockAttempts attempts');
    }

    try {
      final counter = _counterBox.getAt(0)!;
      final List<int> newIds = [];

      // Generate consecutive IDs
      for (int i = 0; i < count; i++) {
        final int newId = counter.lastAssignedId + 1;
        newIds.add(newId);
        counter.lastAssignedId = newId;
      }

      counter.lastUpdated = DateTime.now();
      counter.totalIdsAssigned += count;
      counter.lastClientId = clientId ?? 'unknown';
      await counter.save();

      // Update cache
      _cachedCurrentId = counter.lastAssignedId;

      // Log assignments
      for (int id in newIds) {
        final log = IdAssignmentLog(
          id: id,
          assignedAt: DateTime.now(),
          assignedByClientId: clientId ?? 'unknown',
          isUsed: false,
        );
        await _assignmentLogBox.add(log);
      }

      debugPrint(
          '✅ Reserved ${newIds.length} IDs (${newIds.first} - ${newIds.last})');
      return newIds;
    } finally {
      if (lock != null) {
        lock.isLocked = false;
        lock.lockedAt = null;
        lock.lockedByClientId = null;
        lock.lockedForCount = null;
        await lock.save();
        debugPrint('🔓 Lock released');
      }
    }
  }

  // ============================================================
  // MARK AS USED
  // ============================================================
  Future<void> markIdAsUsed(int id, String receiptNumber) async {
    try {
      final logs = _assignmentLogBox.values
          .where((log) => log.id == id && !log.isUsed)
          .toList();

      if (logs.isNotEmpty) {
        final log = logs.first;
        log.isUsed = true;
        log.usedAt = DateTime.now();
        log.paymentReceiptNumber = receiptNumber;
        await log.save();
        debugPrint('✅ ID $id marked as used with receipt: $receiptNumber');
      } else {
        debugPrint('⚠️ No pending assignment found for ID: $id');
      }
    } catch (e) {
      debugPrint('❌ Failed to mark ID $id as used: $e');
    }
  }

  List<int> getPendingIds() {
    return _assignmentLogBox.values
        .where((log) => !log.isUsed)
        .map((log) => log.id)
        .toList();
  }

  bool isIdUsed(int id) {
    return _assignmentLogBox.values.any((log) => log.id == id && log.isUsed);
  }

  // ============================================================
  // STATUS
  // ============================================================
  Map<String, dynamic> getStatus() {
    if (!_initialized) {
      return {'initialized': false};
    }

    final counter = _counterBox.getAt(0);
    final lock = _lockBox.getAt(0);
    final totalAssigned = _assignmentLogBox.values.length;
    final usedIds = _assignmentLogBox.values.where((log) => log.isUsed).length;
    final pendingIds =
        _assignmentLogBox.values.where((log) => !log.isUsed).length;

    return {
      'initialized': _initialized,
      'currentId': _cachedCurrentId,
      'lastAssignedId': counter?.lastAssignedId ?? 0,
      'totalIdsAssigned': counter?.totalIdsAssigned ?? 0,
      'lastUpdated': counter?.lastUpdated.toIso8601String(),
      'isLocked': lock?.isLocked ?? false,
      'lockedByClientId': lock?.lockedByClientId,
      'totalLogs': totalAssigned,
      'usedIds': usedIds,
      'pendingIds': pendingIds,
    };
  }

  Future<void> cleanupOldLogs() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      final logsToRemove = _assignmentLogBox.values
          .where((log) => log.assignedAt.isBefore(cutoffDate))
          .toList();

      for (var log in logsToRemove) {
        await log.delete();
      }

      if (logsToRemove.isNotEmpty) {
        debugPrint('🧹 Cleaned up ${logsToRemove.length} old ID logs');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to clean up old logs: $e');
    }
  }
}
