import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/settings.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';
import 'package:zitf_system/server/routes/attendence_settings_api.dart';
import 'package:zitf_system/server/routes/class_factory.dart';
import 'package:zitf_system/server/routes/terms_factory.dart';
import 'package:zitf_system/server/routes/bulk_register_marking_api.dart';
import 'package:zitf_system/student_management/fetch_student_register_api.dart';
import 'package:zitf_system/student_management/mark_student_register_fetch_student_api.dart';
import 'package:zitf_system/student_management/settings_helper.dart';
import 'package:zitf_system/student_management/update_student_from_client.dart';

class MarkAttendanceScreen extends StatefulWidget {
  final String? initialClassName;

  const MarkAttendanceScreen({super.key, this.initialClassName});

  @override
  _MarkAttendanceScreenState createState() => _MarkAttendanceScreenState();
}

enum DeviceRole { host, client }

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  String? _selectedClass;
  DateTime _selectedDate = DateTime.now();
  List<Student> _students = [];
  List<String> _classes = [];
  List<String> _filteredClasses = []; // ✅ For role-based filtering
  List<Terms> _availableTerms = [];
  List<String> _selectedTerms = [];
  bool _isSubmitting = false;
  bool _isLoading = false;
  bool _isLoadingClasses = false;

  // ✅ Settings cache
  Settings? _settings;
  bool _isLoadingSettings = false;

  // Cache for students
  List<Student>? _cachedStudents;

  // ✅ Logged in user
  User? _loggedInUser;
  bool _isAdmin = false;
  bool _isTeacher = false;
  List<String> _teacherClasses = [];

  Future<DeviceRole> _loadDeviceRole() async {
    final prefs = await SharedPreferences.getInstance();
    final roleStr = prefs.getString('device_role');

    if (roleStr == 'host') return DeviceRole.host;
    return DeviceRole.client; // default safe
  }

  DeviceRole? _role;
  bool _roleReady = false;

  @override
  void initState() {
    super.initState();
    _initializeDevice();
  }

  Future<void> _initializeDevice() async {
    final role = await _loadDeviceRole();

    setState(() {
      _role = role;
      _roleReady = true;
    });

    // ✅ Load logged in user first
    await _loadLoggedInUser();

    // ✅ Load settings
    await _loadSettings();
    await _loadTerms();
    await _loadClasses();

    final initialClass = widget.initialClassName;
    if (initialClass != null && _filteredClasses.contains(initialClass)) {
      setState(() => _selectedClass = initialClass);
      await _loadStudentsForClass(initialClass);
    }
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
        debugPrint('📚 Assigned classes: $_teacherClasses');
        debugPrint('🔑 Is Admin: $_isAdmin');
        debugPrint('👨‍🏫 Is Teacher: $_isTeacher');
      }
    } catch (e) {
      debugPrint('❌ Error loading logged in user: $e');
    }
  }

  // ✅ Load settings from Hive
  Future<void> _loadSettings() async {
    if (_role != DeviceRole.host) return; // Only host needs local settings

    setState(() => _isLoadingSettings = true);

    try {
      final settings = await SettingsHelper.getSettings();
      setState(() {
        _settings = settings;
        _isLoadingSettings = false;
      });

      debugPrint(
          '✅ Settings loaded: allowAttendanceUpdate = ${settings.allowAttendanceUpdate}');
    } catch (e) {
      debugPrint('❌ Error loading settings: $e');
      setState(() => _isLoadingSettings = false);
    }
  }

  // ✅ Toggle attendance update permission (Host only)
  Future<void> _toggleAttendanceUpdate(bool value) async {
    if (_role != DeviceRole.host) return;

    setState(() => _isLoadingSettings = true);

    try {
      await SettingsHelper.toggleAttendanceUpdate(value);

      // Refresh settings
      final settings = await SettingsHelper.getSettings();
      setState(() {
        _settings = settings;
        _isLoadingSettings = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value
              ? '✅ Attendance updates are now allowed'
              : '❌ Attendance updates are now blocked'),
          backgroundColor: value ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      setState(() => _isLoadingSettings = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error updating setting: $e')),
      );
    }
  }

  Future<void> _loadTerms() async {
    if (!_roleReady) return;

    final now = DateTime.now();

    if (_role == DeviceRole.host) {
      final termsBox = await Hive.openBox<Terms>('terms');
      final terms = termsBox.values.toList();
      final sorted = sortTermsByStatusAndStartDate(terms);

      setState(() {
        _availableTerms = sorted;
        _selectedTerms = sorted
            .where((t) => t.endDate != null && t.endDate!.isAfter(now))
            .map((t) => t.termId!)
            .toList();
      });
    } else {
      try {
        final terms = await TermApiService.fetchTerms();
        final sorted = sortTermsByStatusAndStartDate(terms);

        setState(() {
          _availableTerms = sorted;
          _selectedTerms = sorted
              .where((t) => t.endDate != null && t.endDate!.isAfter(now))
              .map((t) => t.termId!)
              .toList();
        });
      } catch (e) {
        setState(() {
          _availableTerms = [];
          _selectedTerms = [];
        });

        _showDialog(
          'Unable to load terms from host.\n'
          'You cannot mark attendance while offline.',
        );
      }
    }
  }

  List<Terms> sortTermsByStatusAndStartDate(List<Terms> terms) {
    final now = DateTime.now();

    terms.sort((a, b) {
      final aExpired = a.endDate != null && a.endDate!.isBefore(now);
      final bExpired = b.endDate != null && b.endDate!.isBefore(now);

      if (aExpired != bExpired) {
        return aExpired ? 1 : -1;
      }

      final aStart = a.startDate ?? DateTime(1900);
      final bStart = b.startDate ?? DateTime(1900);

      return bStart.compareTo(aStart);
    });

    return terms;
  }

  Terms? getActiveTerm() {
    if (_availableTerms.isEmpty) return null;

    final now = DateTime.now();
    return _availableTerms.firstWhere(
      (term) =>
          term.startDate != null &&
          term.endDate != null &&
          !now.isBefore(term.startDate!) &&
          !now.isAfter(term.endDate!),
      orElse: () => _availableTerms.first,
    );
  }

  Future<void> _loadClasses() async {
    if (!_roleReady) return;

    final currentTerm = getActiveTerm();
    if (currentTerm == null) {
      setState(() {
        _classes = [];
        _filteredClasses = [];
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '⚠️ No term found. Attendance cannot be marked until a term is set up.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      });
      return;
    }

    final termId = currentTerm.termId!;

    setState(() {
      _isLoadingClasses = true;
    });

    try {
      List<String> allClasses = [];

      if (_role == DeviceRole.host) {
        final box = await Hive.openBox<Classes>('classes');
        allClasses = box.values
            .where((c) => c.terms!.contains(termId))
            .map((c) => c.className)
            .toList();
      } else {
        try {
          allClasses = await ClassApiService.fetchClasses(termId);
        } catch (e) {
          setState(() {
            _classes = [];
            _filteredClasses = [];
            _isLoadingClasses = false;
          });
          _showDialog(
            'Unable to load classes from host.\n'
            'You cannot mark attendance while offline.',
          );
          return;
        }
      }

      // ✅ Apply role-based filtering with case-insensitive comparison
      List<String> filteredClasses = [];

      // ✅ Create a normalized map for case-insensitive comparison
      // This maps lowercase class names to their original casing
      final Map<String, String> classMap = {};
      for (var className in allClasses) {
        classMap[className.toLowerCase()] = className;
      }

      if (_isAdmin) {
        // ✅ Admin: See ALL classes
        filteredClasses = List.from(allClasses);
        debugPrint('🔑 Admin - Showing all ${filteredClasses.length} classes');
      } else if (_isTeacher) {
        // ✅ Teacher: Only see assigned classes (case-insensitive)
        final normalizedTeacherClasses =
            _teacherClasses.map((c) => c.toLowerCase()).toList();

        // Find matching classes using case-insensitive comparison
        filteredClasses = allClasses.where((className) {
          return normalizedTeacherClasses.contains(className.toLowerCase());
        }).toList();

        debugPrint(
            '👨‍🏫 Teacher - Showing ${filteredClasses.length} assigned classes');
        debugPrint('📚 Assigned classes (original): $_teacherClasses');
        debugPrint('📋 Available classes: $allClasses');
        debugPrint('🔍 Matched classes: $filteredClasses');

        if (filteredClasses.isEmpty) {
          // Show a message if teacher has no classes assigned
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'ℹ️ You have no classes assigned. Please contact administrator.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          });
        }
      } else {
        // ✅ Other roles (secretary, accountant): No class access
        filteredClasses = [];
        debugPrint('👤 ${_loggedInUser?.role} - No class access');
      }

      setState(() {
        _classes = allClasses; // Keep full list for reference
        _filteredClasses = filteredClasses; // Display filtered list
        _isLoadingClasses = false;

        // Reset selected class if it's not in the filtered list (case-insensitive)
        if (_selectedClass != null) {
          final normalizedSelected = _selectedClass!.toLowerCase();
          final matches =
              filteredClasses.any((c) => c.toLowerCase() == normalizedSelected);
          if (!matches) {
            _selectedClass = null;
          }
        }
      });
    } catch (e) {
      setState(() {
        _classes = [];
        _filteredClasses = [];
        _isLoadingClasses = false;
      });
    }
  }

  Future<void> _loadStudentsForClass(String className) async {
    if (!_roleReady) return;

    final currentTerm = getActiveTerm();
    if (currentTerm == null) {
      setState(() => _students = []);
      _showDialog('No active term found. Attendance cannot be marked.');
      return;
    }

    final termId = currentTerm.termId!;

    setState(() {
      _isLoading = true;
      _students = [];
    });

    try {
      List<Student> loadedStudents = [];

      if (_role == DeviceRole.host) {
        // HOST: Load from Hive
        final box = await Hive.openBox<Student>('students');
        loadedStudents = box.values
            .where((s) =>
                s.class_ == className &&
                s.terms != null &&
                s.terms!.contains(termId))
            .toList();
      } else {
        // CLIENT: Fetch from server using /all endpoint
        final allStudents = await StudentRegisterFetchApi.fetchAllStudents();
        _cachedStudents = allStudents;

        // Filter locally for the selected class and term
        loadedStudents = allStudents
            .where((s) =>
                s.class_ == className &&
                s.terms != null &&
                s.terms!.contains(termId))
            .toList();
      }

      // Sort alphabetically by surname then name
      loadedStudents.sort((a, b) {
        final surnameCompare = a.surname.compareTo(b.surname);
        if (surnameCompare != 0) return surnameCompare;
        return a.name.compareTo(b.name);
      });

      // ✅ Check if attendance already marked for today
      final date = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );

      bool isAlreadyMarked =
          await _isAttendanceAlreadyMarkedForClass(className, date);

      if (isAlreadyMarked) {
        // ✅ Show a banner but still load students
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '📋 Attendance already marked for this date. You can update the records.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        });
      }

      if (isAlreadyMarked) {
        // ✅ Reflect the actual historical record for this specific date -
        // not whatever isPresent happened to be left over from loading a
        // different day or a previous marking session. isPresent is a
        // single field on the Student record, not date-scoped, so it must
        // be re-derived from presentDates/absentDates every time a
        // possibly-different date is loaded.
        for (var student in loadedStudents) {
<<<<<<< HEAD
          student.isPresent =
              student.presentDates.any((d) => _isSameDay(d, date));
=======
          student.isPresent = student.presentDates.any((d) => _isSameDay(d, date));
>>>>>>> 7d311023c2619e7d7fa273d034388c9ed21d5c8d
        }
      } else {
        // Mark all as present by default if not already marked
        for (var student in loadedStudents) {
          student.isPresent = true; // Default to present
        }
      }

      setState(() {
        _students = loadedStudents;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _students = [];
        _isLoading = false;
      });
      _showDialog(
        'Unable to load students from host.\n'
        'Check connection.',
      );
    }
  }

  // Compares calendar day only, ignoring any time component - relying on
  // exact DateTime equality (via List.contains) silently fails to match if
  // a stored date ever picked up a differing time from some other code
  // path.
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ✅ Check if attendance already marked for this class and date
  Future<bool> _isAttendanceAlreadyMarkedForClass(
      String className, DateTime date) async {
    if (_role == DeviceRole.host) {
      // HOST: Check Hive
      final box = await Hive.openBox<Student>('students');
      final students = box.values.where((s) => s.class_ == className).toList();

      for (var student in students) {
        if (student.presentDates.any((d) => _isSameDay(d, date)) ||
            student.absentDates.any((d) => _isSameDay(d, date))) {
          return true;
        }
      }
      return false;
    } else {
      // CLIENT: Check via API
      try {
        final isMarked = await StudentRegisterFetchApi.isAttendanceMarked(
          className: className,
          date: date,
        );
        return isMarked;
      } catch (e) {
        return false;
      }
    }
  }

  void _toggleSelectAll(bool? value) {
    if (value == null) return;
    setState(() {
      for (var student in _students) {
        student.isPresent = value;
      }
    });
  }

  bool get _allSelected {
    if (_students.isEmpty) return false;
    return _students.every((student) => student.isPresent);
  }

  bool get _anySelected {
    return _students.any((student) => student.isPresent);
  }

  // ✅ Get counts for display
  int get _presentCount {
    return _students.where((s) => s.isPresent).length;
  }

  int get _absentCount {
    return _students.where((s) => !s.isPresent).length;
  }

  // ✅ Check if updates are allowed
  Future<bool> _checkIfUpdateAllowed() async {
    if (_role == DeviceRole.host) {
      // Host: Check local settings
      try {
        final settings = await SettingsHelper.getSettings();
        return settings.isAttendanceUpdateAllowed();
      } catch (e) {
        // If settings can't be loaded, default to false (block updates)
        return false;
      }
    } else {
      // Client: Check with server
      try {
        return await AttendanceSettingsApiService.isUpdateAllowed();
      } catch (e) {
        return false;
      }
    }
  }

// Add this method
  void _showDebugDialog() async {
    try {
      final debugInfo =
          await AttendanceSettingsApiService.debugGetAllSettings();

      final buffer = StringBuffer();
      buffer.writeln('=== DEBUG INFO ===');
      buffer.writeln('User: ${_loggedInUser?.username}');
      buffer.writeln('Role: ${_loggedInUser?.role}');
      buffer.writeln('Is Admin: $_isAdmin');
      buffer.writeln('Is Teacher: $_isTeacher');
      buffer.writeln('Assigned Classes: $_teacherClasses');
      buffer.writeln('Filtered Classes: $_filteredClasses');
      buffer.writeln('All Classes: $_classes');
      buffer.writeln('---');
      buffer.writeln('Settings Count: ${debugInfo['count'] ?? 0}');
      buffer.writeln('Box Name: ${debugInfo['boxName'] ?? 'Unknown'}');
      buffer.writeln('Box Length: ${debugInfo['boxLength'] ?? 0}');
      buffer.writeln('Keys: ${debugInfo['keys'] ?? []}');
      buffer.writeln('\n=== Settings ===');

      final settingsList = debugInfo['settings'] as List? ?? [];
      for (var s in settingsList) {
        buffer.writeln('ID: ${s['id']}');
        buffer.writeln('allowAttendanceUpdate: ${s['allowAttendanceUpdate']}');
        buffer.writeln('lastUpdated: ${s['lastUpdated']}');
        buffer.writeln('modifiedFields: ${s['modifiedFields']}');
        buffer.writeln('---');
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('🐛 Debug Settings'),
          content: Container(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Text(
                buffer.toString(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final success =
                    await AttendanceSettingsApiService.debugResetSettings();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? '✅ Settings reset successfully'
                        : '❌ Failed to reset settings'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              },
              child: const Text('Reset Settings'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }
  }

  // ✅ Handle the attendance marking with update check
  Future<void> _markAttendance() async {
    if (_isSubmitting) return;

    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students to mark attendance for')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_selectedClass == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a class')),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      final date = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );

      final currentTerm = getActiveTerm();
      if (currentTerm == null) {
        _showDialog('No active term found.');
        setState(() => _isSubmitting = false);
        return;
      }

      final termId = currentTerm.termId!;

      // ✅ Check if already marked
      bool alreadyMarked =
          await _isAttendanceAlreadyMarkedForClass(_selectedClass!, date);

      if (alreadyMarked) {
        // ✅ Check if updates are allowed
        final updateAllowed = await _checkIfUpdateAllowed();

        if (!updateAllowed) {
          // ❌ Updates are blocked
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '❌ Attendance updates are currently blocked by the host.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
          setState(() => _isSubmitting = false);
          return;
        }

        // ✅ Show update confirmation dialog
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Attendance Already Marked'),
            content: const Text(
                'Attendance has already been marked for this class on this date.\n'
                'Do you want to update the records?'),
            actions: [
              IconButton(
                icon: const Icon(Icons.bug_report, color: Colors.yellow),
                onPressed: _showDebugDialog,
                tooltip: 'Debug Settings',
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Update'),
              ),
            ],
          ),
        );

        if (confirm != true) {
          setState(() => _isSubmitting = false);
          return;
        }
      }

      // Apply attendance based on device role
      if (_role == DeviceRole.host) {
        // HOST: Save locally
        for (final student in _students) {
          student.presentDates.remove(date);
          student.absentDates.remove(date);
          await _applyAttendanceLocally(student, date, student.isPresent);
        }

        final action = alreadyMarked ? 'Updated' : 'Marked';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Attendance $action successfully (${_presentCount} present, ${_absentCount} absent)'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // CLIENT: Sync to host via API
        try {
          final result = await StudentRegisterBulkApiService.markBulkRegister(
            className: _selectedClass!,
            termId: termId,
            date: date,
            students: _students,
          );

          final action = result['updated'] == true ? 'Updated' : 'Marked';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '✅ Attendance $action successfully (${_presentCount} present, ${_absentCount} absent)'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          if (e is AttendanceConflictException) {
            // ✅ Handle conflict exception
            if (e.allowUpdate) {
              // The server says updates are allowed, but we already checked
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Updates are allowed but there was a conflict. Please try again.'),
                  backgroundColor: Colors.orange,
                ),
              );
            } else {
              // ❌ Updates are blocked by the host
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('❌ ${e.message}'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          } else {
            // Re-throw other errors
            rethrow;
          }
          setState(() => _isSubmitting = false);
          return;
        }
      }

      // Refresh the student list
      if (_selectedClass != null) {
        await _loadStudentsForClass(_selectedClass!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error marking attendance: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _applyAttendanceLocally(
    Student student,
    DateTime date,
    bool isPresent,
  ) async {
    // ✅ Track modified fields
    List<String> modifiedFields = [];

    if (isPresent) {
      if (!student.presentDates.any((d) => _isSameDay(d, date))) {
        student.presentDates.add(date);
        modifiedFields.add('presentDates');
      }
      if (student.absentDates.any((d) => _isSameDay(d, date))) {
        student.absentDates.removeWhere((d) => _isSameDay(d, date));
        if (!modifiedFields.contains('absentDates')) {
          modifiedFields.add('absentDates');
        }
      }
    } else {
      if (!student.absentDates.any((d) => _isSameDay(d, date))) {
        student.absentDates.add(date);
        modifiedFields.add('absentDates');
      }
      if (student.presentDates.any((d) => _isSameDay(d, date))) {
        student.presentDates.removeWhere((d) => _isSameDay(d, date));
        if (!modifiedFields.contains('presentDates')) {
          modifiedFields.add('presentDates');
        }
      }
    }

    // ✅ Only update if there were actual changes
    if (modifiedFields.isNotEmpty) {
      // ✅ Set sync fields
      student.syncStatus = false; // Mark as unsynced
      student.lastModified = DateTime.now();
      student.operationType = 'update';

      // ✅ Merge with existing modified fields
      if (student.modifiedFields == null) {
        student.modifiedFields = modifiedFields;
      } else {
        for (var field in modifiedFields) {
          if (!student.modifiedFields!.contains(field)) {
            student.modifiedFields!.add(field);
          }
        }
      }

      await student.save();
      print(
          '✅ Student ${student.studentIdNumber} - Attendance updated, ready for sync');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Determine if user has access to any classes
    final bool hasClassAccess =
        _isAdmin || (_isTeacher && _filteredClasses.isNotEmpty);

    return Scaffold(
      appBar: const CustomAppBar(title: 'Mark Attendance'),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(16.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ User Role Indicator
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
                                ? '🔑 Administrator - Full Access'
                                : _isTeacher
                                    ? '👨‍🏫 Teacher - ${_filteredClasses.length} classes assigned'
                                    : '👤 ${_loggedInUser?.role ?? 'User'} - No class access',
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

                  // ✅ Host Settings Toggle (only visible to host)
                  if (_role == DeviceRole.host) ...[
                    Card(
                      color: _settings?.allowAttendanceUpdate == true
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Icon(
                              _settings?.allowAttendanceUpdate == true
                                  ? Icons.check_circle
                                  : Icons.block,
                              color: _settings?.allowAttendanceUpdate == true
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Client Update Permission',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _settings?.allowAttendanceUpdate ==
                                              true
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                    ),
                                  ),
                                  Text(
                                    _settings?.allowAttendanceUpdate == true
                                        ? 'Clients can update existing attendance records'
                                        : 'Clients cannot update existing attendance records',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _settings?.allowAttendanceUpdate ==
                                              true
                                          ? Colors.green.shade600
                                          : Colors.red.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _settings?.allowAttendanceUpdate ?? false,
                              onChanged: _isLoadingSettings
                                  ? null
                                  : _toggleAttendanceUpdate,
                              activeColor: Colors.green,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ✅ No access message for non-admin/non-teacher or teacher with no classes
                  if (!hasClassAccess) ...[
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
                                : 'You do not have permission to mark attendance.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.orange.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Only administrators and teachers with assigned classes can mark attendance.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // ✅ Class selection with loading overlay
                    Stack(
                      children: [
                        Column(
                          children: [
                            DropdownButtonFormField<String>(
                              value: _selectedClass,
                              hint: Text(_filteredClasses.isEmpty
                                  ? 'No classes available'
                                  : 'Select Class'),
                              items: _filteredClasses.map((className) {
                                return DropdownMenuItem<String>(
                                  value: className,
                                  child: Text(className),
                                );
                              }).toList(),
                              decoration: const InputDecoration(
                                labelText: 'Select Class',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_isLoadingClasses ||
                                      _isLoading ||
                                      _filteredClasses.isEmpty)
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedClass = value;
                                      });
                                      if (value != null) {
                                        _loadStudentsForClass(value);
                                      }
                                    },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: TextEditingController(
                                text: DateFormat('EEEE, d MMMM yyyy')
                                    .format(_selectedDate),
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Date',
                                border: OutlineInputBorder(),
                              ),
                              readOnly: true,
                              onTap: _isLoading || _isLoadingClasses
                                  ? null
                                  : () async {
                                      DateTime? pickedDate =
                                          await showDatePicker(
                                        context: context,
                                        initialDate: _selectedDate,
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2101),
                                      );
                                      if (pickedDate != null) {
                                        setState(() {
                                          _selectedDate = pickedDate;
                                        });
                                        // Reload students when date changes
                                        if (_selectedClass != null) {
                                          _loadStudentsForClass(
                                              _selectedClass!);
                                        }
                                      }
                                    },
                            ),
                          ],
                        ),
                        // ✅ Loading overlay for class selection
                        if (_isLoadingClasses)
                          Container(
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Loading classes...'),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ✅ Loading indicator for students
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Loading students...'),
                            ],
                          ),
                        ),
                      )
                    else if (_students.isEmpty && _selectedClass != null)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text('No students found for this class'),
                        ),
                      )
                    else if (_students.isNotEmpty)
                      Column(
                        children: [
                          // ✅ Select/Unselect All header with counts
                          Card(
                            color: Colors.grey.shade100,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: _allSelected,
                                    onChanged:
                                        _isSubmitting ? null : _toggleSelectAll,
                                    tristate: _anySelected && !_allSelected,
                                  ),
                                  const Text(
                                    'Select All',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  // ✅ Show present/absent counts
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Present: $_presentCount',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Absent: $_absentCount',
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Total: ${_students.length}',
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // ✅ Student list
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _students.length,
                            itemBuilder: (context, index) {
                              final student = _students[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  title: Text(
                                    "${student.surname}, ${student.name}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Text(student.class_),
                                      const Spacer(),
                                      // ✅ Show if already marked
                                      _isStudentMarked(student)
                                          ? Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade200,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                'Marked',
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            )
                                          : const SizedBox(),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // ✅ Present checkbox
                                      Tooltip(
                                        message: 'Mark Present',
                                        child: Checkbox(
                                          value: student.isPresent,
                                          onChanged: _isSubmitting
                                              ? null
                                              : (value) {
                                                  setState(() {
                                                    student.isPresent =
                                                        value ?? false;
                                                  });
                                                },
                                          activeColor: Colors.green,
                                        ),
                                      ),
                                      // ✅ Absent button
                                      Tooltip(
                                        message: 'Mark Absent',
                                        child: IconButton(
                                          icon: const Icon(Icons.close,
                                              color: Colors.red),
                                          onPressed: _isSubmitting
                                              ? null
                                              : () {
                                                  setState(() {
                                                    student.isPresent = false;
                                                  });
                                                },
                                          iconSize: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),

                    // ✅ Submit button with loading state
                    ElevatedButton(
                      onPressed: (_students.isEmpty ||
                              _isSubmitting ||
                              _isLoading ||
                              _selectedClass == null)
                          ? null
                          : _markAttendance,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: _isSubmitting
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Submitting...'),
                              ],
                            )
                          : const Text('Mark Attendance'),
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

  // ✅ Helper to check if a student is already marked for the selected date
  bool _isStudentMarked(Student student) {
    final date = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    return student.presentDates.any((d) => _isSameDay(d, date)) ||
        student.absentDates.any((d) => _isSameDay(d, date));
  }

  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Attendance Feedback"),
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
}


// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import 'package:intl/intl.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:zitf_system/auth/userdb.dart';
// import 'package:zitf_system/database/classes.dart';
// import 'package:zitf_system/database/settings.dart';
// import 'package:zitf_system/database/student.dart';
// import 'package:zitf_system/database/terms.dart';
// import 'package:zitf_system/global%20files/global_term_id.dart';
// import 'package:zitf_system/main.dart';
// import 'package:zitf_system/reusable_codes/custom_app_bar.dart';
// import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';
// import 'package:zitf_system/server/routes/attendence_settings_api.dart';
// import 'package:zitf_system/server/routes/class_factory.dart';
// import 'package:zitf_system/server/routes/terms_factory.dart';
// import 'package:zitf_system/server/routes/bulk_register_marking_api.dart';
// import 'package:zitf_system/student_management/fetch_student_register_api.dart';
// import 'package:zitf_system/student_management/mark_student_register_fetch_student_api.dart';
// import 'package:zitf_system/student_management/settings_helper.dart';
// import 'package:zitf_system/student_management/update_student_from_client.dart';

// class MarkAttendanceScreen extends StatefulWidget {
//   @override
//   _MarkAttendanceScreenState createState() => _MarkAttendanceScreenState();
// }

// enum DeviceRole { host, client }

// class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
//   String? _selectedClass;
//   DateTime _selectedDate = DateTime.now();
//   List<Student> _students = [];
//   List<String> _classes = [];
//   List<String> _filteredClasses = []; // ✅ For role-based filtering
//   List<Terms> _availableTerms = [];
//   List<String> _selectedTerms = [];
//   bool _isSubmitting = false;
//   bool _isLoading = false;
//   bool _isLoadingClasses = false;

//   // ✅ Settings cache
//   Settings? _settings;
//   bool _isLoadingSettings = false;

//   // Cache for students
//   List<Student>? _cachedStudents;

//   // ✅ Logged in user
//   User? _loggedInUser;
//   bool _isAdmin = false;
//   bool _isTeacher = false;
//   List<String> _teacherClasses = [];

//   Future<DeviceRole> _loadDeviceRole() async {
//     final prefs = await SharedPreferences.getInstance();
//     final roleStr = prefs.getString('device_role');

//     if (roleStr == 'host') return DeviceRole.host;
//     return DeviceRole.client; // default safe
//   }

//   DeviceRole? _role;
//   bool _roleReady = false;

//   @override
//   void initState() {
//     super.initState();
//     _initializeDevice();
//   }

//   Future<void> _initializeDevice() async {
//     final role = await _loadDeviceRole();

//     setState(() {
//       _role = role;
//       _roleReady = true;
//     });

//     // ✅ Load logged in user first
//     await _loadLoggedInUser();

//     // ✅ Load settings
//     await _loadSettings();
//     await _loadTerms();
//     await _loadClasses();
//   }

//   // ✅ Load logged in user and determine permissions
//   Future<void> _loadLoggedInUser() async {
//     try {
//       _loggedInUser = await getLoggedInUser();

//       if (_loggedInUser != null) {
//         final role = _loggedInUser!.role.toLowerCase();
//         _isAdmin = role == 'admin' || role == 'administration';
//         _isTeacher = role == 'teacher';
//         _teacherClasses = _loggedInUser!.assignedClasses ?? [];

//         debugPrint('👤 Logged in user: ${_loggedInUser!.username}');
//         debugPrint('📋 Role: ${_loggedInUser!.role}');
//         debugPrint('📚 Assigned classes: $_teacherClasses');
//         debugPrint('🔑 Is Admin: $_isAdmin');
//         debugPrint('👨‍🏫 Is Teacher: $_isTeacher');
//       }
//     } catch (e) {
//       debugPrint('❌ Error loading logged in user: $e');
//     }
//   }

//   // ✅ Load settings from Hive
//   Future<void> _loadSettings() async {
//     if (_role != DeviceRole.host) return; // Only host needs local settings

//     setState(() => _isLoadingSettings = true);

//     try {
//       final settings = await SettingsHelper.getSettings();
//       setState(() {
//         _settings = settings;
//         _isLoadingSettings = false;
//       });

//       debugPrint(
//           '✅ Settings loaded: allowAttendanceUpdate = ${settings.allowAttendanceUpdate}');
//     } catch (e) {
//       debugPrint('❌ Error loading settings: $e');
//       setState(() => _isLoadingSettings = false);
//     }
//   }

//   // ✅ Toggle attendance update permission (Host only)
//   Future<void> _toggleAttendanceUpdate(bool value) async {
//     if (_role != DeviceRole.host) return;

//     setState(() => _isLoadingSettings = true);

//     try {
//       await SettingsHelper.toggleAttendanceUpdate(value);

//       // Refresh settings
//       final settings = await SettingsHelper.getSettings();
//       setState(() {
//         _settings = settings;
//         _isLoadingSettings = false;
//       });

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(value
//               ? '✅ Attendance updates are now allowed'
//               : '❌ Attendance updates are now blocked'),
//           backgroundColor: value ? Colors.green : Colors.red,
//         ),
//       );
//     } catch (e) {
//       setState(() => _isLoadingSettings = false);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('❌ Error updating setting: $e')),
//       );
//     }
//   }

//   Future<void> _loadTerms() async {
//     if (!_roleReady) return;

//     final now = DateTime.now();

//     if (_role == DeviceRole.host) {
//       final termsBox = await Hive.openBox<Terms>('terms');
//       final terms = termsBox.values.toList();
//       final sorted = sortTermsByStatusAndStartDate(terms);

//       setState(() {
//         _availableTerms = sorted;
//         _selectedTerms = sorted
//             .where((t) => t.endDate != null && t.endDate!.isAfter(now))
//             .map((t) => t.termId!)
//             .toList();
//       });
//     } else {
//       try {
//         final terms = await TermApiService.fetchTerms();
//         final sorted = sortTermsByStatusAndStartDate(terms);

//         setState(() {
//           _availableTerms = sorted;
//           _selectedTerms = sorted
//               .where((t) => t.endDate != null && t.endDate!.isAfter(now))
//               .map((t) => t.termId!)
//               .toList();
//         });
//       } catch (e) {
//         setState(() {
//           _availableTerms = [];
//           _selectedTerms = [];
//         });

//         _showDialog(
//           'Unable to load terms from host.\n'
//           'You cannot mark attendance while offline.',
//         );
//       }
//     }
//   }

//   List<Terms> sortTermsByStatusAndStartDate(List<Terms> terms) {
//     final now = DateTime.now();

//     terms.sort((a, b) {
//       final aExpired = a.endDate != null && a.endDate!.isBefore(now);
//       final bExpired = b.endDate != null && b.endDate!.isBefore(now);

//       if (aExpired != bExpired) {
//         return aExpired ? 1 : -1;
//       }

//       final aStart = a.startDate ?? DateTime(1900);
//       final bStart = b.startDate ?? DateTime(1900);

//       return bStart.compareTo(aStart);
//     });

//     return terms;
//   }

//   Terms? getActiveTerm() {
//     final now = DateTime.now();
//     return _availableTerms.firstWhere(
//       (term) =>
//           term.startDate != null &&
//           term.endDate != null &&
//           !now.isBefore(term.startDate!) &&
//           !now.isAfter(term.endDate!),
//       orElse: () => _availableTerms.first,
//     );
//   }

//   Future<void> _loadClasses() async {
//     if (!_roleReady) return;

//     final currentTerm = getActiveTerm();
//     if (currentTerm == null) {
//       setState(() {
//         _classes = [];
//         _filteredClasses = [];
//       });
//       return;
//     }

//     final termId = currentTerm.termId!;

//     setState(() {
//       _isLoadingClasses = true;
//     });

//     try {
//       List<String> allClasses = [];

//       if (_role == DeviceRole.host) {
//         final box = await Hive.openBox<Classes>('classes');
//         allClasses = box.values
//             .where((c) => c.terms!.contains(termId))
//             .map((c) => c.className)
//             .toList();
//       } else {
//         try {
//           allClasses = await ClassApiService.fetchClasses(termId);
//         } catch (e) {
//           setState(() {
//             _classes = [];
//             _filteredClasses = [];
//             _isLoadingClasses = false;
//           });
//           _showDialog(
//             'Unable to load classes from host.\n'
//             'You cannot mark attendance while offline.',
//           );
//           return;
//         }
//       }

//       // ✅ Apply role-based filtering with case-insensitive comparison
//       List<String> filteredClasses = [];

//       // ✅ Create a normalized map for case-insensitive comparison
//       // This maps lowercase class names to their original casing
//       final Map<String, String> classMap = {};
//       for (var className in allClasses) {
//         classMap[className.toLowerCase()] = className;
//       }

//       if (_isAdmin) {
//         // ✅ Admin: See ALL classes
//         filteredClasses = List.from(allClasses);
//         debugPrint('🔑 Admin - Showing all ${filteredClasses.length} classes');
//       } else if (_isTeacher) {
//         // ✅ Teacher: Only see assigned classes (case-insensitive)
//         final normalizedTeacherClasses =
//             _teacherClasses.map((c) => c.toLowerCase()).toList();

//         // Find matching classes using case-insensitive comparison
//         filteredClasses = allClasses.where((className) {
//           return normalizedTeacherClasses.contains(className.toLowerCase());
//         }).toList();

//         debugPrint(
//             '👨‍🏫 Teacher - Showing ${filteredClasses.length} assigned classes');
//         debugPrint('📚 Assigned classes (original): $_teacherClasses');
//         debugPrint('📋 Available classes: $allClasses');
//         debugPrint('🔍 Matched classes: $filteredClasses');

//         if (filteredClasses.isEmpty) {
//           // Show a message if teacher has no classes assigned
//           WidgetsBinding.instance.addPostFrameCallback((_) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(
//                 content: Text(
//                     'ℹ️ You have no classes assigned. Please contact administrator.'),
//                 backgroundColor: Colors.orange,
//                 duration: Duration(seconds: 4),
//               ),
//             );
//           });
//         }
//       } else {
//         // ✅ Other roles (secretary, accountant): No class access
//         filteredClasses = [];
//         debugPrint('👤 ${_loggedInUser?.role} - No class access');
//       }

//       setState(() {
//         _classes = allClasses; // Keep full list for reference
//         _filteredClasses = filteredClasses; // Display filtered list
//         _isLoadingClasses = false;

//         // Reset selected class if it's not in the filtered list (case-insensitive)
//         if (_selectedClass != null) {
//           final normalizedSelected = _selectedClass!.toLowerCase();
//           final matches =
//               filteredClasses.any((c) => c.toLowerCase() == normalizedSelected);
//           if (!matches) {
//             _selectedClass = null;
//           }
//         }
//       });
//     } catch (e) {
//       setState(() {
//         _classes = [];
//         _filteredClasses = [];
//         _isLoadingClasses = false;
//       });
//     }
//   }

//   Future<void> _loadStudentsForClass(String className) async {
//     if (!_roleReady) return;

//     final currentTerm = getActiveTerm();
//     if (currentTerm == null) {
//       setState(() => _students = []);
//       return;
//     }

//     final termId = currentTerm.termId!;

//     setState(() {
//       _isLoading = true;
//       _students = [];
//     });

//     try {
//       List<Student> loadedStudents = [];

//       if (_role == DeviceRole.host) {
//         // HOST: Load from Hive
//         final box = await Hive.openBox<Student>('students');
//         loadedStudents = box.values
//             .where((s) =>
//                 s.class_ == className &&
//                 s.terms != null &&
//                 s.terms!.contains(termId))
//             .toList();
//       } else {
//         // CLIENT: Fetch from server using /all endpoint
//         final allStudents = await StudentRegisterFetchApi.fetchAllStudents();
//         _cachedStudents = allStudents;

//         // Filter locally for the selected class and term
//         loadedStudents = allStudents
//             .where((s) =>
//                 s.class_ == className &&
//                 s.terms != null &&
//                 s.terms!.contains(termId))
//             .toList();
//       }

//       // Sort alphabetically by surname then name
//       loadedStudents.sort((a, b) {
//         final surnameCompare = a.surname.compareTo(b.surname);
//         if (surnameCompare != 0) return surnameCompare;
//         return a.name.compareTo(b.name);
//       });

//       // ✅ Check if attendance already marked for today
//       final date = DateTime(
//         _selectedDate.year,
//         _selectedDate.month,
//         _selectedDate.day,
//       );

//       bool isAlreadyMarked =
//           await _isAttendanceAlreadyMarkedForClass(className, date);

//       if (isAlreadyMarked) {
//         // ✅ Show a banner but still load students
//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text(
//                   '📋 Attendance already marked for this date. You can update the records.'),
//               backgroundColor: Colors.orange,
//               duration: Duration(seconds: 3),
//             ),
//           );
//         });
//       }

//       // ✅ Mark all as present by default if not already marked
//       if (!isAlreadyMarked) {
//         for (var student in loadedStudents) {
//           student.isPresent = true; // Default to present
//         }
//       }

//       setState(() {
//         _students = loadedStudents;
//         _isLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _students = [];
//         _isLoading = false;
//       });
//       _showDialog(
//         'Unable to load students from host.\n'
//         'Check connection.',
//       );
//     }
//   }

//   // ✅ Check if attendance already marked for this class and date
//   Future<bool> _isAttendanceAlreadyMarkedForClass(
//       String className, DateTime date) async {
//     if (_role == DeviceRole.host) {
//       // HOST: Check Hive
//       final box = await Hive.openBox<Student>('students');
//       final students = box.values.where((s) => s.class_ == className).toList();

//       for (var student in students) {
//         if (student.presentDates.contains(date) ||
//             student.absentDates.contains(date)) {
//           return true;
//         }
//       }
//       return false;
//     } else {
//       // CLIENT: Check via API
//       try {
//         final isMarked = await StudentRegisterFetchApi.isAttendanceMarked(
//           className: className,
//           date: date,
//         );
//         return isMarked;
//       } catch (e) {
//         return false;
//       }
//     }
//   }

//   void _toggleSelectAll(bool? value) {
//     if (value == null) return;
//     setState(() {
//       for (var student in _students) {
//         student.isPresent = value;
//       }
//     });
//   }

//   bool get _allSelected {
//     if (_students.isEmpty) return false;
//     return _students.every((student) => student.isPresent);
//   }

//   bool get _anySelected {
//     return _students.any((student) => student.isPresent);
//   }

//   // ✅ Get counts for display
//   int get _presentCount {
//     return _students.where((s) => s.isPresent).length;
//   }

//   int get _absentCount {
//     return _students.where((s) => !s.isPresent).length;
//   }

//   // ✅ Check if updates are allowed
//   Future<bool> _checkIfUpdateAllowed() async {
//     if (_role == DeviceRole.host) {
//       // Host: Check local settings
//       try {
//         final settings = await SettingsHelper.getSettings();
//         return settings.isAttendanceUpdateAllowed();
//       } catch (e) {
//         // If settings can't be loaded, default to false (block updates)
//         return false;
//       }
//     } else {
//       // Client: Check with server
//       try {
//         return await AttendanceSettingsApiService.isUpdateAllowed();
//       } catch (e) {
//         return false;
//       }
//     }
//   }

// // Add this method
//   void _showDebugDialog() async {
//     try {
//       final debugInfo =
//           await AttendanceSettingsApiService.debugGetAllSettings();

//       final buffer = StringBuffer();
//       buffer.writeln('=== DEBUG INFO ===');
//       buffer.writeln('User: ${_loggedInUser?.username}');
//       buffer.writeln('Role: ${_loggedInUser?.role}');
//       buffer.writeln('Is Admin: $_isAdmin');
//       buffer.writeln('Is Teacher: $_isTeacher');
//       buffer.writeln('Assigned Classes: $_teacherClasses');
//       buffer.writeln('Filtered Classes: $_filteredClasses');
//       buffer.writeln('All Classes: $_classes');
//       buffer.writeln('---');
//       buffer.writeln('Settings Count: ${debugInfo['count'] ?? 0}');
//       buffer.writeln('Box Name: ${debugInfo['boxName'] ?? 'Unknown'}');
//       buffer.writeln('Box Length: ${debugInfo['boxLength'] ?? 0}');
//       buffer.writeln('Keys: ${debugInfo['keys'] ?? []}');
//       buffer.writeln('\n=== Settings ===');

//       final settingsList = debugInfo['settings'] as List? ?? [];
//       for (var s in settingsList) {
//         buffer.writeln('ID: ${s['id']}');
//         buffer.writeln('allowAttendanceUpdate: ${s['allowAttendanceUpdate']}');
//         buffer.writeln('lastUpdated: ${s['lastUpdated']}');
//         buffer.writeln('modifiedFields: ${s['modifiedFields']}');
//         buffer.writeln('---');
//       }

//       showDialog(
//         context: context,
//         builder: (ctx) => AlertDialog(
//           title: const Text('🐛 Debug Settings'),
//           content: Container(
//             width: double.maxFinite,
//             child: SingleChildScrollView(
//               child: Text(
//                 buffer.toString(),
//                 style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
//               ),
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () async {
//                 final success =
//                     await AttendanceSettingsApiService.debugResetSettings();
//                 Navigator.pop(ctx);
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text(success
//                         ? '✅ Settings reset successfully'
//                         : '❌ Failed to reset settings'),
//                     backgroundColor: success ? Colors.green : Colors.red,
//                   ),
//                 );
//               },
//               child: const Text('Reset Settings'),
//             ),
//             TextButton(
//               onPressed: () => Navigator.pop(ctx),
//               child: const Text('Close'),
//             ),
//           ],
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('❌ Error: $e')),
//       );
//     }
//   }

//   // ✅ Handle the attendance marking with update check
//   Future<void> _markAttendance() async {
//     if (_isSubmitting) return;

//     if (_students.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('No students to mark attendance for')),
//       );
//       return;
//     }

//     setState(() {
//       _isSubmitting = true;
//     });

//     try {
//       if (_selectedClass == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Please select a class')),
//         );
//         setState(() => _isSubmitting = false);
//         return;
//       }

//       final date = DateTime(
//         _selectedDate.year,
//         _selectedDate.month,
//         _selectedDate.day,
//       );

//       final currentTerm = getActiveTerm();
//       if (currentTerm == null) {
//         _showDialog('No active term found.');
//         setState(() => _isSubmitting = false);
//         return;
//       }

//       final termId = currentTerm.termId!;

//       // ✅ Check if already marked
//       bool alreadyMarked =
//           await _isAttendanceAlreadyMarkedForClass(_selectedClass!, date);

//       if (alreadyMarked) {
//         // ✅ Check if updates are allowed
//         final updateAllowed = await _checkIfUpdateAllowed();

//         if (!updateAllowed) {
//           // ❌ Updates are blocked
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text(
//                   '❌ Attendance updates are currently blocked by the host.'),
//               backgroundColor: Colors.red,
//               duration: Duration(seconds: 4),
//             ),
//           );
//           setState(() => _isSubmitting = false);
//           return;
//         }

//         // ✅ Show update confirmation dialog
//         final confirm = await showDialog<bool>(
//           context: context,
//           builder: (ctx) => AlertDialog(
//             title: const Text('Attendance Already Marked'),
//             content: const Text(
//                 'Attendance has already been marked for this class on this date.\n'
//                 'Do you want to update the records?'),
//             actions: [
//               IconButton(
//                 icon: const Icon(Icons.bug_report, color: Colors.yellow),
//                 onPressed: _showDebugDialog,
//                 tooltip: 'Debug Settings',
//               ),
//               TextButton(
//                 onPressed: () => Navigator.pop(ctx, false),
//                 child: const Text('Cancel'),
//               ),
//               TextButton(
//                 onPressed: () => Navigator.pop(ctx, true),
//                 style: TextButton.styleFrom(
//                   backgroundColor: Colors.orange,
//                   foregroundColor: Colors.white,
//                 ),
//                 child: const Text('Update'),
//               ),
//             ],
//           ),
//         );

//         if (confirm != true) {
//           setState(() => _isSubmitting = false);
//           return;
//         }
//       }

//       // Apply attendance based on device role
//       if (_role == DeviceRole.host) {
//         // HOST: Save locally
//         for (final student in _students) {
//           student.presentDates.remove(date);
//           student.absentDates.remove(date);
//           await _applyAttendanceLocally(student, date, student.isPresent);
//         }

//         final action = alreadyMarked ? 'Updated' : 'Marked';
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//                 '✅ Attendance $action successfully (${_presentCount} present, ${_absentCount} absent)'),
//             backgroundColor: Colors.green,
//           ),
//         );
//       } else {
//         // CLIENT: Sync to host via API
//         try {
//           final result = await StudentRegisterBulkApiService.markBulkRegister(
//             className: _selectedClass!,
//             termId: termId,
//             date: date,
//             students: _students,
//           );

//           final action = result['updated'] == true ? 'Updated' : 'Marked';
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                   '✅ Attendance $action successfully (${_presentCount} present, ${_absentCount} absent)'),
//               backgroundColor: Colors.green,
//             ),
//           );
//         } catch (e) {
//           if (e is AttendanceConflictException) {
//             // ✅ Handle conflict exception
//             if (e.allowUpdate) {
//               // The server says updates are allowed, but we already checked
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(
//                   content: Text(
//                       'Updates are allowed but there was a conflict. Please try again.'),
//                   backgroundColor: Colors.orange,
//                 ),
//               );
//             } else {
//               // ❌ Updates are blocked by the host
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(
//                   content: Text('❌ ${e.message}'),
//                   backgroundColor: Colors.red,
//                   duration: const Duration(seconds: 4),
//                 ),
//               );
//             }
//           } else {
//             // Re-throw other errors
//             rethrow;
//           }
//           setState(() => _isSubmitting = false);
//           return;
//         }
//       }

//       // Refresh the student list
//       if (_selectedClass != null) {
//         await _loadStudentsForClass(_selectedClass!);
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('❌ Error marking attendance: $e')),
//       );
//     } finally {
//       setState(() => _isSubmitting = false);
//     }
//   }

//   Future<void> _applyAttendanceLocally(
//     Student student,
//     DateTime date,
//     bool isPresent,
//   ) async {
//     // ✅ Track modified fields
//     List<String> modifiedFields = [];

//     if (isPresent) {
//       if (!student.presentDates.contains(date)) {
//         student.presentDates.add(date);
//         modifiedFields.add('presentDates');
//       }
//       if (student.absentDates.contains(date)) {
//         student.absentDates.remove(date);
//         if (!modifiedFields.contains('absentDates')) {
//           modifiedFields.add('absentDates');
//         }
//       }
//     } else {
//       if (!student.absentDates.contains(date)) {
//         student.absentDates.add(date);
//         modifiedFields.add('absentDates');
//       }
//       if (student.presentDates.contains(date)) {
//         student.presentDates.remove(date);
//         if (!modifiedFields.contains('presentDates')) {
//           modifiedFields.add('presentDates');
//         }
//       }
//     }

//     // ✅ Only update if there were actual changes
//     if (modifiedFields.isNotEmpty) {
//       // ✅ Set sync fields
//       student.syncStatus = false; // Mark as unsynced
//       student.lastModified = DateTime.now();
//       student.operationType = 'update';

//       // ✅ Merge with existing modified fields
//       if (student.modifiedFields == null) {
//         student.modifiedFields = modifiedFields;
//       } else {
//         for (var field in modifiedFields) {
//           if (!student.modifiedFields!.contains(field)) {
//             student.modifiedFields!.add(field);
//           }
//         }
//       }

//       await student.save();
//       print(
//           '✅ Student ${student.studentIdNumber} - Attendance updated, ready for sync');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     // ✅ Determine if user has access to any classes
//     final bool hasClassAccess =
//         _isAdmin || (_isTeacher && _filteredClasses.isNotEmpty);

//     return Scaffold(
//       appBar: const CustomAppBar(title: 'Mark Attendance'),
//       body: Center(
//         child: Container(
//           constraints: const BoxConstraints(maxWidth: 600),
//           padding: const EdgeInsets.all(16.0),
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: SingleChildScrollView(
//               scrollDirection: Axis.vertical,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // ✅ User Role Indicator
//                   Container(
//                     padding:
//                         const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                     decoration: BoxDecoration(
//                       color: _isAdmin
//                           ? Colors.blue.shade50
//                           : _isTeacher
//                               ? Colors.green.shade50
//                               : Colors.grey.shade50,
//                       borderRadius: BorderRadius.circular(8),
//                       border: Border.all(
//                         color: _isAdmin
//                             ? Colors.blue.shade300
//                             : _isTeacher
//                                 ? Colors.green.shade300
//                                 : Colors.grey.shade300,
//                       ),
//                     ),
//                     child: Row(
//                       children: [
//                         Icon(
//                           _isAdmin
//                               ? Icons.admin_panel_settings
//                               : _isTeacher
//                                   ? Icons.school
//                                   : Icons.person,
//                           color: _isAdmin
//                               ? Colors.blue.shade700
//                               : _isTeacher
//                                   ? Colors.green.shade700
//                                   : Colors.grey.shade700,
//                           size: 20,
//                         ),
//                         const SizedBox(width: 8),
//                         Expanded(
//                           child: Text(
//                             _isAdmin
//                                 ? '🔑 Administrator - Full Access'
//                                 : _isTeacher
//                                     ? '👨‍🏫 Teacher - ${_filteredClasses.length} classes assigned'
//                                     : '👤 ${_loggedInUser?.role ?? 'User'} - No class access',
//                             style: TextStyle(
//                               color: _isAdmin
//                                   ? Colors.blue.shade700
//                                   : _isTeacher
//                                       ? Colors.green.shade700
//                                       : Colors.grey.shade700,
//                               fontSize: 14,
//                               fontWeight: _isAdmin || _isTeacher
//                                   ? FontWeight.bold
//                                   : FontWeight.normal,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 16),

//                   // ✅ Host Settings Toggle (only visible to host)
//                   if (_role == DeviceRole.host) ...[
//                     Card(
//                       color: _settings?.allowAttendanceUpdate == true
//                           ? Colors.green.shade50
//                           : Colors.red.shade50,
//                       child: Padding(
//                         padding: const EdgeInsets.all(12.0),
//                         child: Row(
//                           children: [
//                             Icon(
//                               _settings?.allowAttendanceUpdate == true
//                                   ? Icons.check_circle
//                                   : Icons.block,
//                               color: _settings?.allowAttendanceUpdate == true
//                                   ? Colors.green
//                                   : Colors.red,
//                             ),
//                             const SizedBox(width: 12),
//                             Expanded(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     'Client Update Permission',
//                                     style: TextStyle(
//                                       fontWeight: FontWeight.bold,
//                                       color: _settings?.allowAttendanceUpdate ==
//                                               true
//                                           ? Colors.green.shade700
//                                           : Colors.red.shade700,
//                                     ),
//                                   ),
//                                   Text(
//                                     _settings?.allowAttendanceUpdate == true
//                                         ? 'Clients can update existing attendance records'
//                                         : 'Clients cannot update existing attendance records',
//                                     style: TextStyle(
//                                       fontSize: 12,
//                                       color: _settings?.allowAttendanceUpdate ==
//                                               true
//                                           ? Colors.green.shade600
//                                           : Colors.red.shade600,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             Switch(
//                               value: _settings?.allowAttendanceUpdate ?? false,
//                               onChanged: _isLoadingSettings
//                                   ? null
//                                   : _toggleAttendanceUpdate,
//                               activeColor: Colors.green,
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                   ],

//                   // ✅ No access message for non-admin/non-teacher or teacher with no classes
//                   if (!hasClassAccess) ...[
//                     Container(
//                       padding: const EdgeInsets.all(20),
//                       decoration: BoxDecoration(
//                         color: Colors.orange.shade50,
//                         borderRadius: BorderRadius.circular(12),
//                         border: Border.all(color: Colors.orange.shade300),
//                       ),
//                       child: Column(
//                         children: [
//                           Icon(
//                             Icons.lock_outline,
//                             size: 48,
//                             color: Colors.orange.shade700,
//                           ),
//                           const SizedBox(height: 12),
//                           Text(
//                             _isTeacher
//                                 ? 'You have no classes assigned. Please contact the administrator.'
//                                 : 'You do not have permission to mark attendance.',
//                             style: TextStyle(
//                               fontSize: 16,
//                               color: Colors.orange.shade700,
//                             ),
//                             textAlign: TextAlign.center,
//                           ),
//                           const SizedBox(height: 8),
//                           Text(
//                             'Only administrators and teachers with assigned classes can mark attendance.',
//                             style: TextStyle(
//                               fontSize: 14,
//                               color: Colors.orange.shade600,
//                             ),
//                             textAlign: TextAlign.center,
//                           ),
//                         ],
//                       ),
//                     ),
//                   ] else ...[
//                     // ✅ Class selection with loading overlay
//                     Stack(
//                       children: [
//                         Column(
//                           children: [
//                             DropdownButtonFormField<String>(
//                               value: _selectedClass,
//                               hint: Text(_filteredClasses.isEmpty
//                                   ? 'No classes available'
//                                   : 'Select Class'),
//                               items: _filteredClasses.map((className) {
//                                 return DropdownMenuItem<String>(
//                                   value: className,
//                                   child: Text(className),
//                                 );
//                               }).toList(),
//                               decoration: const InputDecoration(
//                                 labelText: 'Select Class',
//                                 border: OutlineInputBorder(),
//                               ),
//                               onChanged: (_isLoadingClasses ||
//                                       _isLoading ||
//                                       _filteredClasses.isEmpty)
//                                   ? null
//                                   : (value) {
//                                       setState(() {
//                                         _selectedClass = value;
//                                       });
//                                       if (value != null) {
//                                         _loadStudentsForClass(value);
//                                       }
//                                     },
//                             ),
//                             const SizedBox(height: 16),
//                             TextFormField(
//                               controller: TextEditingController(
//                                 text: DateFormat('EEEE, d MMMM yyyy')
//                                     .format(_selectedDate),
//                               ),
//                               decoration: const InputDecoration(
//                                 labelText: 'Date',
//                                 border: OutlineInputBorder(),
//                               ),
//                               readOnly: true,
//                               onTap: _isLoading || _isLoadingClasses
//                                   ? null
//                                   : () async {
//                                       DateTime? pickedDate =
//                                           await showDatePicker(
//                                         context: context,
//                                         initialDate: _selectedDate,
//                                         firstDate: DateTime(2000),
//                                         lastDate: DateTime(2101),
//                                       );
//                                       if (pickedDate != null) {
//                                         setState(() {
//                                           _selectedDate = pickedDate;
//                                         });
//                                         // Reload students when date changes
//                                         if (_selectedClass != null) {
//                                           _loadStudentsForClass(
//                                               _selectedClass!);
//                                         }
//                                       }
//                                     },
//                             ),
//                           ],
//                         ),
//                         // ✅ Loading overlay for class selection
//                         if (_isLoadingClasses)
//                           Container(
//                             height: 80,
//                             decoration: BoxDecoration(
//                               color: Colors.white.withOpacity(0.7),
//                               borderRadius: BorderRadius.circular(8),
//                             ),
//                             child: const Center(
//                               child: Row(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   SizedBox(
//                                     width: 20,
//                                     height: 20,
//                                     child: CircularProgressIndicator(
//                                       strokeWidth: 2,
//                                     ),
//                                   ),
//                                   SizedBox(width: 12),
//                                   Text('Loading classes...'),
//                                 ],
//                               ),
//                             ),
//                           ),
//                       ],
//                     ),
//                     const SizedBox(height: 16),

//                     // ✅ Loading indicator for students
//                     if (_isLoading)
//                       const Center(
//                         child: Padding(
//                           padding: EdgeInsets.all(32.0),
//                           child: Column(
//                             children: [
//                               CircularProgressIndicator(),
//                               SizedBox(height: 16),
//                               Text('Loading students...'),
//                             ],
//                           ),
//                         ),
//                       )
//                     else if (_students.isEmpty && _selectedClass != null)
//                       const Center(
//                         child: Padding(
//                           padding: EdgeInsets.all(32.0),
//                           child: Text('No students found for this class'),
//                         ),
//                       )
//                     else if (_students.isNotEmpty)
//                       Column(
//                         children: [
//                           // ✅ Select/Unselect All header with counts
//                           Card(
//                             color: Colors.grey.shade100,
//                             child: Padding(
//                               padding: const EdgeInsets.symmetric(
//                                   horizontal: 16, vertical: 12),
//                               child: Row(
//                                 children: [
//                                   Checkbox(
//                                     value: _allSelected,
//                                     onChanged:
//                                         _isSubmitting ? null : _toggleSelectAll,
//                                     tristate: _anySelected && !_allSelected,
//                                   ),
//                                   const Text(
//                                     'Select All',
//                                     style: TextStyle(
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                   const Spacer(),
//                                   // ✅ Show present/absent counts
//                                   Container(
//                                     padding: const EdgeInsets.symmetric(
//                                         horizontal: 12, vertical: 4),
//                                     decoration: BoxDecoration(
//                                       color: Colors.green.shade50,
//                                       borderRadius: BorderRadius.circular(12),
//                                     ),
//                                     child: Text(
//                                       'Present: $_presentCount',
//                                       style: TextStyle(
//                                         color: Colors.green.shade700,
//                                         fontWeight: FontWeight.w600,
//                                         fontSize: 12,
//                                       ),
//                                     ),
//                                   ),
//                                   const SizedBox(width: 8),
//                                   Container(
//                                     padding: const EdgeInsets.symmetric(
//                                         horizontal: 12, vertical: 4),
//                                     decoration: BoxDecoration(
//                                       color: Colors.red.shade50,
//                                       borderRadius: BorderRadius.circular(12),
//                                     ),
//                                     child: Text(
//                                       'Absent: $_absentCount',
//                                       style: TextStyle(
//                                         color: Colors.red.shade700,
//                                         fontWeight: FontWeight.w600,
//                                         fontSize: 12,
//                                       ),
//                                     ),
//                                   ),
//                                   const SizedBox(width: 8),
//                                   Container(
//                                     padding: const EdgeInsets.symmetric(
//                                         horizontal: 12, vertical: 4),
//                                     decoration: BoxDecoration(
//                                       color: Colors.blue.shade50,
//                                       borderRadius: BorderRadius.circular(12),
//                                     ),
//                                     child: Text(
//                                       'Total: ${_students.length}',
//                                       style: TextStyle(
//                                         color: Colors.blue.shade700,
//                                         fontWeight: FontWeight.w600,
//                                         fontSize: 12,
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                           const SizedBox(height: 8),

//                           // ✅ Student list
//                           ListView.builder(
//                             shrinkWrap: true,
//                             physics: const NeverScrollableScrollPhysics(),
//                             itemCount: _students.length,
//                             itemBuilder: (context, index) {
//                               final student = _students[index];
//                               return Card(
//                                 margin: const EdgeInsets.symmetric(vertical: 4),
//                                 child: ListTile(
//                                   title: Text(
//                                     "${student.surname}, ${student.name}",
//                                     style: const TextStyle(
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                   subtitle: Row(
//                                     children: [
//                                       Text(student.class_),
//                                       const Spacer(),
//                                       // ✅ Show if already marked
//                                       _isStudentMarked(student)
//                                           ? Container(
//                                               padding:
//                                                   const EdgeInsets.symmetric(
//                                                       horizontal: 8,
//                                                       vertical: 2),
//                                               decoration: BoxDecoration(
//                                                 color: Colors.grey.shade200,
//                                                 borderRadius:
//                                                     BorderRadius.circular(10),
//                                               ),
//                                               child: Text(
//                                                 'Marked',
//                                                 style: TextStyle(
//                                                   color: Colors.grey.shade600,
//                                                   fontSize: 10,
//                                                 ),
//                                               ),
//                                             )
//                                           : const SizedBox(),
//                                     ],
//                                   ),
//                                   trailing: Row(
//                                     mainAxisSize: MainAxisSize.min,
//                                     children: [
//                                       // ✅ Present checkbox
//                                       Tooltip(
//                                         message: 'Mark Present',
//                                         child: Checkbox(
//                                           value: student.isPresent,
//                                           onChanged: _isSubmitting
//                                               ? null
//                                               : (value) {
//                                                   setState(() {
//                                                     student.isPresent =
//                                                         value ?? false;
//                                                   });
//                                                 },
//                                           activeColor: Colors.green,
//                                         ),
//                                       ),
//                                       // ✅ Absent button
//                                       Tooltip(
//                                         message: 'Mark Absent',
//                                         child: IconButton(
//                                           icon: const Icon(Icons.close,
//                                               color: Colors.red),
//                                           onPressed: _isSubmitting
//                                               ? null
//                                               : () {
//                                                   setState(() {
//                                                     student.isPresent = false;
//                                                   });
//                                                 },
//                                           iconSize: 20,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               );
//                             },
//                           ),
//                         ],
//                       ),
//                     const SizedBox(height: 16),

//                     // ✅ Submit button with loading state
//                     ElevatedButton(
//                       onPressed: (_students.isEmpty ||
//                               _isSubmitting ||
//                               _isLoading ||
//                               _selectedClass == null)
//                           ? null
//                           : _markAttendance,
//                       style: ElevatedButton.styleFrom(
//                         minimumSize: const Size(double.infinity, 50),
//                       ),
//                       child: _isSubmitting
//                           ? const Row(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 SizedBox(
//                                   width: 20,
//                                   height: 20,
//                                   child: CircularProgressIndicator(
//                                     color: Colors.white,
//                                     strokeWidth: 2,
//                                   ),
//                                 ),
//                                 SizedBox(width: 12),
//                                 Text('Submitting...'),
//                               ],
//                             )
//                           : const Text('Mark Attendance'),
//                     ),
//                   ],
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   // ✅ Helper to check if a student is already marked for the selected date
//   bool _isStudentMarked(Student student) {
//     final date = DateTime(
//       _selectedDate.year,
//       _selectedDate.month,
//       _selectedDate.day,
//     );
//     return student.presentDates.contains(date) ||
//         student.absentDates.contains(date);
//   }

//   Future<void> _showDialog(String message) async {
//     await showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text("Attendance Feedback"),
//         content: Text(message),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(ctx).pop(),
//             child: const Text("OK"),
//           ),
//         ],
//       ),
//     );
//   }
// }
