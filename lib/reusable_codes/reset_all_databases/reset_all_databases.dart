import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

Future<void> resetAppHiveData(BuildContext context) async {
  bool confirmed = await _showConfirmationDialog(context);
  if (!confirmed) {
    return;
  }

  // List of all your Hive boxes
  final boxNames = [
    'domainBox',
    'teacher_payments_purposes',
    'payment_purposes',
    'classes',
    'student_payments',
    'teacher_payments',
    'students',
    'withdrawals',
    'users',
    'teachers',
    'school',
    'terms',
    'account',
    'asset',
    'projects',
    'projectItems',
    'dailyActivities',
    'projectStudentPayments',
    'exceptionalStudentsBox',
  ];

  try {
    // 1️⃣ Close and delete all boxes
    for (var boxName in boxNames) {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).close();
      }
      await Hive.deleteBoxFromDisk(boxName);
      debugPrint('✅ Deleted Hive box: $boxName');
    }

    // 2️⃣ Delete leftover .hive and .lock files
    final dir = await getApplicationDocumentsDirectory();
    for (var entity in dir.listSync()) {
      if (entity.path.endsWith('.hive') || entity.path.endsWith('.lock')) {
        try {
          await entity.delete();
          debugPrint('✅ Deleted Hive file: ${entity.path}');
        } catch (e) {
          debugPrint('❌ Failed to delete ${entity.path}: $e');
        }
      }
    }

    debugPrint('🎉 All Hive data reset successfully!');
  } catch (e) {
    debugPrint('❌ Failed to reset Hive data: $e');
  }
}

Future<bool> _showConfirmationDialog(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Reset'),
          content: const Text(
              'Are you sure you want to delete all app data? This action is irreversible and will remove all records.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reset'),
            ),
          ],
        ),
      ) ??
      false;
}
