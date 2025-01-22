import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/teacher_payment_purpose.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';

class TeacherPaymentPuposesSync extends StatefulWidget {
  const TeacherPaymentPuposesSync({Key? key}) : super(key: key);

  @override
  _SyncSchoolsPageState createState() => _SyncSchoolsPageState();
}

class _SyncSchoolsPageState extends State<TeacherPaymentPuposesSync> {
  Box<TeacherPaymentsPurposes>? _teacher_payments_purposesBox;

  @override
  void initState() {
    super.initState();
    _openHiveBox();
  }

  Future<void> _openHiveBox() async {
    _teacher_payments_purposesBox = await Hive.openBox<TeacherPaymentsPurposes>(
        'teacher_payments_purposes');
    print('Hive box opened successfully.');
  }

  // Helper function to decode string to List<String>
  List<String> _decodeToList(dynamic value) {
    if (value is String) {
      // If it's a string, try to decode it as JSON
      try {
        return List<String>.from(jsonDecode(value));
      } catch (e) {
        print('Error decoding string to List: $e');
        return [];
      }
    } else if (value is List) {
      // If it's already a list, return it directly
      return List<String>.from(value);
    }
    return [];
  }

  Future<void> _fetchAndSyncTeacherPurposes() async {
    const String apiUrl =
        'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/teacher_payment_purposes_api.php';

    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> teacherPurposes = jsonDecode(response.body);

        for (var teacherPurposeData in teacherPurposes) {
          TeacherPaymentsPurposes fetchedTeacherPurpose =
              TeacherPaymentsPurposes(
            id: int.tryParse(teacherPurposeData['fid'] ?? '0') ?? 0,
            paymentPurpose: teacherPurposeData['paymentPurpose'] ?? '',
            purposeAmount: teacherPurposeData['purposeAmount'] != null
                ? double.tryParse(
                        teacherPurposeData['purposeAmount'].toString()) ??
                    0.0
                : 0.0,
            purposeCode: teacherPurposeData['purposeCode'],
            associatedStaff:
                _decodeToList(teacherPurposeData['associatedStaff']),
            termId: teacherPurposeData['termId'],
          );

          // Check if the record exists in Hive using schoolCode
          var existingTeacherPurposeList = _teacher_payments_purposesBox!.values
              .where(
                (teacherPurposes) =>
                    teacherPurposes.purposeCode ==
                    fetchedTeacherPurpose.purposeCode,
              )
              .toList();

          TeacherPaymentsPurposes? existingTeacherPurposes =
              existingTeacherPurposeList.isNotEmpty
                  ? existingTeacherPurposeList.first
                  : null;
          if (fetchedTeacherPurpose.purposeCode != null) {
            if (existingTeacherPurposes != null) {
              // Update existing record
              existingTeacherPurposes
                ..id = fetchedTeacherPurpose.id
                ..purposeCode = fetchedTeacherPurpose.purposeCode
                ..paymentPurpose = fetchedTeacherPurpose.paymentPurpose
                ..purposeAmount = fetchedTeacherPurpose.purposeAmount
                ..associatedStaff = fetchedTeacherPurpose.associatedStaff
                ..termId = fetchedTeacherPurpose.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();
              await existingTeacherPurposes.save();
              print(
                  'TeacherPaymentsPurposes ${fetchedTeacherPurpose.purposeCode} updated successfully in Hive.');
            } else {
              // Create a new record
              await _teacher_payments_purposesBox!.add(fetchedTeacherPurpose);
              print(
                  'TeacherPaymentsPurposes ${fetchedTeacherPurpose.purposeCode} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Other staff Payment Purpose Record Was Found with no purposeCode and was Skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch TeacherPaymentsPurposes from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing TeacherPaymentsPurposes: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedInUser = getLoggedInUser();
    final role = loggedInUser.role;
    final user = loggedInUser.username;
    final admin = loggedInUser?.role.toLowerCase() == 'admin';
    final secretary = loggedInUser?.role.toLowerCase() == 'secretary';
    final teacher = loggedInUser?.role.toLowerCase() == 'teacher';

    final accountant = loggedInUser?.role.toLowerCase() == 'accountant';
    final subadmin = loggedInUser?.role.toLowerCase() == 'sub-admin';
    return Scaffold(
      appBar: AppBar(
        title:
            const Center(child: Text('Fetch and Save TeacherPaymentsPurposes')),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            if (admin || subadmin) await _fetchAndSyncTeacherPurposes();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('TeacherPaymentsPurposes data Saved successfully.'),
            ));
          },
          child: const Text('Fetch and Save TeacherPaymentsPurposes'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
