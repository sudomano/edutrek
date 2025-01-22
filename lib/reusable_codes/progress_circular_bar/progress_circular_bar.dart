import 'package:flutter/material.dart';

class SyncManager {
  static bool _isSyncing = false;

  static bool get isSyncing => _isSyncing;

  static void startSyncing(BuildContext context) {
    if (_isSyncing) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sync is already in progress. Please wait.'),
      ));
      return;
    }
    _isSyncing = true;
  }

  static void stopSyncing() {
    _isSyncing = false;
  }

  static void handleSyncError(BuildContext context, String errorMessage) {
    _isSyncing = false;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Error during sync: $errorMessage'),
    ));
  }
}
