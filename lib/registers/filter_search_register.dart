import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';
import 'package:zitf_system/student_management/fetch_student_register_api.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path/path.dart' as path;
import 'package:zitf_system/pdf_global_codes/pdf_preview_util.dart';

class ViewAttendanceScreenFilter extends StatefulWidget {
  @override
  _ViewAttendanceScreenFilterState createState() =>
      _ViewAttendanceScreenFilterState();
}

class _ViewAttendanceScreenFilterState
    extends State<ViewAttendanceScreenFilter> {
  List<Student> _allStudents = [];
  List<Student> _filteredStudents = [];
  List<String> _classes = [];
  String? _selectedClass = "All";
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  String? _selectedStudentName;
  bool _isSortAscending = true;
  bool _isLoading = true;

  // ✅ Cache for students fetched from server
  List<Student>? _cachedStudents;
  bool _isSyncing = false;

  // ✅ User role info
  User? _loggedInUser;
  bool _isAdmin = false;
  bool _isTeacher = false;
  List<String> _teacherClasses = [];
  bool _isHost = false; // ✅ Add this

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadDeviceRole(); // ✅ Add this

    await _loadLoggedInUser();
    await _loadStudents();
    _applyFilters();
    setState(() => _isLoading = false);
  }

// ✅ Add this method
  Future<void> _loadDeviceRole() async {
    final role = await getDeviceRole();
    _isHost = role == DeviceRole.host;
    debugPrint('🖥 Device Role: ${_isHost ? "Host" : "Client"}');
  }

  // ✅ Load logged in user and determine permissions
  Future<void> _loadLoggedInUser() async {
    try {
      _loggedInUser = await getLoggedInUser();

      if (_loggedInUser != null) {
        final role = _loggedInUser!.role.toLowerCase();
        _isAdmin = role == 'admin' || role == 'administration';
        _isTeacher = role == 'teacher';
        _teacherClasses = _loggedInUser!.assignedClasses ?? [];

        debugPrint('👤 Logged in user: ${_loggedInUser!.username}');
        debugPrint('📋 Role: ${_loggedInUser!.role}');
        debugPrint('📚 Assigned classes from local storage: $_teacherClasses');
        debugPrint('🔑 Is Admin: $_isAdmin');
        debugPrint('👨‍🏫 Is Teacher: $_isTeacher');
      }
    } catch (e) {
      debugPrint('❌ Error loading logged in user: $e');
      // Try fallback: get from preferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final username = prefs.getString('logged_in_username');
        final role = prefs.getString('logged_in_role') ?? '';
        final assignedClasses =
            prefs.getStringList('logged_in_assigned_classes') ?? [];

        _loggedInUser = User(
          username: username ?? '',
          password: '',
          role: role,
          securityQuestions: [],
          securityAnswers: [],
          phone: '',
          email: '',
          assignedClasses: assignedClasses,
          isActive: true,
        );

        _isAdmin = role == 'admin' || role == 'administration';
        _isTeacher = role == 'teacher';
        _teacherClasses = assignedClasses;

        debugPrint('👤 Fallback: Loaded user from preferences');
        debugPrint('📚 Assigned classes from preferences: $_teacherClasses');
      } catch (e2) {
        debugPrint('❌ Error loading user from preferences: $e2');
      }
    }
  }

  Future<void> _loadStudents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = await getDeviceRole();

      if (role == DeviceRole.host) {
        // ✅ HOST: Load from Hive
        final studentBox = await Hive.openBox<Student>('students');
        _allStudents = studentBox.values
            .where((student) =>
                student.terms != null && student.terms!.contains(globalTermId))
            .toList();
        debugPrint(
            '📊 Host - Loaded ${_allStudents.length} students from Hive');
      } else {
        // ✅ CLIENT: Fetch from server using /all endpoint and cache
        setState(() => _isSyncing = true);

        try {
          final allStudents = await StudentRegisterFetchApi.fetchAllStudents();
          _cachedStudents = allStudents;

          // Filter for current term
          _allStudents = allStudents
              .where((student) =>
                  student.terms != null &&
                  student.terms!.contains(globalTermId))
              .toList();

          debugPrint(
              '📊 Client - Fetched ${allStudents.length} students from server, ${_allStudents.length} in current term');
        } catch (e) {
          debugPrint('❌ Error fetching students from server: $e');
          _allStudents = [];
        } finally {
          setState(() => _isSyncing = false);
        }
      }

      // ✅ Get all distinct classes from students
      final allClasses = _allStudents.map((s) => s.class_).toSet().toList();
      debugPrint('📊 All classes from students: $allClasses');

      // ✅ Apply role-based filtering for classes
      if (_isAdmin) {
        // ✅ Admin: See ALL classes
        _classes = ['All', ...allClasses];
        debugPrint('🔑 Admin - Showing all ${_classes.length} classes');
      } else if (_isTeacher) {
        // ✅ Teacher: Only see assigned classes (case-insensitive)
        final normalizedTeacherClasses =
            _teacherClasses.map((c) => c.toLowerCase()).toList();
        final filteredClasses = allClasses.where((className) {
          return normalizedTeacherClasses.contains(className.toLowerCase());
        }).toList();

        _classes = ['All', ...filteredClasses];
        debugPrint('👨‍🏫 Teacher - Showing ${_classes.length} classes');
        debugPrint('📚 Assigned classes: $_teacherClasses');

        if (_classes.length == 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'ℹ️ No students found in your assigned classes for the current term.',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          });
        }
      } else {
        // ✅ Other roles: No class access
        _classes = ['All'];
        debugPrint('👤 ${_loggedInUser?.role} - No class access');
      }

      // ✅ Set default selected class
      _selectedClass = "All";
      debugPrint('📋 Default selected class: $_selectedClass');
    } catch (e) {
      debugPrint('❌ Error loading students: $e');
      _allStudents = [];
      _classes = ['All'];
      _selectedClass = "All";
    }
  }

  void _applyFilters() {
    List<Student> filtered = List.from(_allStudents);

    // ✅ Apply class filter (case-insensitive)
    if (_selectedClass != null && _selectedClass != "All") {
      final normalizedSelected = _selectedClass!.toLowerCase();
      filtered = filtered.where((student) {
        return student.class_.toLowerCase() == normalizedSelected;
      }).toList();
    } else if (_isTeacher && !_isAdmin) {
      // ✅ Teacher with "All" selected: Show only their assigned classes
      final normalizedTeacherClasses =
          _teacherClasses.map((c) => c.toLowerCase()).toList();
      filtered = filtered.where((student) {
        return normalizedTeacherClasses.contains(student.class_.toLowerCase());
      }).toList();
    }

    // ✅ Apply date range filter
    if (_selectedStartDate != null && _selectedEndDate != null) {
      final startDate = _selectedStartDate!;
      final endDate = _selectedEndDate!.add(const Duration(days: 1));

      filtered = filtered.where((student) {
        final allDates = [...student.presentDates, ...student.absentDates];
        return allDates.any((date) {
          return date.isAfter(startDate) && date.isBefore(endDate);
        });
      }).toList();
    }

    // ✅ Apply student name search
    if (_selectedStudentName != null && _selectedStudentName!.isNotEmpty) {
      final searchQuery = _selectedStudentName!.toLowerCase();
      filtered = filtered.where((student) {
        final fullName = '${student.name} ${student.surname}'.toLowerCase();
        return fullName.contains(searchQuery);
      }).toList();
    }

    // ✅ Group by class alphabetically, then by surname alphabetically
    filtered.sort((a, b) {
      final classCompare = a.class_.compareTo(b.class_);
      if (classCompare != 0) return classCompare;
      return a.surname.compareTo(b.surname);
    });

    setState(() {
      _filteredStudents = filtered;
    });
  }

  void _toggleSortOrder() {
    setState(() {
      _isSortAscending = !_isSortAscending;
      _applyFilters();
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedClass = "All";
      _selectedStartDate = null;
      _selectedEndDate = null;
      _selectedStudentName = null;
    });
    _applyFilters();
  }

  // ✅ Manual sync students from host
  Future<void> _syncStudents() async {
    setState(() => _isSyncing = true);

    try {
      final allStudents = await StudentRegisterFetchApi.fetchAllStudents();
      _cachedStudents = allStudents;

      // Filter for current term
      _allStudents = allStudents
          .where((student) =>
              student.terms != null && student.terms!.contains(globalTermId))
          .toList();

      // ✅ Rebuild classes list
      final allClasses = _allStudents.map((s) => s.class_).toSet().toList();

      if (_isAdmin) {
        _classes = ['All', ...allClasses];
      } else if (_isTeacher) {
        final normalizedTeacherClasses =
            _teacherClasses.map((c) => c.toLowerCase()).toList();
        final filteredClasses = allClasses.where((className) {
          return normalizedTeacherClasses.contains(className.toLowerCase());
        }).toList();
        _classes = ['All', ...filteredClasses];
      } else {
        _classes = ['All'];
      }

      _applyFilters();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Synced ${_allStudents.length} students from host'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('❌ Error syncing students: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to sync students: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  void _deleteAllAttendanceForClass(String className) {
    // ✅ Only Host Admin can delete
    if (!_isHost || !_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('❌ Only Host Administrators can delete attendance records.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Attendance'),
        content: Text(
            'Are you sure you want to delete all attendance records for class "$className"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDeleteClassAttendance(className);
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteClassAttendance(String className) {
    // Find students in this class
    final students = _allStudents.where((s) => s.class_ == className).toList();

    // Clear attendance for each student
    for (var student in students) {
      student.presentDates.clear();
      student.absentDates.clear();
      student.save();
    }

    // Refresh data
    _loadStudents();
    _applyFilters();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '✅ Deleted attendance for ${students.length} students in $className'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _deleteStudentAttendanceHistory(Student student) {
    // ✅ Only Host Admin can delete
    if (!_isHost || !_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('❌ Only Host Administrators can delete attendance records.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Student Attendance'),
        content: Text(
            'Are you sure you want to delete all attendance records for ${student.name} ${student.surname}?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDeleteStudentAttendance(student);
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteStudentAttendance(Student student) {
    student.presentDates.clear();
    student.absentDates.clear();
    student.save();
    _loadStudents();
    _applyFilters();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('✅ Deleted attendance for ${student.name} ${student.surname}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<Uint8List> generateStudentsPDF() async {
    final pdf = pw.Document();

    final headers = [
      'Class',
      'Student Name',
      'Surname',
      'Total Days',
      'Present',
      'Absent',
      'Attendance %',
      'Term'
    ];

    final data = _filteredStudents.map((student) {
      int totalDays = student.presentDates.length + student.absentDates.length;
      int presentDays = student.presentDates.length;
      int absentDays = student.absentDates.length;
      double attendancePercentage =
          totalDays > 0 ? (presentDays / totalDays) * 100 : 0;

      return [
        student.class_,
        student.name,
        student.surname,
        '$totalDays',
        '$presentDays',
        '$absentDays',
        '${attendancePercentage.toStringAsFixed(2)}%',
        student.termId ?? 'N/A',
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Attendance Report',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 16),
              ],
            ),
            pw.Table.fromTextArray(
              headers: headers,
              data: data,
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerStyle: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              border: pw.TableBorder.all(color: PdfColors.black),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1),
                5: const pw.FlexColumnWidth(1),
                6: const pw.FlexColumnWidth(1),
                7: const pw.FlexColumnWidth(1.5),
              },
            ),
          ];
        },
      ),
    );
    return pdf.save();
  }

  Future<void> savePDFToFile(
      BuildContext context, Uint8List pdfBytes, String fileName) async {
    try {
      if (await Permission.storage.request().isGranted) {
        final downloadDir = Directory('/storage/emulated/0/Download');

        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }

        String filePath = path.join(downloadDir.path, '$fileName.pdf');
        int fileIndex = 1;

        while (await File(filePath).exists()) {
          filePath = path.join(downloadDir.path, '$fileName-$fileIndex.pdf');
          fileIndex++;
        }

        final file = File(filePath);
        await file.writeAsBytes(pdfBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("✅ PDF saved to $filePath")),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Permission denied for storage access.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving PDF: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasClassAccess = _isAdmin || (_isTeacher && _classes.length > 1);

    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text(
            'View Attendance',
            style: TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.normal,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
        actions: [
          // ✅ Sync button (for client)
          IconButton(
            onPressed: _syncStudents,
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync, color: Colors.white),
            tooltip: 'Sync Students from Host',
          ),
          // ✅ Filter button
          IconButton(
            onPressed: _showFilterOptions,
            icon: const Icon(Icons.filter_list, color: Colors.white),
            tooltip: 'Filter Options',
          ),
          // ✅ Reset filters button
          IconButton(
            onPressed: _resetFilters,
            icon: const Icon(Icons.clear_all, color: Colors.white),
            tooltip: 'Reset Filters',
          ),
          // ✅ PDF export button
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: _filteredStudents.isEmpty
                ? null
                : () async {
                    final pdfBytes = await generateStudentsPDF();
                    final confirmSave =
                        await PDFPreviewUtil.showPDFPreview(context, pdfBytes);
                    if (confirmSave) {
                      await savePDFToFile(
                          context, pdfBytes, 'attendance_report');
                    }
                  },
            tooltip: 'Export PDF',
          ),
          // ✅ Delete all attendance for class (Admin only)
          // ✅ Delete all attendance for class (Host Admin only)
          if (_isHost &&
              _isAdmin &&
              _selectedClass != null &&
              _selectedClass != "All")
            IconButton(
              onPressed: () => _deleteAllAttendanceForClass(_selectedClass!),
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: 'Delete All Attendance for Class',
            ),
        ],
        backgroundColor: const Color.fromARGB(255, 38, 140, 191),
        elevation: 4.0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1200),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ User Role Indicator
                    // In the User Role Indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: _isAdmin
                            ? Colors.blue.shade50
                            : _isTeacher
                                ? Colors.green.shade50
                                : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isAdmin
                              ? Colors.blue.shade300
                              : _isTeacher
                                  ? Colors.green.shade300
                                  : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isAdmin
                                ? Icons.admin_panel_settings
                                : _isTeacher
                                    ? Icons.school
                                    : Icons.person,
                            color: _isAdmin
                                ? Colors.blue.shade700
                                : _isTeacher
                                    ? Colors.green.shade700
                                    : Colors.grey.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isAdmin
                                  ? '🔑 Administrator - ${_isHost ? "Host" : "Client"} - All Classes'
                                  : _isTeacher
                                      ? '👨‍🏫 Teacher - ${_classes.length - 1} classes assigned'
                                      : '👤 ${_loggedInUser?.role ?? 'User'} - No Access',
                              style: TextStyle(
                                color: _isAdmin
                                    ? Colors.blue.shade700
                                    : _isTeacher
                                        ? Colors.green.shade700
                                        : Colors.grey.shade700,
                                fontSize: 14,
                                fontWeight: _isAdmin || _isTeacher
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ✅ Filter summary
                    if (_selectedClass != "All" ||
                        _selectedStartDate != null ||
                        _selectedEndDate != null ||
                        (_selectedStudentName != null &&
                            _selectedStudentName!.isNotEmpty))
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.filter_alt,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Filtered by: ${_getFilterSummary()}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (!hasClassAccess) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 48,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _isTeacher
                                  ? 'You have no classes assigned. Please contact the administrator.'
                                  : 'You do not have permission to view attendance.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.orange.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Only administrators and teachers with assigned classes can view attendance.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ] else if (_filteredStudents.isEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _isTeacher && _teacherClasses.isNotEmpty
                                  ? 'No students found for your assigned classes'
                                  : 'No attendance records found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isTeacher && _teacherClasses.isNotEmpty
                                  ? 'Your assigned classes: ${_teacherClasses.join(", ")}\nTap the sync button to download students from the host.'
                                  : _selectedClass != "All"
                                      ? 'No students have attendance records for the selected filters.'
                                      : 'No attendance records available for the current term.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_isTeacher && _teacherClasses.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _syncStudents,
                                icon: const Icon(Icons.sync),
                                label: const Text('Sync Students'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      // ✅ Summary stats
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('Total Students',
                                _filteredStudents.length, Colors.blue),
                            _buildStatItem(
                                'Total Present',
                                _filteredStudents.fold(
                                    0, (sum, s) => sum + s.presentDates.length),
                                Colors.green),
                            _buildStatItem(
                                'Total Absent',
                                _filteredStudents.fold(
                                    0, (sum, s) => sum + s.absentDates.length),
                                Colors.red),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ✅ Data Table with group headers
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: _buildGroupedDataTable(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildGroupedDataTable() {
    // ✅ Group students by class
    final Map<String, List<Student>> groupedStudents = {};
    for (var student in _filteredStudents) {
      if (!groupedStudents.containsKey(student.class_)) {
        groupedStudents[student.class_] = [];
      }
      groupedStudents[student.class_]!.add(student);
    }

    // ✅ Sort classes alphabetically
    final sortedClassNames = groupedStudents.keys.toList()..sort();

    // ✅ Build table with group headers
    return DataTable(
      headingRowColor: MaterialStateProperty.resolveWith(
        (states) => Colors.grey.shade200,
      ),
      columns: const [
        DataColumn(label: Text('Class')),
        DataColumn(label: Text('Name')),
        DataColumn(label: Text('Surname')),
        DataColumn(label: Text('Total Days')),
        DataColumn(label: Text('Present')),
        DataColumn(label: Text('Absent')),
        DataColumn(label: Text('Attendance %')),
        DataColumn(label: Text('Actions')),
      ],
      rows: sortedClassNames.expand((className) {
        final students = groupedStudents[className]!;
        final rows = <DataRow>[];

        // ✅ Add group header row (non-interactive)
        rows.add(
          DataRow(
            color: MaterialStateProperty.resolveWith(
              (states) => Colors.blue.shade50,
            ),
            cells: [
              DataCell(
                Text(
                  className,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blue,
                  ),
                ),
                placeholder: true,
              ),
              DataCell(
                const Text(''),
                placeholder: true,
              ),
              DataCell(
                const Text(''),
                placeholder: true,
              ),
              DataCell(
                const Text(''),
                placeholder: true,
              ),
              DataCell(
                const Text(''),
                placeholder: true,
              ),
              DataCell(
                const Text(''),
                placeholder: true,
              ),
              DataCell(
                const Text(''),
                placeholder: true,
              ),
              DataCell(
                const Text(''),
                placeholder: true,
              ),
            ],
          ),
        );

        // ✅ Add student rows
        for (var student in students) {
          int totalDays =
              student.presentDates.length + student.absentDates.length;
          int presentDays = student.presentDates.length;
          int absentDays = student.absentDates.length;
          double attendancePercentage =
              totalDays > 0 ? (presentDays / totalDays) * 100 : 0;

          rows.add(
            DataRow(
              cells: [
                DataCell(Text('')),
                DataCell(Text(student.name)),
                DataCell(Text(student.surname)),
                DataCell(Text('$totalDays')),
                DataCell(
                  InkWell(
                    onTap: () =>
                        _showDetailedAttendance(context, student, true),
                    child: Text(
                      '$presentDays',
                      style: const TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  InkWell(
                    onTap: () =>
                        _showDetailedAttendance(context, student, false),
                    child: Text(
                      '$absentDays',
                      style: const TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '${attendancePercentage.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: attendancePercentage >= 80
                          ? Colors.green
                          : attendancePercentage >= 60
                              ? Colors.orange
                              : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // In _buildGroupedDataTable, update the Actions cell
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ✅ Only show delete button for Host Admin
                      if (_isHost && _isAdmin)
                        IconButton(
                          icon: const Icon(Icons.delete,
                              size: 20, color: Colors.red),
                          onPressed: () =>
                              _deleteStudentAttendanceHistory(student),
                          tooltip: 'Delete Attendance History',
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return rows;
      }).toList(),
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  String _getFilterSummary() {
    final parts = <String>[];
    if (_selectedClass != null && _selectedClass != "All")
      parts.add('Class: $_selectedClass');
    if (_selectedStartDate != null && _selectedEndDate != null) {
      parts.add(
          'Date: ${DateFormat('yyyy-MM-dd').format(_selectedStartDate!)} to ${DateFormat('yyyy-MM-dd').format(_selectedEndDate!)}');
    }
    if (_selectedStudentName != null && _selectedStudentName!.isNotEmpty) {
      parts.add('Search: $_selectedStudentName');
    }
    return parts.isEmpty ? 'None' : parts.join(' | ');
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.9,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                expand: false,
                builder: (context, scrollController) {
                  return SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Filter Options',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ✅ Class filter with role-based options
                        DropdownButtonFormField<String>(
                          value: _selectedClass,
                          decoration: const InputDecoration(
                            labelText: 'Select Class',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _selectedClass = value;
                            });
                          },
                          items: _classes.map((class_) {
                            return DropdownMenuItem(
                              value: class_,
                              child: Text(class_),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // ✅ Date range filter
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  final pickedStartDate = await showDatePicker(
                                    context: context,
                                    initialDate:
                                        _selectedStartDate ?? DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2101),
                                  );
                                  if (pickedStartDate != null) {
                                    setState(() {
                                      _selectedStartDate = pickedStartDate;
                                    });
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade100,
                                  foregroundColor: Colors.black,
                                ),
                                child: Text(
                                  _selectedStartDate != null
                                      ? 'From: ${DateFormat('yyyy-MM-dd').format(_selectedStartDate!)}'
                                      : 'Start Date',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  final pickedEndDate = await showDatePicker(
                                    context: context,
                                    initialDate:
                                        _selectedEndDate ?? DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2101),
                                  );
                                  if (pickedEndDate != null) {
                                    setState(() {
                                      _selectedEndDate = pickedEndDate;
                                    });
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade100,
                                  foregroundColor: Colors.black,
                                ),
                                child: Text(
                                  _selectedEndDate != null
                                      ? 'To: ${DateFormat('yyyy-MM-dd').format(_selectedEndDate!)}'
                                      : 'End Date',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ✅ Clear date range button
                        if (_selectedStartDate != null ||
                            _selectedEndDate != null)
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedStartDate = null;
                                _selectedEndDate = null;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Clear Date Range'),
                          ),
                        const SizedBox(height: 16),

                        // ✅ Student name search
                        TextField(
                          onChanged: (value) {
                            setState(() {
                              _selectedStudentName = value;
                            });
                          },
                          controller:
                              TextEditingController(text: _selectedStudentName),
                          decoration: const InputDecoration(
                            labelText: 'Search by Student Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.search),
                            suffixIcon: Icon(Icons.clear),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ✅ Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  _applyFilters();
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text('Apply Filters'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  _resetFilters();
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text('Reset All'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showDetailedAttendance(
      BuildContext context, Student student, bool isPresent) {
    final dates = isPresent ? student.presentDates : student.absentDates;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            isPresent ? '✅ Present Dates' : '❌ Absent Dates',
            style: TextStyle(
              color: isPresent ? Colors.green : Colors.red,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: min(400.0, dates.length * 60.0 + 20.0),
            child: dates.isEmpty
                ? const Center(
                    child: Text('No dates recorded'),
                  )
                : ListView.builder(
                    itemCount: dates.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: Icon(
                          isPresent ? Icons.check_circle : Icons.cancel,
                          color: isPresent ? Colors.green : Colors.red,
                        ),
                        title: Text(
                          DateFormat('EEEE, d MMMM yyyy').format(dates[index]),
                        ),
                        subtitle: Text(
                          DateFormat('h:mm a').format(dates[index]),
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
        );
      },
    );
  }
}
