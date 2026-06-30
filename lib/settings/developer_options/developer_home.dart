import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/accounting_module_models/account_type.dart';
import 'package:zitf_system/database/accounting_module_models/assets.dart';
import 'package:zitf_system/database/exceptional_students/exceptional_students.dart';
import 'package:zitf_system/database/payment_receipts_log.dart';
import 'package:zitf_system/database/projects/payment_method_model.dart';
import 'package:zitf_system/database/projects/project_daily_activity_model.dart';
import 'package:zitf_system/database/projects/project_item_batch_model.dart';
import 'package:zitf_system/database/projects/project_item_batch_sell_model.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/project_item_price_model.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/database/projects/project_sale_transaction_model.dart';
import 'package:zitf_system/database/projects/reprint_project_receipt.dart';
import 'package:zitf_system/database/projects/unitbatching.dart';
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
import 'package:zitf_system/settings/developer_options/domainConfigs/currencies/payment_mthods_screen.dart';
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
  Map<String, dynamic> _paymentLogsStatus = {};
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _isLoading = true);
    final status = await _getPaymentLogsStatus();
    setState(() {
      _paymentLogsStatus = status;
      _isLoading = false;
    });
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
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment Logs Cleanup',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Fix payment logs with invalid operation types and prepare them for sync',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 12),

                            // Status Display
                            if (_isLoading) ...[
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  children: [
                                    _buildStatusRow('Total Logs',
                                        _paymentLogsStatus['total'] ?? 0),
                                    _buildStatusRow('✅ Synced',
                                        _paymentLogsStatus['synced'] ?? 0,
                                        color: Colors.green),
                                    _buildStatusRow('⏳ Unsynced',
                                        _paymentLogsStatus['unsynced'] ?? 0,
                                        color: Colors.orange),
                                    _buildStatusRow('📝 Create Operations',
                                        _paymentLogsStatus['createCount'] ?? 0,
                                        color: Colors.blue),
                                    _buildStatusRow('✏️ Update Operations',
                                        _paymentLogsStatus['updateCount'] ?? 0,
                                        color: Colors.purple),
                                    _buildStatusRow(
                                      '⚠️ Invalid Operations',
                                      _paymentLogsStatus['otherCount'] ?? 0,
                                      color:
                                          (_paymentLogsStatus['otherCount'] ??
                                                      0) >
                                                  0
                                              ? Colors.red
                                              : Colors.green,
                                      isBold: true,
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),

                            // Cleanup Button
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    (_paymentLogsStatus['otherCount'] ?? 0) > 0
                                        ? Colors.red
                                        : Colors.grey.shade400,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed:
                                  (_paymentLogsStatus['otherCount'] ?? 0) > 0
                                      ? _cleanupPaymentLogs
                                      : null,
                              icon: Icon(
                                (_paymentLogsStatus['otherCount'] ?? 0) > 0
                                    ? Icons.cleaning_services
                                    : Icons.check_circle,
                                size: 24,
                              ),
                              label: Text(
                                (_paymentLogsStatus['otherCount'] ?? 0) > 0
                                    ? 'Clean Up ${_paymentLogsStatus['otherCount']} Logs'
                                    : 'All Logs Clean',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                            if ((_paymentLogsStatus['otherCount'] ?? 0) > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '⚠️ ${_paymentLogsStatus['otherCount']} log(s) need cleanup to be ready for sync',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),

                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _loadStatus,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Refresh Status'),
                            ),
                          ],
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
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const PaymentMethodsSettingsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.payments,
                          size: 24, color: Colors.blue),
                      label: const Text(
                        'Payment Methods',
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

  // Helper widget for status row
  Widget _buildStatusRow(String label, int value,
      {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value.toString(),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

// ============================================================
// PAYMENT LOG COMPACTION / CLEANUP LOGIC
// ============================================================

  /// Method to clean up payment logs:
  /// - Finds all logs with operationType not in ['none', 'create', 'update']
  /// - Resets them to 'create' with syncStatus = false
  Future<void> _cleanupPaymentLogs() async {
    try {
      final box = await Hive.openBox<PaymentLog>('payment_log');
      final allLogs = box.values.toList();

      if (allLogs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No payment logs found to clean up'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // ✅ Find logs with invalid operation types
      final List<PaymentLog> logsToFix = [];
      final List<String> invalidOperationTypes = [];

      for (var log in allLogs) {
        final opType = log.operationType ?? '';
        if (opType != 'none' && opType != 'create' && opType != 'update') {
          logsToFix.add(log);
          if (!invalidOperationTypes.contains(opType)) {
            invalidOperationTypes.add(opType);
          }
        }
      }

      if (logsToFix.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ All payment logs have valid operation types'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      // ✅ Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('🔄 Clean Up Payment Logs'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Found ${logsToFix.length} payment log(s) with invalid operation types:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Invalid operation types found:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    ...invalidOperationTypes.map(
                      (type) => Text(
                        '• $type',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'These logs will be reset to:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text('• operationType: "create"'),
              const Text('• syncStatus: false'),
              const Text('• lastModified: now'),
              const Text('• modifiedFields: cleared'),
              const SizedBox(height: 12),
              Text(
                '⚠️ This action cannot be undone!',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clean Up'),
            ),
          ],
        ),
      );

      if (confirm != true) {
        return;
      }

      // ✅ Perform the cleanup
      int fixedCount = 0;
      for (var log in logsToFix) {
        try {
          // ✅ Reset to 'create' with syncStatus = false
          log.operationType = 'create';
          log.syncStatus = false;
          log.lastModified = DateTime.now();
          log.modifiedFields = [
            'operationType',
            'syncStatus',
            'lastModified',
            'modifiedFields',
          ];
          await log.save();
          fixedCount++;
          debugPrint(
              '✅ Fixed log: ${log.logId} (receipt: ${log.receiptNumber})');
        } catch (e) {
          debugPrint('❌ Failed to fix log ${log.logId}: $e');
        }
      }

      // ✅ Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Fixed $fixedCount payment log(s) - ready for sync',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error cleaning up payment logs: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Method to check payment logs status (for display)
  Future<Map<String, dynamic>> _getPaymentLogsStatus() async {
    try {
      final box = await Hive.openBox<PaymentLog>('payment_log');
      final allLogs = box.values.toList();

      int total = allLogs.length;
      int synced = allLogs.where((l) => l.syncStatus == true).length;
      int unsynced = allLogs.where((l) => l.syncStatus == false).length;
      int createCount =
          allLogs.where((l) => l.operationType == 'create').length;
      int updateCount =
          allLogs.where((l) => l.operationType == 'update').length;
      int otherCount = allLogs
          .where((l) =>
              l.operationType != 'none' &&
              l.operationType != 'create' &&
              l.operationType != 'update')
          .length;

      return {
        'total': total,
        'synced': synced,
        'unsynced': unsynced,
        'createCount': createCount,
        'updateCount': updateCount,
        'otherCount': otherCount,
      };
    } catch (e) {
      return {
        'total': 0,
        'synced': 0,
        'unsynced': 0,
        'createCount': 0,
        'updateCount': 0,
        'otherCount': 0,
        'error': e.toString(),
      };
    }
  }

  Future<void> setOperationTypeForSelectedModels(List<String> models) async {
    Future<void> resetBox<T>(String boxName) async {
      final box = await Hive.openBox<T>(boxName);
      for (var key in box.keys) {
        final item = box.get(key);
        if (item != null) {
          (item as dynamic).operationType = 'create';
          (item as dynamic).syncStatus = false;
          await box.put(key, item);
        }
      }
    }

    if (models.contains('TeacherPaymentsPurposes')) {
      await resetBox<TeacherPaymentsPurposes>('teacher_payments_purposes');
    }
    if (models.contains('PaymentPurpose')) {
      await resetBox<PaymentPurpose>('payment_purposes');
    }
    if (models.contains('Classes')) {
      await resetBox<Classes>('classes');
    }
    if (models.contains('StudentPayment')) {
      await resetBox<StudentPayment>('student_payments');
    }
    if (models.contains('TeacherPayment')) {
      await resetBox<TeacherPayment>('teacher_payments');
    }
    if (models.contains('Student')) {
      await resetBox<Student>('students');
    }
    if (models.contains('Withdrawal')) {
      await resetBox<Withdrawal>('withdrawals');
    }
    if (models.contains('User')) {
      await resetBox<User>('users');
    }
    if (models.contains('Teachers')) {
      await resetBox<Teachers>('teachers');
    }
    if (models.contains('School')) {
      await resetBox<School>('school');
    }
    if (models.contains('Terms')) {
      await resetBox<Terms>('terms');
    }
    if (models.contains('Account')) {
      await resetBox<Account>('account');
    }
    if (models.contains('Asset')) {
      await resetBox<Asset>('asset');
    }
    if (models.contains('Project')) {
      await resetBox<Project>('projects');
    }
    if (models.contains('ProjectItem')) {
      await resetBox<ProjectItem>('projectItems');
    }
    if (models.contains('DailyActivity')) {
      await resetBox<DailyActivity>('dailyActivities');
    }
    if (models.contains('DomainRecord')) {
      await resetBox<DomainRecord>('domainBox');
    }

    // --- NEWLY ADDED MISSING MODELS ---
    if (models.contains('ExceptionalStudents')) {
      await resetBox<ExceptionalStudents>('exceptionalStudents');
    }
    if (models.contains('BatchUnit')) {
      await resetBox<BatchUnit>('batch_units');
    }
    if (models.contains('ProductBatch')) {
      await resetBox<ProductBatch>('product_batches');
    }
    if (models.contains('ProjectItemPrice')) {
      await resetBox<ProjectItemPrice>('projectItemPrice');
    }
    if (models.contains('ProjectSaleTransaction')) {
      await resetBox<ProjectSaleTransaction>('project_sale_transactions');
    }
    if (models.contains('BatchSellUnit')) {
      await resetBox<BatchSellUnit>('batchSellUnits');
    }
    if (models.contains('PaymentMethod')) {
      await resetBox<PaymentMethod>('paymentMethods');
    }
    if (models.contains('ReceiptSnapshot')) {
      await resetBox<ReceiptSnapshot>('receiptSnapshots');
    }

    print("Selected models' operationType fields set to 'create'.");
  }
}
