import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/admin/forgotten.dart';
import 'package:zitf_system/admin/login_screen.dart';
import 'package:zitf_system/auth/crud_auth/crud_auth_home.dart';
import 'package:zitf_system/auth/crud_auth/dev_login.dart';
import 'package:zitf_system/auth/crud_auth/secretary/view_secretary.dart';
import 'package:zitf_system/auth/crud_auth/view_admin_auth.dart';
import 'package:zitf_system/auth/update_auth.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/database/accounting_module_models/account_type.dart';
import 'package:zitf_system/database/accounting_module_models/assets.dart';
import 'package:zitf_system/database/auto_logout_timer/auto_logou_timer.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/exceptional_students/exceptional_students.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/payment_receipts_log.dart';
import 'package:zitf_system/database/projects/project_daily_activity_model.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/database/projects/project_student_payment_model.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/database/syncConfigs/syncConfig.dart';
import 'package:zitf_system/database/teacher_payment_purpose.dart';
import 'package:zitf_system/database/teacher_payments.dart';
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/database/withdrawalshome.dart';
import 'package:zitf_system/admin/home_screen.dart';
import 'package:zitf_system/export_import_backup_data/export_import_home.dart';
import 'package:zitf_system/flutter_codes_for_a_restful_api/data_sync/classes_final.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/projects/projects_home.dart';
import 'package:zitf_system/reusable_codes/auto_logout_user_when_app_in_background/auto_logout_user_when_app_in_background.dart';
import 'package:zitf_system/server/alfred_server.dart';
import 'package:zitf_system/server/save_Ip_To_Shared_prefs.dart';
import 'package:zitf_system/server/save_gateway_to_shared_prefs.dart';
import 'package:zitf_system/settings/developer_options/developer_home.dart';
import 'package:zitf_system/settings/developer_options/domainConfigs/device_role_settings.dart';
import 'package:zitf_system/settings/developer_options/domainConfigs/ip_address_settings.dart';
import 'package:zitf_system/terms/term_switcher.dart';
import 'package:zitf_system/welcome/welcome_admin.dart';
import 'package:zitf_system/welcome/welcome_secretary.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

enum DeviceRole { host, client }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    await initHiveWithCustomPath();
  } else {
    await Hive.initFlutter();
  }
// Hive initialization for host
  try {
    await Hive.openBox('financial_position_box');
  } catch (e) {
    print("Error opening financial_position_box: $e");
  }

  Hive.registerAdapter(StudentAdapter());
  Hive.registerAdapter(ClassesAdapter());
  Hive.registerAdapter(WithdrawalAdapter());
  Hive.registerAdapter(PaymentPurposeAdapter());
  Hive.registerAdapter(TeacherPaymentsPurposesAdapter());
  Hive.registerAdapter(StudentPaymentAdapter());
  Hive.registerAdapter(TeacherPaymentAdapter());
  Hive.registerAdapter(UserAdapter());
  Hive.registerAdapter(TeachersAdapter());
  Hive.registerAdapter(SchoolAdapter());
  Hive.registerAdapter(TermsAdapter());
  Hive.registerAdapter(AccountAdapter());
  Hive.registerAdapter(AssetAdapter());
  Hive.registerAdapter(ProjectAdapter());
  Hive.registerAdapter(ProjectItemAdapter());
  Hive.registerAdapter(DailyActivityAdapter());
  Hive.registerAdapter(ProjectStudentPaymentAdapter());
  Hive.registerAdapter(AutoLogoutSettingsAdapter());
  Hive.registerAdapter(DomainRecordAdapter());
  Hive.registerAdapter(ExceptionalStudentsAdapter());
  Hive.registerAdapter(PaymentLogAdapter());

  final prefs = await SharedPreferences.getInstance();
  final role = await getDeviceRole();

  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  if (role == null) {
    runApp(MaterialApp(home: RoleSelectionScreen(isLoggedIn: isLoggedIn)));
    return;
  }
  if (role == DeviceRole.host) {
    await HiveService.openAllBoxes();
    await startAlfredServer();
    saveLocalIpToPrefs();
// Start Alfred server
  }
  await HiveService.openAllBoxes();
  saveGatewayToPrefs();
  _initializeDefaultTerm();

  var userBox = Hive.box<User>('users');
  if (userBox.isEmpty) {
    var defaultAdminUser = User(
      username: 'SUDOMANOadmin',
      password: 'SUDOMANO@codedatapool@admin',
      role: 'admin',
      securityQuestions: ['good day', 'good year', 'good bank'],
      securityAnswers: ['SUDOMANO', '1961', 'STEWARD'],
      phone: '0773309607',
      id: 1,
      termId: 'defaultTermId',
      syncStatus: false,
      lastModified: DateTime.now(),
      operationType: 'create',
      userCode: 'admin',
    );
    userBox.add(defaultAdminUser);
  }

  // Initialize SharedPreferences with developer credentials
  await prefs.setString('developerUsername', 'SUDOMANOdeveloper');
  await prefs.setString('developerPassword', 'SUDOMANO@codedatapool@developer');

  runApp(MyApp(role: role, isLoggedIn: isLoggedIn));
}

class HiveService {
  static Future<void> openAllBoxes() async {
    await Hive.openBox<DomainRecord>('domainBox');
    await Hive.openBox<TeacherPaymentsPurposes>('teacher_payments_purposes');
    await Hive.openBox<PaymentPurpose>('payment_purposes');
    await Hive.openBox<Classes>('classes');
    await Hive.openBox<StudentPayment>('student_payments');
    await Hive.openBox<TeacherPayment>('teacher_payments');
    await Hive.openBox<Student>('students');
    await Hive.openBox<Withdrawal>('withdrawals');
    await Hive.openBox<User>('users');
    await Hive.openBox<Teachers>('teachers');
    await Hive.openBox<School>('school');
    await Hive.openBox<Terms>('terms');
    await Hive.openBox<Account>('account');
    await Hive.openBox<Asset>('asset');
    await Hive.openBox<Project>('projects');
    await Hive.openBox<ProjectItem>('projectItems');
    await Hive.openBox<DailyActivity>('dailyActivities');
    await Hive.openBox<ProjectStudentPayment>('projectStudentPayments');
    await Hive.openBox<ExceptionalStudents>('exceptionalStudentsBox');
    await Hive.openBox('financial_box');
    await Hive.openBox<PaymentLog>('payment_log');
  }
}

class RoleSelectionScreen extends StatefulWidget {
  final bool isLoggedIn;

  const RoleSelectionScreen({Key? key, required this.isLoggedIn})
      : super(key: key);

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  DeviceRole? _selectedRole;

  @override
  void initState() {
    super.initState();
    _loadSelectedRole();
  }

  Future<void> _loadSelectedRole() async {
    _selectedRole = await getDeviceRole();
    setState(() {});
  }

  void _showRoleInfoDialog(DeviceRole role) {
    String roleName = role == DeviceRole.host ? "HOST" : "CLIENT";

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Role Already Selected"),
        content: Text(
          "This device is already set as $roleName.\n\n"
          "You can change the device role later from Developer Settings.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleButton({
    required IconData icon,
    required Color color,
    required String label,
    required DeviceRole role,
  }) {
    final bool isAnyRoleSelected = _selectedRole != null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton.icon(
            onPressed: () async {
              await setDeviceRole(role);
              if (role == DeviceRole.host || role == DeviceRole.client) {
                await HiveService.openAllBoxes();
              }
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        MyApp(role: role, isLoggedIn: widget.isLoggedIn)),
              );
            },
            icon: Icon(icon, size: 28),
            label: Text(label, style: const TextStyle(fontSize: 18)),
            style: ElevatedButton.styleFrom(
              backgroundColor: isAnyRoleSelected ? Colors.grey.shade400 : color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            onPressed: _selectedRole != null
                ? () async {
                    debugPrint('Login button pressed');
                    debugPrint('Selected Role: $_selectedRole');
                    debugPrint(
                        'Is Logged In: ${widget.isLoggedIn}'); // Restart the app to ensure Hive boxes are properly initialized
                    runApp(MyApp(
                      role: _selectedRole!,
                      isLoggedIn: widget.isLoggedIn,
                    ));
                    debugPrint('runApp(MyApp) called successfully');
                  }
                : null,
            icon: const Icon(Icons.login),
            label: const Text("Proceed to Login"),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedRole != null
                  ? Colors.green.shade700
                  : Colors.grey.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.devices, size: 80, color: Colors.indigo),
              const SizedBox(height: 20),
              const Text(
                "Select Device Role",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Choose whether this device will act as a host or a client in your local network setup.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 40),
              _buildRoleButton(
                icon: Icons.storage_rounded,
                color: Colors.green.shade700,
                label: "This is the HOST",
                role: DeviceRole.host,
              ),
              const SizedBox(height: 20),
              _buildRoleButton(
                icon: Icons.phonelink,
                color: Colors.blue.shade800,
                label: "This is a CLIENT",
                role: DeviceRole.client,
              ),
              const SizedBox(height: 30),
              _buildLoginButton(),
              const SizedBox(height: 20),
              const Text(
                "You can change this later from Developer Settings.",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> initializeHiveForRole(DeviceRole role) async {
  if (role == DeviceRole.client) return; // skip Hive

  await _initializeDefaultTerm();

  final userBox = Hive.box<User>('users');
  if (userBox.isEmpty) {
    var defaultAdminUser = User(
      username: 'SUDOMANOadmin',
      password: 'SUDOMANO@codedatapool@admin',
      role: 'admin',
      securityQuestions: ['good day', 'good year', 'good bank'],
      securityAnswers: ['SUDOMANO', '1961', 'STEWARD'],
      phone: '0773309607',
      id: 1,
      termId: 'defaultTermId',
      syncStatus: false,
      lastModified: DateTime.now(),
      operationType: 'create',
      userCode: 'admin',
    );
    userBox.add(defaultAdminUser);
  }
}

Future<void> setDeviceRole(DeviceRole role) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('device_role', role.name);
}

Future<DeviceRole?> getDeviceRole() async {
  final prefs = await SharedPreferences.getInstance();
  final roleString = prefs.getString('device_role');

  if (roleString == null) return null;

  return DeviceRole.values.firstWhere(
    (role) => role.name == roleString,
    orElse: () => DeviceRole.client,
  );
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;
  final DeviceRole role;

  const MyApp({Key? key, required this.isLoggedIn, required this.role})
      : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AutoLogoutManager _autoLogoutManager;

  @override
  void initState() {
    super.initState();
    _autoLogoutManager = AutoLogoutManager();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoLogoutManager.initialize(context);
    });
  }

  @override
  void dispose() {
    _autoLogoutManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _autoLogoutManager.resetInactivityTimer();
      },
      child: MaterialApp(
        navigatorKey: navigatorKey, // Use the global navigatorKey
        debugShowCheckedModeBanner: false,

        initialRoute: widget.isLoggedIn ? '/home' : '/login',
        routes: {
          '/login': (context) => LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/homedeveloper': (context) => ViewSecurityScreen(),
          '/forgot': (context) => ForgottenPasswordScreen(),
          '/admin': (context) => EditSecurityScreen(),
          '/sync': (context) => const ClassesFinal(),
          '/secretary': (context) => ViewSecretaryScreen(),
          '/developer': (context) => DeveloperLoginScreen(),
          '/devicesettings': (context) => const DeveloperRoleSettingsScreen(),
          '/ipsettings': (context) => const IpAddressSettings(),
          '/welcome': (context) => WelcomePage(),
          '/welcome1': (context) => WelcomePage1(),
          '/backup': (context) => const ExportImportHome(),
          '/profile': (context) => const AdminPanelScreen(),
          '/settings': (context) => const DeveloperHome(),
          '/projects': (context) => const ProjectsHome(),
          '/term_switch': (context) => TermSwitcher(),
        },
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        navigatorObservers: [
          RouteObserver<PageRoute>(),
        ],
        builder: (BuildContext context, Widget? child) {
          return PopScope(
            onBackPress: () async {
              bool shouldPop = true;

              if (widget.isLoggedIn) {
                shouldPop = await showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text("Logout"),
                      content: const Text("Do you want to logout?"),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(true);
                          },
                          child: const Text("Yes"),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(false);
                          },
                          child: const Text("No"),
                        ),
                      ],
                    );
                  },
                );
              }

              return shouldPop;
            },
            child: child ?? Container(),
          );
        },
      ),
    );
  }
}

void clearTeachersBox() async {
  var box = await Hive.openBox('teachers');
  await box.clear();
}

Future<void> _initializeDefaultTerm() async {
  var termsBox = await Hive.openBox<Terms>('terms');
  // Search for an open term

  var openedTerms = termsBox.values.where((term) => term.status == 'Opened');
  Terms? openedTerm = openedTerms.isNotEmpty ? openedTerms.first : null;

  if (termsBox.isEmpty) {
    // Terms box is empty, create a default term
    String defaultTermId = "defaultTermId";
    String defaultTermName = "Default Term";
    DateTime defaultStartDate = DateTime.now();
    int id = 1;

    Terms defaultTerm = Terms(
      id: id,
      termId: defaultTermId,
      termName: defaultTermName,
      startDate: defaultStartDate,
      isActive: false,
      status: 'Opened',
      operationType: 'create',
      syncStatus: false,
      lastModified: DateTime.now(),
    );

    // Set the global term ID

    // Save the default term in the box
    await termsBox.put(defaultTerm.termId, defaultTerm);
    globalTermId ??= defaultTermId;

    // Notify the user
  } else if (openedTerm != null) {
    // Found an opened term, assign its ID to the global term ID
    globalTermId = openedTerm.termId;
    print(
        "Found an opened term: ${openedTerm.termId}. Assigned as global term ID.");
  }
}

class PopScope extends StatelessWidget {
  final Widget child;
  final Future<bool> Function() onBackPress;

  PopScope({required this.child, required this.onBackPress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {}, // to prevent touch propagation
      child: WillPopScope(
        onWillPop: onBackPress,
        child: child,
      ),
    );
  }
}

Future<void> initHiveWithCustomPath() async {
  String exeName = Platform.resolvedExecutable
      .split(Platform.pathSeparator)
      .last
      .replaceAll('.exe', '');

  // Optional: use env or args instead of exe name
  final hivePath =
      p.join(Platform.environment['APPDATA'] ?? '.', 'Edutrek', exeName);

  final hiveDir = Directory(hivePath);
  if (!hiveDir.existsSync()) {
    hiveDir.createSync(recursive: true);
  }

  await Hive.initFlutter(hivePath);
  print("Hive initialized at: $hivePath");
}
