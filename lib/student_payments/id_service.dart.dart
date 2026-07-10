// id_service.dart - FIXED VERSION with proper validation and UI support

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
import 'package:zitf_system/database/payment_receipts_log.dart';

// ============================================================
// CLIENT ID MANAGER - SIMPLIFIED (No reservations)
// ============================================================
class ClientIdManager {
  final SharedPreferences _prefs;
  final String _hostIp;
  final String _clientId;

  bool _isInitialized = false;
  int _currentId = 0;
  bool _hasExistingPayments = false; // Track if payments exist
  bool _isServerReachable = false;
  ClientIdManager(this._prefs, this._hostIp) : _clientId = _generateClientId();

  static String _generateClientId() {
    return '${kIsWeb ? 'web' : Platform.isAndroid ? 'android' : 'windows'}_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Get current ID from local storage
      _currentId = _prefs.getInt('current_id') ?? 0;

      // ✅ Check if there are existing payments in local cache
      _hasExistingPayments = await _checkExistingPayments();

      // ✅ Sync with server to get latest ID
      final serverId = await _fetchLastIdFromServer();

      if (serverId > 0) {
        // Server returned a valid ID
        _isServerReachable = true;
        if (serverId > _currentId) {
          _currentId = serverId;
          await _prefs.setInt('current_id', _currentId);
        }
        debugPrint('✅ Client ID Manager initialized. Current ID: $_currentId');
      } else {
        // Server returned 0 or failed
        _isServerReachable = false;

        if (_hasExistingPayments && _currentId <= 0) {
          // ❌ CRITICAL: We have existing payments but no valid ID
          throw Exception(
              '⚠️ ID Service Error: Existing payments found but no valid ID available.\n'
              'Cannot process payments until ID service is synced with the host.\n'
              'Please contact the administrator to sync the ID counter.');
        }

        if (_currentId > 0) {
          // We have a cached ID, use it but warn
          debugPrint('⚠️ Server unreachable, using cached ID: $_currentId');
        } else {
          // No cached ID and server unreachable - this is dangerous
          throw Exception(
              '⚠️ ID Service Error: No ID available. Cannot process payments.\n'
              'Please ensure the host is reachable and try again.');
        }
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ Failed to initialize client ID manager: $e');
      rethrow; // Don't silently fail
    }
  }

// ✅ Check if there are existing payments
  Future<bool> _checkExistingPayments() async {
    try {
      // Try to open the payment box
      if (Hive.isBoxOpen('student_payments')) {
        final box = Hive.box<StudentPayment>('student_payments');
        return box.isNotEmpty;
      } else {
        final box = await Hive.openBox<StudentPayment>('student_payments');
        final hasPayments = box.isNotEmpty;
        await box.close();
        return hasPayments;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to check existing payments: $e');
      return false;
    }
  }

  Future<int> _fetchLastIdFromServer() async {
    try {
      final response = await http.get(
        Uri.parse('http://$_hostIp:8080/api/ids/last'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final lastId = data['lastId'] as int?;
        if (lastId != null && lastId > 0) {
          return lastId;
        }
        // If server returns 0 or null, check if there are payments
        final hasPayments = await _checkExistingPayments();
        if (hasPayments) {
          // There are payments but server says 0 - this is a problem
          debugPrint('⚠️ Server returned 0 but local has payments!');
          return -1; // Signal that there's a mismatch
        }
        return 0;
      }
      throw Exception('Failed to fetch last ID: ${response.statusCode}');
    } catch (e) {
      debugPrint('⚠️ Could not fetch last ID from server: $e');
      rethrow; // Rethrow to be handled by initialize()
    }
  }

  Future<int> getCurrentId() async {
    if (!_isInitialized) await initialize();
    return _currentId;
  }

  Future<int> getNextId() async {
    if (!_isInitialized) await initialize();

    // ✅ Validate that we have a valid ID before proceeding
    if (_currentId <= 0 && _hasExistingPayments) {
      throw Exception('⚠️ ID Service Error: Cannot generate receipt number.\n'
          'The ID counter is not properly synced with the server.\n'
          'Please contact the administrator to fix the ID service.');
    }

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
      final response = await http
          .post(
            Uri.parse('http://$_hostIp:8080/api/ids/reserve'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'count': 1,
              'clientId': _clientId,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final ids = List<int>.from(data['ids']);
          if (ids.isNotEmpty) {
            _currentId = ids.first;
            await _prefs.setInt('current_id', _currentId);
            debugPrint('✅ Synced ID with server: $_currentId');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to sync with server: $e');
      // Don't throw - payment already saved locally
    }
  }

  Map<String, dynamic> getStatus() {
    return {
      'clientId': _clientId,
      'isInitialized': _isInitialized,
      'currentId': _currentId,
      'localCounter': _prefs.getInt('current_id') ?? 0,
      'hasExistingPayments': _hasExistingPayments,
      'isServerReachable': _isServerReachable,
    };
  }
}

// ============================================================
// HOST ID SERVICE - FIXED VERSION
// ============================================================
class IdService {
  static final IdService _instance = IdService._internal();
  factory IdService() => _instance;
  IdService._internal();

  // Box references
  late Box<IdCounter> _counterBox;
  late Box<IdLock> _lockBox;
  late Box<IdAssignmentLog> _assignmentLogBox;
  late Box<PaymentLog> _paymentLogBox;
  late Box<StudentPayment> _studentPaymentBox;

  bool _initialized = false;
  int _cachedCurrentId = 0;

  static const int maxLockAttempts = 20;
  static const Duration lockRetryDelay = Duration(milliseconds: 50);

  // ============================================================
  // INITIALIZATION WITH VALIDATION
  // ============================================================
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Open all required boxes
      _counterBox = await _openBox<IdCounter>('id_counter');
      _lockBox = await _openBox<IdLock>('id_lock');
      _assignmentLogBox = await _openBox<IdAssignmentLog>('id_assignment_log');
      _paymentLogBox = await _openBox<PaymentLog>('payment_log');
      _studentPaymentBox = await _openBox<StudentPayment>('student_payments');

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

      // ============================================================
      // STEP 1: Get the highest ID from ALL sources
      // ============================================================
      final int maxPaymentId = _getMaxPaymentId();
      final int maxReceiptId = _getMaxReceiptId();
      final int maxAssignedId = _getMaxAssignedId();

      // The true current ID should be the maximum of all sources
      int trueCurrentId = maxPaymentId;
      if (maxReceiptId > trueCurrentId) trueCurrentId = maxReceiptId;
      if (maxAssignedId > trueCurrentId) trueCurrentId = maxAssignedId;

      // ============================================================
      // STEP 2: Update counter if needed
      // ============================================================
      final counter = _counterBox.getAt(0)!;

      if (counter.lastAssignedId < trueCurrentId) {
        debugPrint('⚠️ Counter mismatch detected!');
        debugPrint('   Counter: ${counter.lastAssignedId}');
        debugPrint('   Max Payment ID: $maxPaymentId');
        debugPrint('   Max Receipt ID: $maxReceiptId');
        debugPrint('   Max Assigned ID: $maxAssignedId');
        debugPrint('   True Current ID: $trueCurrentId');

        counter.lastAssignedId = trueCurrentId;
        counter.lastUpdated = DateTime.now();
        await counter.save();

        debugPrint('✅ Counter updated to: $trueCurrentId');
      }

      // Cache current ID
      _cachedCurrentId = counter.lastAssignedId;

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
  // GET MAXIMUM ID FROM ALL SOURCES
  // ============================================================
  int _getMaxPaymentId() {
    try {
      if (_studentPaymentBox.isNotEmpty) {
        int maxId = 0;
        for (var payment in _studentPaymentBox.values) {
          final id = payment.id ?? 0;
          if (id > maxId) maxId = id;
        }
        return maxId;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to get max payment ID: $e');
    }
    return 0;
  }

  int _getMaxReceiptId() {
    try {
      if (_paymentLogBox.isNotEmpty) {
        int maxId = 0;
        for (var log in _paymentLogBox.values) {
          final id = log.receiptNumber ?? 0;
          if (id > maxId) maxId = id;
        }
        return maxId;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to get max receipt ID: $e');
    }
    return 0;
  }

  int _getMaxAssignedId() {
    try {
      if (_assignmentLogBox.isNotEmpty) {
        int maxId = 0;
        for (var log in _assignmentLogBox.values) {
          final id = log.id ?? 0;
          if (id > maxId) maxId = id;
        }
        return maxId;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to get max assigned ID: $e');
    }
    return 0;
  }

  // ============================================================
  // GETTERS
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
  // RESERVE SINGLE ID
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
  // RESERVE MULTIPLE IDs
  // ============================================================
  Future<List<int>> reserveIds(int count, {String? clientId}) async {
    if (!_initialized) await initialize();
    if (count <= 0) return [];

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

      for (int i = 0; i < count; i++) {
        final int newId = counter.lastAssignedId + 1;
        newIds.add(newId);
        counter.lastAssignedId = newId;
      }

      counter.lastUpdated = DateTime.now();
      counter.totalIdsAssigned += count;
      counter.lastClientId = clientId ?? 'unknown';
      await counter.save();

      _cachedCurrentId = counter.lastAssignedId;

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
  // FORCE UPDATE - Admin UI
  // ============================================================
  Future<void> forceUpdateCounter(int newId, {String? reason}) async {
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
        lock.lockedByClientId = 'admin_force_update';
        lock.lockedForCount = 1;
        await lock.save();
        lockAcquired = true;
        debugPrint('🔒 Lock acquired for force update');
      } else {
        await Future.delayed(lockRetryDelay);
        attempts++;
      }
    }

    if (!lockAcquired) {
      throw Exception('Could not acquire ID lock for force update');
    }

    try {
      final counter = _counterBox.getAt(0)!;

      // Validate that the new ID is greater than current
      if (newId <= counter.lastAssignedId) {
        throw Exception(
            'New ID ($newId) must be greater than current ID (${counter.lastAssignedId})');
      }

      final oldId = counter.lastAssignedId;
      counter.lastAssignedId = newId;
      counter.lastUpdated = DateTime.now();
      counter.totalIdsAssigned += (newId - oldId);
      counter.lastClientId = 'admin_force_update';
      await counter.save();

      _cachedCurrentId = newId;

      // Log the forced update
      final log = IdAssignmentLog(
        id: newId,
        assignedAt: DateTime.now(),
        assignedByClientId: 'admin_force_update',
        isUsed: false,
      );
      await _assignmentLogBox.add(log);

      debugPrint('✅ Force updated ID counter from $oldId to $newId');
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
  // SYNC COUNTER - Admin UI
  // ============================================================
  Future<Map<String, dynamic>> syncCounterWithSources() async {
    if (!_initialized) await initialize();

    final int maxPaymentId = _getMaxPaymentId();
    final int maxReceiptId = _getMaxReceiptId();
    final int maxAssignedId = _getMaxAssignedId();
    final int trueCurrentId = [maxPaymentId, maxReceiptId, maxAssignedId]
        .reduce((a, b) => a > b ? a : b);

    final counter = _counterBox.getAt(0)!;
    final int currentCounterId = counter.lastAssignedId;

    final result = {
      'currentCounterId': currentCounterId,
      'maxPaymentId': maxPaymentId,
      'maxReceiptId': maxReceiptId,
      'maxAssignedId': maxAssignedId,
      'trueCurrentId': trueCurrentId,
      'needsUpdate': trueCurrentId > currentCounterId,
    };

    if (trueCurrentId > currentCounterId) {
      counter.lastAssignedId = trueCurrentId;
      counter.lastUpdated = DateTime.now();
      await counter.save();
      _cachedCurrentId = trueCurrentId;
      debugPrint('✅ Counter synced to: $trueCurrentId');
      result['updated'] = true;
      result['newCounterId'] = trueCurrentId;
    } else {
      debugPrint('✅ Counter is already up to date: $currentCounterId');
      result['updated'] = false;
    }

    return result;
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
      'maxPaymentId': _getMaxPaymentId(),
      'maxReceiptId': _getMaxReceiptId(),
      'maxAssignedId': _getMaxAssignedId(),
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

// ============================================================
// ID SERVICE UI - Admin Settings Page
// ============================================================
class IdServiceSettingsPage extends StatefulWidget {
  const IdServiceSettingsPage({Key? key}) : super(key: key);

  @override
  State<IdServiceSettingsPage> createState() => _IdServiceSettingsPageState();
}

class _IdServiceSettingsPageState extends State<IdServiceSettingsPage> {
  final TextEditingController _newIdController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  bool _isLoading = true;
  bool _isUpdating = false;
  Map<String, dynamic> _status = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _isLoading = true);
    try {
      final idService = IdService();
      await idService.initialize();
      _status = idService.getStatus();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _syncCounter() async {
    setState(() => _isUpdating = true);
    try {
      final idService = IdService();
      final result = await idService.syncCounterWithSources();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['updated']
              ? '✅ Counter updated to: ${result['newCounterId']}'
              : '✅ Counter is already up to date'),
          backgroundColor: result['updated'] ? Colors.green : Colors.blue,
        ),
      );

      await _loadStatus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to sync: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    setState(() => _isUpdating = false);
  }

  Future<void> _forceUpdateCounter() async {
    final newId = int.tryParse(_newIdController.text.trim());
    if (newId == null || newId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid positive number'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final currentId = _status['lastAssignedId'] ?? 0;
    if (newId <= currentId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'New ID ($newId) must be greater than current ID ($currentId)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ Force Update ID Counter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current ID: $currentId'),
            Text('New ID: $newId'),
            const SizedBox(height: 12),
            const Text(
              'This will skip forward to the new ID. '
              'IDs between current and new will be skipped.',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                hintText: 'Reason for update (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(_, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Force Update'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isUpdating = true);
    try {
      final idService = IdService();
      await idService.forceUpdateCounter(
        newId,
        reason: _reasonController.text.trim().isNotEmpty
            ? _reasonController.text.trim()
            : 'Admin force update',
      );

      _reasonController.clear();
      _newIdController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ID counter updated to: $newId'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadStatus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to update: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    setState(() => _isUpdating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ID Service Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadStatus,
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_error', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadStatus,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Current Status',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildStatusRow('Current ID',
                                  _status['currentId']?.toString() ?? 'N/A'),
                              _buildStatusRow(
                                  'Last Assigned ID',
                                  _status['lastAssignedId']?.toString() ??
                                      'N/A'),
                              _buildStatusRow(
                                  'Total IDs Assigned',
                                  _status['totalIdsAssigned']?.toString() ??
                                      '0'),
                              _buildStatusRow('Max Payment ID',
                                  _status['maxPaymentId']?.toString() ?? '0'),
                              _buildStatusRow('Max Receipt ID',
                                  _status['maxReceiptId']?.toString() ?? '0'),
                              _buildStatusRow('Max Assigned ID',
                                  _status['maxAssignedId']?.toString() ?? '0'),
                              _buildStatusRow('Pending IDs',
                                  _status['pendingIds']?.toString() ?? '0'),
                              _buildStatusRow('Used IDs',
                                  _status['usedIds']?.toString() ?? '0'),
                              _buildStatusRow(
                                  'Locked',
                                  _status['isLocked'] == true
                                      ? '🔒 Yes'
                                      : '🔓 No'),
                              if (_status['lockedByClientId'] != null)
                                _buildStatusRow(
                                    'Locked By', _status['lockedByClientId']),
                              _buildStatusRow(
                                  'Last Updated',
                                  _status['lastUpdated'] != null
                                      ? DateTime.parse(_status['lastUpdated'])
                                          .toLocal()
                                          .toString()
                                      : 'N/A'),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Sync Button
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sync Counter',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Check all payment and receipt records and update the counter to the highest ID found.',
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _isUpdating ? null : _syncCounter,
                                icon: _isUpdating
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.sync),
                                label: const Text('Sync Now'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Force Update Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Force Update Counter',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Manually set the ID counter to a specific value. '
                                'Use this ONLY if IDs are out of sync or you need to skip a range.',
                                style:
                                    TextStyle(fontSize: 12, color: Colors.red),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _newIdController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'New ID Number',
                                  hintText: 'Enter the new starting ID',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.numbers),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _reasonController,
                                decoration: const InputDecoration(
                                  labelText: 'Reason (optional)',
                                  hintText: 'Why is this update needed?',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed:
                                    _isUpdating ? null : _forceUpdateCounter,
                                icon: _isUpdating
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.warning_amber),
                                label: const Text('Force Update'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
