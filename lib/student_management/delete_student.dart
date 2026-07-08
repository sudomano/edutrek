import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import '../database/student.dart';
import '../database/student_payments.dart';

class DeleteStudentScreen extends StatefulWidget {
  const DeleteStudentScreen({super.key});

  @override
  _DeleteStudentScreenState createState() => _DeleteStudentScreenState();
}

class _DeleteStudentScreenState extends State<DeleteStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _indexController = TextEditingController();
  List<Student> _foundStudents = [];
  bool _isLoading = false;

  // =========================================================================
  // 1. SEARCH STUDENTS (Only Active)
  // =========================================================================
  void _searchStudent() async {
    if (_indexController.text.isEmpty) {
      _showDialog('Please enter a surname to search.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final box = await Hive.openBox<Student>('students');

      // ✅ ONLY SEARCH ACTIVE (NON-DELETED) STUDENTS
      final activeStudents =
          box.values.where((s) => !(s.isDeleted ?? false)).toList();

      final searchTerm = _indexController.text.toLowerCase().trim();

      final matchedStudents = activeStudents
          .where((student) =>
              student.surname.toLowerCase().contains(searchTerm) ||
              student.name.toLowerCase().contains(searchTerm) ||
              student.studentIdNumber?.toLowerCase().contains(searchTerm) ==
                  true ||
              student.regNumber.toLowerCase().contains(searchTerm))
          .toList();

      // Sort by surname
      matchedStudents.sort((a, b) => a.surname.compareTo(b.surname));

      setState(() {
        _foundStudents = matchedStudents;
        _isLoading = false;
      });

      if (matchedStudents.isEmpty) {
        _showDialog('No active students found matching "$searchTerm"');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showDialog('Error searching students: $e');
    }
  }

  // =========================================================================
  // 2. SOFT DELETE STUDENT (Ready for Sync)
  // =========================================================================
  void _deleteStudent(Student studentToDelete) async {
    // Confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
          'Are you sure you want to soft-delete:\n\n'
          'Name: ${studentToDelete.name} ${studentToDelete.surname}\n'
          'ID: ${studentToDelete.studentIdNumber ?? 'N/A'}\n'
          'Class: ${studentToDelete.class_}\n\n'
          'This student will be marked as deleted and synced to host.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final studentsBox = await Hive.openBox<Student>('students');
      final studentPaymentsBox =
          await Hive.openBox<StudentPayment>('student_payments');

      // ✅ Step 1: Get the key for the student
      final studentKey = studentsBox.keys.firstWhere(
        (k) {
          final student = studentsBox.get(k);
          return student?.id == studentToDelete.id;
        },
        orElse: () => throw Exception('Student not found in Hive'),
      );

      // ✅ Step 2: Retrieve the current student
      final currentStudent = studentsBox.get(studentKey);

      if (currentStudent == null) {
        throw Exception('Student data is null');
      }

      // ✅ Step 3: Mark as SOFT DELETED with all sync flags
      currentStudent.markDeleted(
        deletedBy: 'User: ${currentStudent.name} ${currentStudent.surname}',
        reason: 'Deleted from DeleteStudentScreen',
      );

      // ✅ Ensure all sync flags are properly set
      currentStudent.syncStatus = false; // ⭐ Needs sync
      currentStudent.deletedSyncStatus = false; // ⭐ Deletion needs sync
      currentStudent.operationType = 'delete'; // ⭐ Operation type
      currentStudent.lastModified = DateTime.now(); // ⭐ Timestamp

      // ✅ Step 4: Save the updated (soft-deleted) student
      await studentsBox.put(studentKey, currentStudent);

      // ✅ Step 5: SOFT DELETE related payment records
      final paymentsToDelete = studentPaymentsBox.values
          .where((payment) =>
              payment.studentName.toLowerCase() ==
                  currentStudent.name.toLowerCase() &&
              payment.studentSurname.toLowerCase() ==
                  currentStudent.surname.toLowerCase() &&
              payment.studentClass.toLowerCase() ==
                  currentStudent.class_.toLowerCase())
          .toList();

      for (var payment in paymentsToDelete) {
        try {
          final paymentKey = studentPaymentsBox.keys.firstWhere(
            (k) {
              final p = studentPaymentsBox.get(k);
              return p?.id == payment.id;
            },
            orElse: () => throw Exception('Payment not found'),
          );

          // ✅ Update payment with deletion flags
          final updatedPayment = payment.copyWith(
            syncStatus: false, // ⭐ Needs sync
            lastModified: DateTime.now(), // ⭐ Timestamp
            operationType: 'delete', // ⭐ Operation type
          );

          // If StudentPayment has isDeleted field, add it
          // updatedPayment.isDeleted = true;
          // updatedPayment.deletedSyncStatus = false;

          await studentPaymentsBox.put(paymentKey, updatedPayment);
        } catch (e) {
          debugPrint('Error soft-deleting payment: $e');
          // Continue with other payments
        }
      }

      _showDialog(
        '✅ Student soft-deleted successfully!\n\n'
        'Student: ${currentStudent.name} ${currentStudent.surname}\n'
        'ID: ${currentStudent.studentIdNumber ?? 'N/A'}\n'
        'Class: ${currentStudent.class_}\n\n'
        '📤 Ready to sync to host when online.\n'
        '⏰ Deleted at: ${currentStudent.deletedAt!.toLocal()}',
      );

      // ✅ Remove from UI list
      setState(() {
        _foundStudents.remove(studentToDelete);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showDialog('❌ Error soft-deleting student:\n$e');
      debugPrint('Error in _deleteStudent: $e');
    }
  }

  // =========================================================================
  // 3. BULK SOFT DELETE ALL STUDENTS (Ready for Sync)
  // =========================================================================
  void _confirmDeleteAllStudents() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Delete All Students'),
        content: const Text(
          'Are you sure you want to soft-delete ALL active students?\n\n'
          'This will:\n'
          '• Mark all active students as deleted\n'
          '• Mark their payments as deleted\n'
          '• Set sync flags for host synchronization\n\n'
          'This action can be reversed by restoring students.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteAllStudents();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  void _deleteAllStudents() async {
    setState(() => _isLoading = true);

    try {
      final studentsBox = await Hive.openBox<Student>('students');
      final studentPaymentsBox =
          await Hive.openBox<StudentPayment>('student_payments');

      // ✅ Only get ACTIVE (non-deleted) students
      final studentsToDelete = studentsBox.values
          .where((s) => !(s.isDeleted ?? false))
          .cast<Student>()
          .toList();

      if (studentsToDelete.isEmpty) {
        setState(() => _isLoading = false);
        _showDialog('No active students to delete.');
        return;
      }

      int deletedCount = 0;
      int paymentCount = 0;

      for (var student in studentsToDelete) {
        try {
          // ✅ Get the key for this student
          final studentKey = studentsBox.keys.firstWhere(
            (k) {
              final s = studentsBox.get(k);
              return s?.id == student.id;
            },
            orElse: () => throw Exception('Student not found'),
          );

          // ✅ Mark as SOFT DELETED with sync flags
          student.markDeleted(
            deletedBy: 'System - Bulk Delete',
            reason: 'Bulk delete all active students',
          );

          // ✅ Ensure all sync flags are set
          student.syncStatus = false;
          student.deletedSyncStatus = false;
          student.operationType = 'delete';
          student.lastModified = DateTime.now();

          await studentsBox.put(studentKey, student);

          // ✅ Soft delete related payment records
          final paymentsToDelete = studentPaymentsBox.values
              .where((payment) =>
                  payment.studentName.toLowerCase() ==
                      student.name.toLowerCase() &&
                  payment.studentSurname.toLowerCase() ==
                      student.surname.toLowerCase() &&
                  payment.studentClass.toLowerCase() ==
                      student.class_.toLowerCase())
              .toList();

          for (var payment in paymentsToDelete) {
            try {
              final paymentKey = studentPaymentsBox.keys.firstWhere(
                (k) {
                  final p = studentPaymentsBox.get(k);
                  return p?.id == payment.id;
                },
                orElse: () => throw Exception('Payment not found'),
              );

              final updatedPayment = payment.copyWith(
                syncStatus: false,
                lastModified: DateTime.now(),
                operationType: 'delete',
              );

              await studentPaymentsBox.put(paymentKey, updatedPayment);
              paymentCount++;
            } catch (e) {
              debugPrint('Error soft-deleting payment: $e');
            }
          }

          deletedCount++;
        } catch (e) {
          debugPrint('Error deleting student ${student.id}: $e');
        }
      }

      _showDialog(
        '✅ Bulk soft-delete completed!\n\n'
        '📊 Students deleted: $deletedCount\n'
        '📊 Payments marked: $paymentCount\n\n'
        '📤 All records are ready to sync to host when online.',
      );

      setState(() {
        _foundStudents.clear();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showDialog('❌ Error during bulk delete:\n$e');
      debugPrint('Error in _deleteAllStudents: $e');
    }
  }

  // =========================================================================
  // 4. RESTORE STUDENT (Ready for Sync)
  // =========================================================================
  void _restoreStudent(Student studentToRestore) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Restore'),
        content: Text(
          'Restore student:\n\n'
          'Name: ${studentToRestore.name} ${studentToRestore.surname}\n'
          'ID: ${studentToRestore.studentIdNumber ?? 'N/A'}\n'
          'Deleted: ${studentToRestore.deletedAt?.toLocal() ?? 'Unknown'}\n\n'
          'This will restore the student and mark for sync.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final studentsBox = await Hive.openBox<Student>('students');
      final studentPaymentsBox =
          await Hive.openBox<StudentPayment>('student_payments');

      final studentKey = studentsBox.keys.firstWhere(
        (k) {
          final s = studentsBox.get(k);
          return s?.id == studentToRestore.id;
        },
        orElse: () => throw Exception('Student not found'),
      );

      final currentStudent = studentsBox.get(studentKey);

      if (currentStudent != null && (currentStudent.isDeleted ?? false)) {
        // ✅ Restore the student (sets sync flags)
        currentStudent.restoreDeleted();

        // ✅ Ensure sync flags are set
        currentStudent.syncStatus = false; // ⭐ Needs sync
        currentStudent.deletedSyncStatus = false; // ⭐ Restoration needs sync
        currentStudent.operationType = 'update'; // ⭐ Operation type
        currentStudent.lastModified = DateTime.now(); // ⭐ Timestamp

        // ✅ Restore related payments
        final paymentsToRestore = studentPaymentsBox.values
            .where((payment) =>
                payment.studentName.toLowerCase() ==
                    currentStudent.name.toLowerCase() &&
                payment.studentSurname.toLowerCase() ==
                    currentStudent.surname.toLowerCase() &&
                payment.studentClass.toLowerCase() ==
                    currentStudent.class_.toLowerCase())
            .toList();

        for (var payment in paymentsToRestore) {
          try {
            final paymentKey = studentPaymentsBox.keys.firstWhere(
              (k) {
                final p = studentPaymentsBox.get(k);
                return p?.id == payment.id;
              },
              orElse: () => throw Exception('Payment not found'),
            );

            final updatedPayment = payment.copyWith(
              syncStatus: false,
              lastModified: DateTime.now(),
              operationType: 'update',
            );

            await studentPaymentsBox.put(paymentKey, updatedPayment);
          } catch (e) {
            debugPrint('Error restoring payment: $e');
          }
        }

        await studentsBox.put(studentKey, currentStudent);

        _showDialog(
          '✅ Student restored successfully!\n\n'
          'Student: ${currentStudent.name} ${currentStudent.surname}\n'
          'ID: ${currentStudent.studentIdNumber ?? 'N/A'}\n\n'
          '📤 Ready to sync restoration to host when online.',
        );

        // ✅ Refresh the list
        setState(() {
          _foundStudents.remove(studentToRestore);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showDialog('Student is not deleted or not found.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showDialog('❌ Error restoring student:\n$e');
      debugPrint('Error in _restoreStudent: $e');
    }
  }

  // =========================================================================
  // 5. VIEW DELETED STUDENTS
  // =========================================================================
  void _viewDeletedStudents() async {
    try {
      final box = await Hive.openBox<Student>('students');
      final deletedStudents =
          box.values.where((s) => (s.isDeleted ?? false)).toList();

      if (deletedStudents.isEmpty) {
        _showDialog('No deleted students found.');
        return;
      }

      // Sort by deletion date (most recent first)
      deletedStudents.sort((a, b) => (b.deletedAt ?? DateTime(1970))
          .compareTo(a.deletedAt ?? DateTime(1970)));

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.delete, color: Colors.red),
              const SizedBox(width: 8),
              Text('Deleted Students (${deletedStudents.length})'),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: deletedStudents.length,
              itemBuilder: (context, index) {
                final student = deletedStudents[index];
                final isDeleted = student.isDeleted ?? false;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(
                      '${student.name} ${student.surname}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID: ${student.studentIdNumber ?? 'N/A'}'),
                        Text('Class: ${student.class_}'),
                        Text(
                          'Deleted: ${student.deletedAt?.toLocal() ?? 'Unknown'}',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.red),
                        ),
                        if (student.deleteReason != null)
                          Text(
                            'Reason: ${student.deleteReason}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.restore, color: Colors.green),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _restoreStudent(student);
                      },
                      tooltip: 'Restore Student',
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showDialog('Error loading deleted students: $e');
    }
  }

  // =========================================================================
  // 6. HELPER: Show Dialog
  // =========================================================================
  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🧾 Student Management"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 7. BUILD UI
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text(
            'Delete Student',
            style: TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.normal,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
        actions: [
          // ✅ View deleted students
          IconButton(
            icon: const Icon(Icons.restore_page, color: Colors.amber),
            onPressed: _viewDeletedStudents,
            tooltip: 'View Deleted Students',
          ),
          // ✅ Delete All
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            onPressed: _confirmDeleteAllStudents,
            tooltip: 'Delete All Students',
          ),
        ],
        backgroundColor: const Color.fromARGB(255, 38, 140, 191),
        elevation: 4.0,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing...', style: TextStyle(fontSize: 16)),
                ],
              ),
            )
          : Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _indexController,
                          decoration: InputDecoration(
                            labelText: 'Enter Name or Surname to Search',
                            hintText: 'e.g. John, Smith, 2024-001',
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.search),
                          ),
                          textInputAction: TextInputAction.search,
                          onFieldSubmitted: (_) => _searchStudent(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a surname or name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: ElevatedButton(
                            onPressed: _searchStudent,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 16,
                              ),
                              textStyle: const TextStyle(fontSize: 18),
                            ),
                            child: const Text('Search'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_foundStudents.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Found ${_foundStudents.length} active student(s)',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _foundStudents.length,
                              itemBuilder: (context, index) {
                                final foundStudent = _foundStudents[index];
                                final isDeleted =
                                    foundStudent.isDeleted ?? false;

                                return Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  elevation: 5,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${foundStudent.name} ${foundStudent.surname}',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                'Class: ${foundStudent.class_}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isDeleted)
                                          const Chip(
                                            label: Text('DELETED'),
                                            backgroundColor: Colors.red,
                                            labelStyle: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Reg: ${foundStudent.regNumber}',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        Text(
                                          'ID: ${foundStudent.studentIdNumber ?? 'N/A'}',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        if (foundStudent.deletedAt != null)
                                          Text(
                                            'Deleted: ${foundStudent.deletedAt!.toLocal()}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.red,
                                            ),
                                          ),
                                        if (foundStudent.syncStatus == false &&
                                            foundStudent.isDeleted == true)
                                          const Text(
                                            '⏳ Awaiting sync to host',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange,
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // ✅ Option to restore if deleted
                                        if (isDeleted)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.restore,
                                              color: Colors.green,
                                            ),
                                            onPressed: () =>
                                                _restoreStudent(foundStudent),
                                            tooltip: 'Restore Student',
                                          ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete,
                                            color: isDeleted
                                                ? Colors.grey
                                                : Colors.red,
                                          ),
                                          onPressed: isDeleted
                                              ? null
                                              : () =>
                                                  _deleteStudent(foundStudent),
                                          tooltip: 'Soft Delete Student',
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _indexController.dispose();
    super.dispose();
  }
}
