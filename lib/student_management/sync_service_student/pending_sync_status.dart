// reusable_codes/pending_sync_badge.dart
import 'package:flutter/material.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/student_management/sync_service_student/sync_service_student.dart';

class PendingSyncBadge extends StatefulWidget {
  const PendingSyncBadge({super.key});

  @override
  _PendingSyncBadgeState createState() => _PendingSyncBadgeState();
}

class _PendingSyncBadgeState extends State<PendingSyncBadge> {
  int _pendingCount = 0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    final role = await getDeviceRole();
    if (role != DeviceRole.client) {
      setState(() => _pendingCount = 0);
      return;
    }

    final count = await StudentSyncService().getPendingQueueSize();
    setState(() => _pendingCount = count);
  }

  Future<void> _processPendingSync() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final results = await StudentSyncService().processPendingQueue();

      if (results['total'] > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '📦 Synced ${results['synced']}/${results['total']} pending students',
            ),
            backgroundColor:
                results['failed'] > 0 ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        if (results['failed'] > 0) {
          // Show details of failed syncs
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('⚠️ Partial Sync'),
              content: Text(
                '${results['synced']} students synced successfully.\n'
                '${results['failed']} students failed to sync.\n\n'
                'Failed IDs: ${results['failedIds'].join(', ')}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }

        await _loadPendingCount();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Error processing sync: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingCount == 0) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: _processPendingSync,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.shade700,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isProcessing ? Icons.sync : Icons.cloud_off,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              _isProcessing ? 'Syncing...' : '$_pendingCount pending',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
