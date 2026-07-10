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
import 'package:zitf_system/registers/class_register_detail.dart';

class _ClassSummary {
  final String className;
  final int totalStudents;
  final int presentCount;
  final int absentCount;

  _ClassSummary({
    required this.className,
    required this.totalStudents,
    required this.presentCount,
    required this.absentCount,
  });

  bool get wasMarked => presentCount + absentCount > 0;
}

class ViewAttendanceScreenFilter extends StatefulWidget {
  @override
  _ViewAttendanceScreenFilterState createState() =>
      _ViewAttendanceScreenFilterState();
}

class _ViewAttendanceScreenFilterState
    extends State<ViewAttendanceScreenFilter> {
  List<Student> _allStudents = [];
  List<String> _classes = [];
  bool _isLoading = true;

  // The date the class-by-class marked/not-marked summary is shown for.
  DateTime _summaryDate = DateTime.now();

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
    // Force a real event-loop turn before the (potentially large,
    // synchronous-feeling) work below runs. SharedPreferences.getInstance()
    // and Hive box reads often resolve almost instantly once warm (e.g.
    // after an earlier screen already touched them this session), which
    // can let the whole chain run in one microtask burst and starve the
    // renderer - so the loading spinner below is requested but never
    // actually painted before the screen appears to freeze.
    await Future.delayed(const Duration(milliseconds: 50));

    await _loadDeviceRole(); // ✅ Add this

    await _loadLoggedInUser();
    await _loadStudents();
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

    } catch (e) {
      debugPrint('❌ Error loading students: $e');
      _allStudents = [];
      _classes = ['All'];
    }
  }

  // ✅ Class-by-class marked/not-marked summary for the selected date -
  // the main view's primary content, instead of one long table clustering
  // every student across every class.
  List<_ClassSummary> _computeClassSummaries() {
    final classNames = _classes.where((c) => c != 'All').toList()..sort();

    return classNames.map((className) {
      final classStudents = _allStudents
          .where((s) => s.class_.toLowerCase() == className.toLowerCase())
          .toList();
      final presentCount = classStudents
          .where((s) =>
              s.presentDates.any((d) => _isSameDay(d, _summaryDate)))
          .length;
      final absentCount = classStudents
          .where(
              (s) => s.absentDates.any((d) => _isSameDay(d, _summaryDate)))
          .length;

      return _ClassSummary(
        className: className,
        totalStudents: classStudents.length,
        presentCount: presentCount,
        absentCount: absentCount,
      );
    }).toList();
  }

  void _openClassDetail(String className) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClassRegisterDetailScreen(
          className: className,
          allStudents: _allStudents,
          isHost: _isHost,
          isAdmin: _isAdmin,
          initialDate: _summaryDate,
        ),
      ),
    );
  }

  Widget _buildClassSummaryCard(_ClassSummary summary) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(summary.className,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${summary.totalStudents} students'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: summary.wasMarked ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  summary.wasMarked ? Colors.green.shade300 : Colors.red.shade300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                summary.wasMarked ? Icons.check_circle : Icons.error_outline,
                color: summary.wasMarked
                    ? Colors.green.shade700
                    : Colors.red.shade700,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                summary.wasMarked
                    ? '${summary.presentCount}P / ${summary.absentCount}A'
                    : 'Not Marked',
                style: TextStyle(
                  color: summary.wasMarked
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        onTap: () => _openClassDetail(summary.className),
      ),
    );
  }

  // Compares calendar day only, ignoring any time component.
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ✅ Manual sync students from host
  Future<void> _syncStudents() async {
    setState(() => _isSyncing = true);

    try {
      final allStudents = await StudentRegisterFetchApi.fetchAllStudents();

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

      setState(() {});

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
        ],
        backgroundColor: const Color.fromARGB(255, 38, 140, 191),
        elevation: 4.0,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading attendance records...'),
                ],
              ),
            )
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
                    ] else if (_classes.where((c) => c != 'All').isEmpty) ...[
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
                      // ✅ Date selector for the summary below
                      Row(
                        children: [
                          const Icon(Icons.event, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          const Text('Register status for: ',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey)),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _summaryDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2101),
                              );
                              if (picked != null) {
                                setState(() => _summaryDate = picked);
                              }
                            },
                            child: Text(
                              DateFormat('EEEE, d MMMM yyyy')
                                  .format(_summaryDate),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (!_isSameDay(_summaryDate, DateTime.now()))
                            TextButton(
                              onPressed: () => setState(
                                  () => _summaryDate = DateTime.now()),
                              child: const Text('Today'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // ✅ Summary stats for the selected date
                      Expanded(
                          child: Builder(builder: (context) {
                        final summaries = _computeClassSummaries();
                        final markedCount =
                            summaries.where((s) => s.wasMarked).length;
                        final notMarkedCount =
                            summaries.length - markedCount;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatItem('Classes Marked',
                                      markedCount, Colors.green),
                                  _buildStatItem('Classes Not Marked',
                                      notMarkedCount, Colors.red),
                                  _buildStatItem(
                                      'Total Present',
                                      summaries.fold(
                                          0, (sum, s) => sum + s.presentCount),
                                      Colors.green),
                                  _buildStatItem(
                                      'Total Absent',
                                      summaries.fold(
                                          0, (sum, s) => sum + s.absentCount),
                                      Colors.red),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: ListView.builder(
                                itemCount: summaries.length,
                                itemBuilder: (context, index) =>
                                    _buildClassSummaryCard(summaries[index]),
                              ),
                            ),
                          ],
                        );
                      })),
                    ],
                  ],
                ),
              ),
            ),
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
}
