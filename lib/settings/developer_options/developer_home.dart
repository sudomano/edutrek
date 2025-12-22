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
import 'package:zitf_system/reusable_codes/contact_utils/contact_utils.dart';

import 'package:zitf_system/reusable_codes/custom_app_bar.dart';
import 'package:zitf_system/reusable_codes/school_logo/school_logo.dart';
import 'package:zitf_system/settings/developer_options/assign_missing_terms.dart';
import 'package:zitf_system/settings/developer_options/domainConfigs.dart';
import 'package:zitf_system/settings/developer_options/domainConfigs/ip_address_settings.dart';
import 'package:zitf_system/settings/developer_options/domainConfigs/reset_app.dart';
import 'package:zitf_system/settings/developer_options/remove_duplicates.dart';
import 'package:zitf_system/settings/developer_options/termAggregation.dart';

class DeveloperHome extends StatefulWidget {
  const DeveloperHome({super.key});

  @override
  _SyncClassesPageState createState() => _SyncClassesPageState();
}

final Map<String, bool> modelSelections = {
  'TeacherPaymentsPurposes': false,
  'PaymentPurpose': false,
  'Classes': false,
  'StudentPayment': false,
  'TeacherPayment': false,
  'Student': false,
  'Withdrawal': false,
  'User': false,
  'Teachers': false,
  'School': false,
  'Terms': false,
  'Account': false,
  'Asset': false,
  'Project': false,
  'ProjectItem': false,
  'DailyActivity': false,
  'ProjectStudentPayment': false,
  'DomainRecord': false,
};

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
                        // Navigate to the AutoLogoutSettingsScreen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DeviceSettingsPage(),
                          ),
                        );

                        // Optionally, show a SnackBar indicating the action.
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Combine Terms?',
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
                        'Terms Combiner',
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
                        await syncAllParentsToPhoneBook();
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text(
                            'Parent contacts saved successfully.',
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
                        'Save All Parent Contacts',
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
                      onPressed: () {
                        // Navigate to SettingsScreen when clicked
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const IpAddressSettings()),
                        );
                      },
                      icon: const Icon(Icons.key, size: 24, color: Colors.blue),
                      label: const Text(
                        'Change IP Address',
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
                    const SizedBox(
                      height: 10,
                    ),
                    const Text(
                      'Select Models to Reset:',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              modelSelections.updateAll((key, value) => true);
                            });
                          },
                          child: const Text("Select All"),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              modelSelections.updateAll((key, value) => false);
                            });
                          },
                          child: const Text("Deselect All"),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    ...modelSelections.keys.map((modelName) {
                      return CheckboxListTile(
                        title: Text(modelName),
                        value: modelSelections[modelName],
                        onChanged: (bool? value) {
                          setState(() {
                            modelSelections[modelName] = value ?? false;
                          });
                        },
                      );
                    }).toList(),
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
                        final selectedModels = modelSelections.entries
                            .where((entry) => entry.value)
                            .map((entry) => entry.key)
                            .toList();

                        if (selectedModels.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text("Please select at least one model."),
                            ),
                          );
                          return;
                        }

                        await setOperationTypeForSelectedModels(selectedModels);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Selected models reset successfully.',
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
                      icon: const Icon(Icons.restart_alt),
                      label: const Text(
                        'Reset Selected Models',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SizedBox(height: 20),
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
                        await developerLoginReset(context);
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
                        'Reset All Databases',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> setOperationTypeForSelectedModels(List<String> models) async {
    if (models.contains('TeacherPaymentsPurposes')) {
      final box = await Hive.openBox<TeacherPaymentsPurposes>(
          'teacher_payments_purposes');
      for (var key in box.keys) {
        final item = box.get(key);
        if (item != null) {
          item.operationType = 'create';
          item.syncStatus = false;
          await box.put(key, item);
        }
      }
    }

    if (models.contains('PaymentPurpose')) {
      final box = await Hive.openBox<PaymentPurpose>('payment_purposes');
      for (var key in box.keys) {
        final item = box.get(key);
        if (item != null) {
          item.operationType = 'create';
          item.syncStatus = false;
          await box.put(key, item);
        }
      }
    }

    if (models.contains('Classes')) {
      final box = await Hive.openBox<Classes>('classes');
      for (var key in box.keys) {
        final item = box.get(key);
        if (item != null) {
          item.operationType = 'create';
          item.syncStatus = false;
          await box.put(key, item);
        }
      }
    }

    if (models.contains('StudentPayment')) {
      final box = await Hive.openBox<StudentPayment>('student_payments');
      for (var key in box.keys) {
        final item = box.get(key);
        if (item != null) {
          item.operationType = 'create';
          item.syncStatus = false;
          await box.put(key, item);
        }
      }
    }

    if (models.contains('TeacherPayment')) {
      final box = await Hive.openBox<TeacherPayment>('teacher_payments');
      for (var key in box.keys) {
        final item = box.get(key);
        if (item != null) {
          item.operationType = 'create';
          item.syncStatus = false;
          await box.put(key, item);
        }
      }
    }

    if (models.contains('Student')) {
      final box = await Hive.openBox<Student>('students');
      for (var key in box.keys) {
        final item = box.get(key);
        if (item != null) {
          item.operationType = 'create';
          item.syncStatus = false;
          await box.put(key, item);
        }
      }
    }

    if (models.contains('Withdrawal')) {
      final box = await Hive.openBox<Withdrawal>('withdrawals');
      for (var key in box.keys) {
        final item = box.get(key);
        if (item != null) {
          item.operationType = 'create';
          item.syncStatus = false;
          await box.put(key, item);
        }
      }
    }

    if (models.contains('User')) {
      final box = await Hive.openBox<User>('users');
      for (var key in box.keys) {
        final item = box.get(key);
        if (item != null) {
          item.operationType = 'create';
          item.syncStatus = false;
          await box.put(key, item);
        }
      }
    }

    if (models.contains('Teachers')) {
      final box = await Hive.openBox<Teachers>('teachers');
      for (var key in box.keys) {
        final item = box.get(key);
        if (item != null) {
          item.operationType = 'create';
          item.syncStatus = false;
          await box.put(key, item);
        }
      }
    }

    if (models.contains('School')) {
      final box = await Hive.openBox<School>('school');
      for (var key in box.keys) {
        final item = box.get(key);
        if (item != null) {
          item.operationType = 'create';
          item.syncStatus = false;
          await box.put(key, item);
        }
      }
    }

    if (models.contains('Terms')) {
      final box = await Hive.openBox<Terms>('terms');
      for (var key in box.keys) {
        final item = box.get(key);
        if (item != null) {
          item.operationType = 'create';
          item.syncStatus = false;
          await box.put(key, item);
        }
      }
    }

    if (models.contains('Account')) {
      final box = await Hive.openBox<Account>('account');
      for (var key in box.keys) {
        final item = box.get(key);
        if (item != null) {
          item.operationType = 'create';
          item.syncStatus = false;
          await box.put(key, item);
        }
      }
    }

    if (models.contains('Asset')) {
      final box = await Hive.openBox<Asset>('asset');
      for (var key in box.keys) {
        final item = box.get(key);
        if (item != null) {
          item.operationType = 'create';
          item.syncStatus = false;
          await box.put(key, item);
        }
      }
    }

    if (models.contains('Project')) {
      final box = await Hive.openBox<Project>('projects');
      for (var key in box.keys) {
        final item = box.get(key);
        if (item != null) {
          item.operationType = 'create';
          item.syncStatus = false;
          await box.put(key, item);
        }
      }
    }

    if (models.contains('ProjectItem')) {
      final box = await Hive.openBox<ProjectItem>('projectItems');
      for (var key in box.keys) {
        final item = box.get(key);
        if (item != null) {
          item.operationType = 'create';
          item.syncStatus = false;
          await box.put(key, item);
        }
      }
    }

    if (models.contains('DailyActivity')) {
      final box = await Hive.openBox<DailyActivity>('dailyActivities');
      for (var key in box.keys) {
        final item = box.get(key);
        if (item != null) {
          item.operationType = 'create';
          item.syncStatus = false;
          await box.put(key, item);
        }
      }
    }

    if (models.contains('ProjectStudentPayment')) {
      final box =
          await Hive.openBox<ProjectStudentPayment>('projectStudentPayments');
      for (var key in box.keys) {
        final item = box.get(key);
        if (item != null) {
          item.operationType = 'create';
          item.syncStatus = false;
          await box.put(key, item);
        }
      }
    }

    if (models.contains('DomainRecord')) {
      final box = await Hive.openBox<DomainRecord>('domainBox');
      for (var key in box.keys) {
        final item = box.get(key);
        if (item != null) {
          item.operationType = 'create';
          item.syncStatus = false;
          await box.put(key, item);
        }
      }
    }

    print("Selected models' operationType fields set to 'create'.");
  }

  @override
  void dispose() {
    super.dispose();
  }
}
