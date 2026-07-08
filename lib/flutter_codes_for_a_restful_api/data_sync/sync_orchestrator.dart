// lib/services/sync_orchestrator.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/flutter_codes_for_a_restful_api/data_sync/connectivity_monitor.dart';

typedef SyncFunction = Future<void> Function();

class SyncOrchestrator {
  static final SyncOrchestrator _instance = SyncOrchestrator._internal();
  factory SyncOrchestrator() => _instance;
  SyncOrchestrator._internal();

  final ConnectivityMonitor _connectivity = ConnectivityMonitor();
  Timer? _syncTimer;
  bool _isSyncing = false;

  // Callback to your existing sync function
  SyncFunction? _syncFunction;

  // Status stream for UI updates
  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  SyncStatus _currentStatus = SyncStatus.idle("");
  SyncStatus get currentStatus => _currentStatus;

  void initialize(SyncFunction syncFunction, {String? domainName}) {
    _syncFunction = syncFunction;

    // Initialize connectivity monitor with domain
    _connectivity.initialize(domainName: domainName);

    // Listen to connectivity changes
    _connectivity.addListener((connected) {
      if (connected && !_isSyncing) {
        _updateStatus(SyncStatus.ready('Network available, ready to sync'));
      } else if (!connected) {
        _updateStatus(SyncStatus.waiting('Waiting for network connection...'));
      }
    });

    // Start auto-sync loop
    _startAutoSyncLoop();
  }

  void _startAutoSyncLoop() {
    _syncTimer?.cancel();

    // Check every 2 minutes
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _checkAndSync();
    });

    // Initial check after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      _checkAndSync();
    });
  }

  Future<void> _checkAndSync() async {
    // Don't start if already syncing or no internet
    if (_isSyncing) {
      return;
    }

    // First, verify connectivity
    final hasConnection = await _connectivity.checkConnectivity();
    if (!hasConnection) {
      _updateStatus(SyncStatus.waiting('No network connection'));
      return;
    }

    // Check if there are unsynced records
    final hasUnsynced = await _checkForUnsyncedRecords();
    if (!hasUnsynced) {
      _updateStatus(SyncStatus.idle('All records synced'));
      return;
    }

    // Start sync
    await _performSync();
  }

  Future<bool> _checkForUnsyncedRecords() async {
    try {
      // Check all open Hive boxes for unsynced records
      // This is a lightweight check without opening all boxes
      final boxNames = [
        'classes',
        'school',
        'terms',
        'withdrawals',
        'students',
        'users',
        'payment_purposes',
        'student_payments',
        'teachers',
        'teacher_payments_purposes',
        'teacher_payments',
        'domainBox',
        'account',
        'asset',
        'projects',
        'projectItems',
        'dailyActivities',
        'exceptionalStudentsBox',
        'batch_units',
        'product_batches',
        'project_item_prices',
        'project_sale_transactions',
        'batch_sell_units',
        'payment_methods',
        'receipt_snapshots',
        'payment_log'
      ];

      for (String name in boxNames) {
        try {
          if (Hive.isBoxOpen(name)) {
            final box = Hive.box(name);
            final unsynced =
                box.values.where((record) => record.syncStatus == false).length;
            if (unsynced > 0) {
              return true;
            }
          }
        } catch (_) {
          // Box might not be open, skip
          continue;
        }
      }
      return false;
    } catch (_) {
      return true; // If we can't check, assume there's unsynced data
    }
  }

  Future<void> _performSync() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _updateStatus(SyncStatus.syncing('Syncing records...'));

    try {
      // Call your existing _syncModels() function
      if (_syncFunction != null) {
        await _syncFunction!();
        _updateStatus(SyncStatus.completed('Sync completed successfully'));
      }
    } catch (e) {
      _updateStatus(SyncStatus.error('Sync failed: $e'));
    } finally {
      _isSyncing = false;
    }
  }

  // Manual sync trigger
  Future<void> manualSync() async {
    if (_isSyncing) {
      _updateStatus(SyncStatus.waiting('Sync already in progress'));
      return;
    }

    final hasConnection = await _connectivity.checkConnectivity();
    if (!hasConnection) {
      _updateStatus(SyncStatus.error('No network connection'));
      return;
    }

    await _performSync();
  }

  void _updateStatus(SyncStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  void pauseAutoSync() {
    _syncTimer?.cancel();
    _updateStatus(SyncStatus.paused('Auto-sync paused'));
  }

  void resumeAutoSync() {
    _startAutoSyncLoop();
    _updateStatus(SyncStatus.ready('Auto-sync resumed'));
  }

  void dispose() {
    _syncTimer?.cancel();
    _connectivity.dispose();
    _statusController.close();
  }
}

// Sync Status Models
class SyncStatus {
  final String message;
  final String type; // idle, ready, waiting, syncing, completed, error, paused

  const SyncStatus._({
    required this.message,
    required this.type,
  });

  factory SyncStatus.idle(String message) =>
      SyncStatus._(message: message, type: 'idle');

  factory SyncStatus.ready(String message) =>
      SyncStatus._(message: message, type: 'ready');

  factory SyncStatus.waiting(String message) =>
      SyncStatus._(message: message, type: 'waiting');

  factory SyncStatus.syncing(String message) =>
      SyncStatus._(message: message, type: 'syncing');

  factory SyncStatus.completed(String message) =>
      SyncStatus._(message: message, type: 'completed');

  factory SyncStatus.error(String message) =>
      SyncStatus._(message: message, type: 'error');

  factory SyncStatus.paused(String message) =>
      SyncStatus._(message: message, type: 'paused');

  bool get isIdle => type == 'idle';
  bool get isReady => type == 'ready';
  bool get isWaiting => type == 'waiting';
  bool get isSyncing => type == 'syncing';
  bool get isCompleted => type == 'completed';
  bool get isError => type == 'error';
  bool get isPaused => type == 'paused';
}
