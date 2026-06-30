// services/student_sync_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/server/routes/student_factory.dart';
import 'package:zitf_system/reusable_codes/serializers/students_serializer.dart';
import 'package:zitf_system/student_management/add_student_from_client.dart';

class StudentSyncService {
  static final StudentSyncService _instance = StudentSyncService._internal();
  factory StudentSyncService() => _instance;
  StudentSyncService._internal();

  // Queue for pending student creations (client mode)
  static const String _pendingStudentsKey = 'pending_students';
  static const String _syncRetryCountKey = 'sync_retry_count';

  /// Save student locally (HOST mode only)
  Future<bool> saveStudentLocally(Student student) async {
    try {
      final box = await Hive.openBox<Student>('students');
      await box.add(student);
      await box.close();
      print('✅ Student saved locally (HOST mode)');
      return true;
    } catch (e) {
      print('❌ Failed to save student locally: $e');
      return false;
    }
  }

  /// Sync student to host (CLIENT mode)
  Future<SyncResult> syncStudentToHost(Student student) async {
    try {
      print('🔄 Syncing student to host...');

      // Get host IP
      final prefs = await SharedPreferences.getInstance();
      final hostIp = prefs.getString('host_ip');

      if (hostIp == null || hostIp.isEmpty) {
        return SyncResult(
          success: false,
          message: 'Host IP not configured',
          error: 'NO_HOST_IP',
        );
      }

      // Check host reachability
      final reachable = await _isHostReachable(hostIp);
      if (!reachable) {
        // Queue for later sync
        await _queueStudentForSync(student);
        return SyncResult(
          success: false,
          message: 'Host unreachable - Student queued for later sync',
          error: 'HOST_UNREACHABLE',
          queued: true,
        );
      }

      // Send to host
      final response = await StudentApiService.sendStudents([
        studentsToJson(student),
      ]);

      if (response['insertedStudents'] != null &&
          response['insertedStudents'].isNotEmpty) {
        print('✅ Student synced to host successfully');
        return SyncResult(
          success: true,
          message: 'Student synced to host successfully',
          data: response,
        );
      } else {
        // If host returns but no data, queue it
        await _queueStudentForSync(student);
        return SyncResult(
          success: false,
          message: 'Host response invalid - Student queued',
          error: 'INVALID_RESPONSE',
          queued: true,
        );
      }
    } catch (e) {
      print('❌ Student sync failed: $e');
      // Queue for later sync
      await _queueStudentForSync(student);
      return SyncResult(
        success: false,
        message: 'Sync failed: $e',
        error: e.toString(),
        queued: true,
      );
    }
  }

  /// Queue student for later sync (offline mode)
  Future<void> _queueStudentForSync(Student student) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingStudentsJson =
          prefs.getStringList(_pendingStudentsKey) ?? [];

      // Convert student to JSON and add to queue
      final studentJson = studentsToJson(student);
      pendingStudentsJson.add(jsonEncode(studentJson));

      await prefs.setStringList(_pendingStudentsKey, pendingStudentsJson);
      print(
          '📦 Student queued for later sync (Queue size: ${pendingStudentsJson.length})');
    } catch (e) {
      print('❌ Failed to queue student: $e');
    }
  }

  /// Process pending students queue
  Future<Map<String, dynamic>> processPendingQueue() async {
    final results = {
      'total': 0,
      'synced': 0,
      'failed': 0,
      'failedIds': <String>[],
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingJson = prefs.getStringList(_pendingStudentsKey) ?? [];

      if (pendingJson.isEmpty) {
        print('📦 No pending students to sync');
        return results;
      }

      print('📦 Processing ${pendingJson.length} pending students...');

      final hostIp = prefs.getString('host_ip');
      if (hostIp == null || hostIp.isEmpty) {
        print('❌ Host IP not configured - cannot process queue');
        return results;
      }

      // Check host reachability
      final reachable = await _isHostReachable(hostIp);
      if (!reachable) {
        print('⚠️ Host unreachable - skipping queue processing');
        return results;
      }

      results['total'] = pendingJson.length;

      // Process all pending students
      for (var jsonString in pendingJson) {
        try {
          final studentMap = jsonDecode(jsonString);
          final student = Student.fromJson(studentMap);

          final response = await StudentApiService.sendStudents([studentMap]);

          if (response['insertedStudents'] != null &&
              response['insertedStudents'].isNotEmpty) {
            results['synced']++;
            print(
                '✅ Synced pending student: ${student.name} ${student.surname}');
          } else {
            results['failed']++;
            results['failedIds'].add(student.id?.toString() ?? 'unknown');
            print(
                '❌ Failed to sync pending student: ${student.name} ${student.surname}');
          }
        } catch (e) {
          results['failed']++;
          print('❌ Error processing pending student: $e');
        }
      }

      // Clear successful syncs from queue
      if (results['failed'] == 0) {
        await prefs.remove(_pendingStudentsKey);
        print('✅ All pending students synced - Queue cleared');
      } else {
        // Keep failed items in queue
        final remaining = pendingJson.length - results['synced'];
        print('⚠️ $remaining students still pending');
      }

      return results;
    } catch (e) {
      print('❌ Failed to process pending queue: $e');
      return results;
    }
  }

  /// Get pending queue size
  Future<int> getPendingQueueSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList(_pendingStudentsKey) ?? [];
      return pending.length;
    } catch (e) {
      return 0;
    }
  }

  /// Check if host is reachable
  Future<bool> _isHostReachable(String hostIp) async {
    try {
      // Try to reach the health endpoint
      final url = Uri.parse('http://$hostIp:8080/api/health');
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);

      final request = await client.getUrl(url);
      final response = await request.close();

      return response.statusCode == 200;
    } catch (e) {
      print('⚠️ Host reachability check failed: $e');
      return false;
    }
  }

  /// Clear pending queue
  Future<void> clearPendingQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingStudentsKey);
      print('🗑️ Pending queue cleared');
    } catch (e) {
      print('❌ Failed to clear pending queue: $e');
    }
  }
}

class SyncResult {
  final bool success;
  final String message;
  final String? error;
  final bool queued;
  final dynamic data;

  SyncResult({
    required this.success,
    required this.message,
    this.error,
    this.queued = false,
    this.data,
  });
}
