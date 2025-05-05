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
import 'package:zitf_system/database/payment_purpose.dart';
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
import 'package:zitf_system/reusable_codes/custom_drawers/custom_drawer_admin.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';
import 'package:zitf_system/settings/developer_options/developer_home.dart';
import 'package:zitf_system/welcome/welcome_admin.dart';
import 'package:zitf_system/welcome/welcome_secretary.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  try {
    await Hive.openBox('financial_position_box');
  } catch (e) {
    print("Error opening financial_position_box: $e");
  }

  // Initialize Hive for Flutter
  Hive.registerAdapter(StudentAdapter()); // Register the adapter
  Hive.registerAdapter(ClassesAdapter());
  Hive.registerAdapter(WithdrawalAdapter());
  Hive.registerAdapter(PaymentPurposeAdapter());
  Hive.registerAdapter(
      TeacherPaymentsPurposesAdapter()); // Register the adapter
  Hive.registerAdapter(StudentPaymentAdapter());
  Hive.registerAdapter(TeacherPaymentAdapter());
  Hive.registerAdapter(UserAdapter()); // Register the User adapter
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

  await Hive.openBox<DomainRecord>('domainBox');
  await Hive.openBox<TeacherPaymentsPurposes>('teacher_payments_purposes');
  await Hive.openBox<PaymentPurpose>('payment_purposes');
  await Hive.openBox<Classes>('classes'); // Open the payment purposes box
  await Hive.openBox<StudentPayment>('student_payments');
  await Hive.openBox<TeacherPayment>('teacher_payments');
  await Hive.openBox<Student>('students'); // Open the box for student data
  await Hive.openBox<Withdrawal>('withdrawals');
  await Hive.openBox<User>('users'); // Open the box for users
  await Hive.openBox<Teachers>('teachers');
  await Hive.openBox<School>('school');
  await Hive.openBox<Terms>('terms');
  await Hive.openBox<Account>('account');
  await Hive.openBox<Asset>('asset');
  await Hive.openBox<Project>('projects');
  await Hive.openBox<ProjectItem>('projectItems');
  await Hive.openBox<DailyActivity>('dailyActivities');
  await Hive.openBox<ProjectStudentPayment>('projectStudentPayments');

  try {
    await Hive.openBox('financial_box');
  } catch (e) {
    print("Error opening financial_box: $e");
  }
  // Initialize the admin user if not present
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

  final prefs = await SharedPreferences.getInstance();

  // Initialize SharedPreferences with developer credentials
  await prefs.setString('developerUsername', 'SUDOMANOdeveloper');
  await prefs.setString('developerPassword', 'SUDOMANO@codedatapool@developer');

  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  _initializeDefaultTerm();

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;

  const MyApp({Key? key, required this.isLoggedIn}) : super(key: key);

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
    final loggedInUser = getLoggedInUser();

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
          '/welcome': (context) => WelcomePage(),
          '/welcome1': (context) => WelcomePage1(),
          '/backup': (context) => const ExportImportHome(),
          '/profile': (context) => const AdminPanelScreen(),
          '/settings': (context) => const DeveloperHome(),
          '/projects': (context) => const ProjectsHome(),
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
