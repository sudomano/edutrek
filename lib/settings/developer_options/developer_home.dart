import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/accounting_module_models/account_type.dart';
import 'package:zitf_system/database/accounting_module_models/assets.dart';
import 'package:zitf_system/database/projects/project_daily_activity_model.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/database/projects/project_student_payment_model.dart';
import 'package:zitf_system/database/syncConfigs/syncConfig.dart';

import 'package:zitf_system/reusable_codes/PK_assignment/pk_assignment.dart';

import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/database/withdrawalshome.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/database/teacher_payment_purpose.dart';
import 'package:zitf_system/database/teacher_payments.dart';
import 'package:zitf_system/reusable_codes/auto_logout_user_when_app_in_background/auto_logout_timer.dart';
import 'package:zitf_system/reusable_codes/bluetooth_helper_codes/bluetooth_tips_helper.dart';

import 'package:zitf_system/reusable_codes/custom_app_bar.dart';
import 'package:zitf_system/reusable_codes/school_logo/school_logo.dart';
import 'package:zitf_system/settings/developer_options/assign_missing_terms.dart';
import 'package:zitf_system/settings/developer_options/domainConfigs.dart';
import 'package:zitf_system/settings/developer_options/remove_duplicates.dart';

class DeveloperHome extends StatefulWidget {
  const DeveloperHome({super.key});

  @override
  _SyncClassesPageState createState() => _SyncClassesPageState();
}

class _SyncClassesPageState extends State<DeveloperHome> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen =
        MediaQuery.of(context).size.width > 600; // Example threshold

    return Scaffold(
      appBar: const CustomAppBar(title: 'Developer Options'),
      body: SingleChildScrollView(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromRGBO(0, 233, 254, 1),
                Color.fromARGB(0, 233, 254, 1),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sync All Records Button
                    const SizedBox(
                      height: 5,
                    ),
                    buildFutureSchoolsWidget(isLargeScreen: isLargeScreen),
                    const SizedBox(height: 20),
                    const SizedBox(
                      height: 10,
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 255, 255, 255),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        // Navigate to the AutoLogoutSettingsScreen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AutoLogoutSettingsScreen(),
                          ),
                        );

                        // Optionally, show a SnackBar indicating the action.
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Auto Logout Timer',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Color.fromARGB(255, 255, 255, 255),
                          ),
                        );
                      },
                      icon: const Icon(Icons.timer, size: 24),
                      label: const Text(
                        'Auto Logout Timer',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),

                    const SizedBox(height: 20),
                    const SizedBox(
                      height: 10,
                    ),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 255, 255, 255),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        await setOperationTypeToCreateForAllModels();
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text(
                            'Operation Type Reset was successfully.',
                            style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                                fontWeight: FontWeight.w600),
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Color.fromARGB(255, 255, 255, 255),
                        ));
                      },
                      icon: const Icon(Icons.restart_alt, size: 24),
                      label: const Text(
                        'Reset Operation Type',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 255, 255, 255),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        await assignPrimaryKeysToModels();
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text(
                            'All primary keys assigned successfully.',
                            style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                                fontWeight: FontWeight.w600),
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Color.fromARGB(255, 255, 255, 255),
                        ));
                      },
                      icon: const Icon(Icons.key, size: 24),
                      label: const Text(
                        'Assign Primary Keys',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        await BluetoothHelper().resetBluetooth();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  "Bluetooth has been reset. Restarting...")),
                        );
                      },
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text("Reset Bluetooth",
                          style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 255, 255, 255),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        // Navigate to SettingsScreen when clicked
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SettingsScreen()),
                        );
                      },
                      icon: const Icon(Icons.key, size: 24, color: Colors.blue),
                      label: const Text(
                        'Assign Associated Terms',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 255, 255, 255),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        // Navigate to SettingsScreen when clicked
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SettingsScreens()),
                        );
                      },
                      icon: const Icon(Icons.key, size: 24, color: Colors.blue),
                      label: const Text(
                        'Remove Duplicates',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 255, 255, 255),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        await developerLogin(context);
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text(
                            'Redirect To Developer Login',
                            style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                                fontWeight: FontWeight.w600),
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Color.fromARGB(255, 255, 255, 255),
                        ));
                      },
                      icon: const Icon(Icons.restart_alt, size: 24),
                      label: const Text(
                        'School Domain Configs',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Retrieve and Save Records Button
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> setOperationTypeToCreateForAllModels() async {
    // Set operationType for TeacherPaymentsPurposes
    final teacherPaymentsPurposesBox =
        await Hive.openBox<TeacherPaymentsPurposes>(
            'teacher_payments_purposes');
    for (var key in teacherPaymentsPurposesBox.keys) {
      final item = teacherPaymentsPurposesBox.get(key);
      if (item != null) {
        item.operationType = 'create';
        item.syncStatus = false;
        await teacherPaymentsPurposesBox.put(key, item);
      }
    }

    // Set operationType for PaymentPurpose
    final paymentPurposeBox =
        await Hive.openBox<PaymentPurpose>('payment_purposes');
    for (var key in paymentPurposeBox.keys) {
      final item = paymentPurposeBox.get(key);
      if (item != null) {
        item.operationType = 'create';
        item.syncStatus = false;

        await paymentPurposeBox.put(key, item);
      }
    }

    // Set operationType for Classes
    final classesBox = await Hive.openBox<Classes>('classes');
    for (var key in classesBox.keys) {
      final item = classesBox.get(key);
      if (item != null) {
        item.operationType = 'create';
        item.syncStatus = false;

        await classesBox.put(key, item);
      }
    }

    // Set operationType for StudentPayment
    final studentPaymentBox =
        await Hive.openBox<StudentPayment>('student_payments');
    for (var key in studentPaymentBox.keys) {
      final item = studentPaymentBox.get(key);
      if (item != null) {
        item.operationType = 'create';
        item.syncStatus = false;

        await studentPaymentBox.put(key, item);
      }
    }

    // Set operationType for TeacherPayment
    final teacherPaymentBox =
        await Hive.openBox<TeacherPayment>('teacher_payments');
    for (var key in teacherPaymentBox.keys) {
      final item = teacherPaymentBox.get(key);
      if (item != null) {
        item.operationType = 'create';
        item.syncStatus = false;

        await teacherPaymentBox.put(key, item);
      }
    }

    // Set operationType for Student
    final studentBox = await Hive.openBox<Student>('students');
    for (var key in studentBox.keys) {
      final item = studentBox.get(key);
      if (item != null) {
        item.operationType = 'create';
        item.syncStatus = false;

        await studentBox.put(key, item);
      }
    }

    // Set operationType for Withdrawal
    final withdrawalBox = await Hive.openBox<Withdrawal>('withdrawals');
    for (var key in withdrawalBox.keys) {
      final item = withdrawalBox.get(key);
      if (item != null) {
        item.operationType = 'create';
        item.syncStatus = false;

        await withdrawalBox.put(key, item);
      }
    }

    // Set operationType for User
    final userBox = await Hive.openBox<User>('users');
    for (var key in userBox.keys) {
      final item = userBox.get(key);
      if (item != null) {
        item.operationType = 'create';
        item.syncStatus = false;

        await userBox.put(key, item);
      }
    }

    // Set operationType for Teachers
    final teachersBox = await Hive.openBox<Teachers>('teachers');
    for (var key in teachersBox.keys) {
      final item = teachersBox.get(key);
      if (item != null) {
        item.operationType = 'create';
        item.syncStatus = false;

        await teachersBox.put(key, item);
      }
    }

    // Set operationType for School
    final schoolBox = await Hive.openBox<School>('school');
    for (var key in schoolBox.keys) {
      final item = schoolBox.get(key);
      if (item != null) {
        item.operationType = 'create';
        item.syncStatus = false;

        await schoolBox.put(key, item);
      }
    }

    // Set operationType for Terms
    final termsBox = await Hive.openBox<Terms>('terms');
    for (var key in termsBox.keys) {
      final item = termsBox.get(key);
      if (item != null) {
        item.operationType = 'create';
        item.syncStatus = false;

        await termsBox.put(key, item);
      }
    }

    // Set operationType for Account
    final accountBox = await Hive.openBox<Account>('account');
    for (var key in accountBox.keys) {
      final item = accountBox.get(key);
      if (item != null) {
        item.operationType = 'create';
        item.syncStatus = false;

        await accountBox.put(key, item);
      }
    }

    // Set operationType for Asset
    final assetBox = await Hive.openBox<Asset>('asset');
    for (var key in assetBox.keys) {
      final item = assetBox.get(key);
      if (item != null) {
        item.operationType = 'create';
        item.syncStatus = false;

        await assetBox.put(key, item);
      }
    }

    // Set operationType for Project
    final projectBox = await Hive.openBox<Project>('projects');
    for (var key in projectBox.keys) {
      final item = projectBox.get(key);
      if (item != null) {
        item.operationType = 'create';
        item.syncStatus = false;

        await projectBox.put(key, item);
      }
    }

    // Set operationType for ProjectItem
    final projectItemBox = await Hive.openBox<ProjectItem>('projectItems');
    for (var key in projectItemBox.keys) {
      final item = projectItemBox.get(key);
      if (item != null) {
        item.operationType = 'create';
        item.syncStatus = false;

        await projectItemBox.put(key, item);
      }
    }

    // Set operationType for DailyActivity
    final dailyActivityBox =
        await Hive.openBox<DailyActivity>('dailyActivities');
    for (var key in dailyActivityBox.keys) {
      final item = dailyActivityBox.get(key);
      if (item != null) {
        item.operationType = 'create';
        item.syncStatus = false;

        await dailyActivityBox.put(key, item);
      }
    }

    // Set operationType for ProjectStudentPayment
    final projectStudentPaymentBox =
        await Hive.openBox<ProjectStudentPayment>('projectStudentPayments');
    for (var key in projectStudentPaymentBox.keys) {
      final item = projectStudentPaymentBox.get(key);
      if (item != null) {
        item.operationType = 'create';
        item.syncStatus = false;

        await projectStudentPaymentBox.put(key, item);
      }
    }

    // Set operationType for _domainRecordBox
    final domainRecordBox = await Hive.openBox<DomainRecord>('domainBox');
    for (var key in domainRecordBox.keys) {
      final item = domainRecordBox.get(key);
      if (item != null) {
        item.operationType = 'create';
        item.syncStatus = false;

        await domainRecordBox.put(key, item);
      }
    }

    print("All operationType fields set to 'create' for all models.");
  }

  @override
  void dispose() {
    super.dispose();
  }
}
