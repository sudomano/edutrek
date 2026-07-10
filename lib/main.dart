import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/admin/device_few_settings.dart';
import 'package:zitf_system/admin/forgotten.dart';
import 'package:zitf_system/admin/login_screen.dart';
import 'package:zitf_system/auth/crud_auth/crud_auth_home.dart';
import 'package:zitf_system/auth/crud_auth/dev_login.dart';
import 'package:zitf_system/auth/crud_auth/developer_device_few_settings.dart';
import 'package:zitf_system/auth/crud_auth/secretary/view_secretary.dart';
import 'package:zitf_system/auth/crud_auth/view_admin_auth.dart';
import 'package:zitf_system/auth/update_auth.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/database/accounting_module_models/account_type.dart';
import 'package:zitf_system/database/accounting_module_models/assets.dart';
import 'package:zitf_system/database/auto_logout_timer/auto_logou_timer.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/exceptional_students/exceptional_students.dart';
import 'package:zitf_system/database/id_assignment_log.dart';
import 'package:zitf_system/database/id_client_reservation.dart';
import 'package:zitf_system/database/id_counter.dart';
import 'package:zitf_system/database/id_lock.dart';
import 'package:zitf_system/database/id_range.dart';
import 'package:zitf_system/database/id_sync_status.dart';
import 'package:zitf_system/database/network_utils/network_settings.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/payment_receipts_log.dart';
import 'package:zitf_system/database/projects/packaging_level.dart';
import 'package:zitf_system/database/projects/payment_method_model.dart';
import 'package:zitf_system/database/projects/project_daily_activity_model.dart';
import 'package:zitf_system/database/projects/project_item_batch_model.dart';
import 'package:zitf_system/database/projects/project_item_batch_sell_model.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/project_item_price_model.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/database/projects/project_sale_transaction_model.dart';
import 'package:zitf_system/database/projects/reprint_project_receipt.dart';
import 'package:zitf_system/database/projects/stock_unit_type.dart';
import 'package:zitf_system/database/projects/unitbatching.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/database/settings.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/database/syncConfigs/syncConfig.dart';
import 'package:zitf_system/database/teacher_payment_purpose.dart';
import 'package:zitf_system/database/teacher_payments.dart';
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/database/withdrawalshome.dart';
import 'package:zitf_system/admin/home_screen.dart';
import 'package:zitf_system/entry_point/app_bootstrap_layer_1/hive_bootstrap.dart';
import 'package:zitf_system/entry_point/host_services_layer_4/host_bootstrap.dart';
import 'package:zitf_system/entry_point/host_services_layer_4/host_runner.dart';
import 'package:zitf_system/entry_point/host_services_layer_4/host_seed.dart';
import 'package:zitf_system/export_import_backup_data/export_import_home.dart';
import 'package:zitf_system/flutter_codes_for_a_restful_api/data_sync/classes_final.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/projects/projects_home.dart';
import 'package:zitf_system/reusable_codes/auto_logout_user_when_app_in_background/auto_logout_user_when_app_in_background.dart';
import 'package:zitf_system/server/save_gateway_to_shared_prefs.dart';
import 'package:zitf_system/services/payments_id_service.dart';

import 'package:zitf_system/settings/developer_options/developer_home.dart';
import 'package:zitf_system/settings/developer_options/domainConfigs/device_role_settings.dart';
import 'package:zitf_system/settings/developer_options/domainConfigs/ip_address_settings.dart';
import 'package:zitf_system/student_payments/id_service.dart.dart';
import 'package:zitf_system/terms/term_switcher.dart';
import 'package:zitf_system/welcome/welcome_admin.dart';
import 'package:zitf_system/welcome/welcome_secretary.dart';

import 'package:flutter/foundation.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Held for the app's entire lifetime as a single-instance guard - see
// main(). Must stay a top-level reference, not a local variable in main(),
// so it can't be garbage-collected (and the socket closed) once main()
// itself returns.
ServerSocket? _singleInstanceLock;

enum DeviceRole { host, client }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 🌐 WEB: skip device role selection completely
  if (kIsWeb) {
    await Hive.initFlutter();

    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    runApp(
      MyApp(
        role: DeviceRole.client, // implicit
        isLoggedIn: isLoggedIn,
      ),
    );
    return;
  }

  // Single-instance guard. Every box Hive opens below takes an exclusive
  // file lock (RandomAccessFile.lock()) that BLOCKS - it never throws -
  // when another process already holds it. That means a second launch of
  // this app used to hang forever inside HiveService.openHostOnlyBoxes(),
  // with runApp() never reached and no window ever created, silently
  // piling up as an invisible zombie process. A plain socket bind fails
  // fast instead of blocking, so it's used here purely as a fast-failing
  // lock, checked before any Hive initialization begins.
  try {
    _singleInstanceLock =
        await ServerSocket.bind(InternetAddress.loopbackIPv4, 47811);
  } catch (e) {
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'This app is already running.\nCheck your taskbar for the existing window.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
    ));
    return;
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
  Hive.registerAdapter(AutoLogoutSettingsAdapter());
  Hive.registerAdapter(DomainRecordAdapter());
  Hive.registerAdapter(ExceptionalStudentsAdapter());
  Hive.registerAdapter(PaymentLogAdapter());
  Hive.registerAdapter(ProductBatchAdapter());
  Hive.registerAdapter(BatchSellUnitAdapter());
  Hive.registerAdapter(ProjectItemPriceAdapter());
  Hive.registerAdapter(ProjectSaleTransactionAdapter());
  Hive.registerAdapter(BatchUnitAdapter());
  Hive.registerAdapter(StockUnitTypeAdapter());
  Hive.registerAdapter(PackagingLevelAdapter());
  Hive.registerAdapter(PaymentMethodAdapter());
  Hive.registerAdapter(ReceiptSnapshotAdapter());
  Hive.registerAdapter(NetworkSettingsAdapter());
  Hive.registerAdapter(SettingsAdapter()); // ✅ Register Settings adapter
  Hive.registerAdapter(IdCounterAdapter());
  Hive.registerAdapter(IdLockAdapter());
  Hive.registerAdapter(IdAssignmentLogAdapter());
  Hive.registerAdapter(ClientIdReservationAdapter());
  Hive.registerAdapter(IdRangeAdapter());
  Hive.registerAdapter(IdSyncStatusAdapter());
  final role = await getDeviceRole();

  if (role == null) {
    await Hive.initFlutter(); // temporary minimal init
    runApp(const MaterialApp(
      home: RoleSelectionScreen(isLoggedIn: false),
    ));
    return;
  }

  await loadLastTermId();

  await HiveBootstrap.initialize(role);
  if (role == DeviceRole.client) {
    print('🌐 CLIENT BOOTSTRAP: syncing network model...');

    await Hive.openBox<NetworkSettings>('network_settings_box');

    final ip = await saveGatewayToPrefs();

    print('🎯 CLIENT BOOTSTRAP host_ip: $ip');
  }

// Hive initialization for host
  try {
    await Hive.openBox('financial_position_box');
  } catch (e) {
    print("Error opening financial_position_box: $e");
  }

  final prefs = await SharedPreferences.getInstance();

  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  await HiveService.openCoreBoxes();

  if (role == DeviceRole.host) {
    await HiveService.openHostOnlyBoxes();
  }

  if (role == DeviceRole.host) {
    await HiveService.openHostOnlyBoxes();
    await HostSeed.run();
    try {
      await startHostIfSupported(() async {
        await HostBootstrap.start();
      });
    } catch (e) {
      // If this fails (e.g. port 8080 already held by another running
      // instance of this app), the app must still reach runApp() below -
      // otherwise the process hangs forever with no window ever created,
      // since the periodic cleanup timer registered in
      // openHostOnlyBoxes() keeps the event loop alive regardless.
      debugPrint(
          '❌ Host bootstrap failed (server may already be running elsewhere): $e');
    }
  }

  // Initialize SharedPreferences with developer credentials
  await prefs.setString('developerUsername', 'SUDOMANOdeveloper');
  await prefs.setString('developerPassword', 'SUDOMANO@codedatapool@developer');

  runApp(MyApp(role: role, isLoggedIn: isLoggedIn));
}

class HiveService {
  static Future<void> openCoreBoxes() async {
    await Hive.openBox<User>('users');
    await Hive.openBox<School>('school');
    await Hive.openBox<Terms>('terms');
  }

  static Future<void> openHostOnlyBoxes() async {
    await Hive.openBox<DomainRecord>('domainBox');
    await Hive.openBox<TeacherPaymentsPurposes>('teacher_payments_purposes');
    await Hive.openBox<PaymentPurpose>('payment_purposes');
    await Hive.openBox<Classes>('classes');
    await Hive.openBox<StudentPayment>('student_payments');
    await Hive.openBox<TeacherPayment>('teacher_payments');
    await Hive.openBox<Student>('students');
    await Hive.openBox<Withdrawal>('withdrawals');
    await Hive.openBox<Teachers>('teachers');

    await Hive.openBox<Account>('account');
    await Hive.openBox<Asset>('asset');
    await Hive.openBox<Project>('projects');
    await Hive.openBox<ProjectItem>('projectItems');
    await Hive.openBox<DailyActivity>('dailyActivities');
    await Hive.openBox<ExceptionalStudents>('exceptionalStudentsBox');
    await Hive.openBox('financial_box');
    await Hive.openBox<PaymentLog>('payment_log');

    await Hive.openBox<ProductBatch>('product_batches');
    await Hive.openBox<ProjectItemPrice>('project_item_prices');
    await Hive.openBox<BatchSellUnit>('batch_sell_units');
    await Hive.openBox<ProjectSaleTransaction>('project_sale_transactions');

    await Hive.openBox<BatchUnit>('batch_units');
    await Hive.openBox<PaymentMethod>('payment_methods');
    await Hive.openBox<ReceiptSnapshot>('receipt_snapshots');
    await Hive.openBox<NetworkSettings>('network_settings_box');
    await Hive.openBox<Settings>('settings'); // ✅ Open settings box
// Open ID service boxes
    await Hive.openBox<IdCounter>('id_counter');
    await Hive.openBox<IdLock>('id_lock');
    await Hive.openBox<IdAssignmentLog>('id_assignment_log');
    await IdService().initialize();

    // Start periodic cleanup
    Timer.periodic(const Duration(days: 1), (timer) {
      IdService().cleanupOldLogs();
    });
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
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MyApp(
                          role: _selectedRole!,
                          isLoggedIn: widget.isLoggedIn,
                        ),
                      ),
                      (route) => false,
                    );

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
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/homedeveloper': (context) => ViewSecurityScreen(),
          '/forgot': (context) => ForgottenPasswordScreen(),
          '/device_few_settings': (context) => const DeviceFewSettingsScreen(),
          '/developer_device_few_settings': (context) =>
              DeveloperDeviceFewSettingsScreen(),
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
          '/term_switch': (context) => const TermSwitcher(),
          // Add to your routes in main.dart
          '/id_service_settings': (context) => const IdServiceSettingsPage(),
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
