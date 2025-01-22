import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';

class StudentPaymentSync extends StatefulWidget {
  const StudentPaymentSync({Key? key}) : super(key: key);

  @override
  _SyncSchoolsPageState createState() => _SyncSchoolsPageState();
}

class _SyncSchoolsPageState extends State<StudentPaymentSync> {
  Box<StudentPayment>? _student_paymentsBox;

  @override
  void initState() {
    super.initState();
    _openHiveBox();
  }

  Future<void> _openHiveBox() async {
    _student_paymentsBox =
        await Hive.openBox<StudentPayment>('student_payments');
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

  Future<void> _fetchAndSyncStudentPayments() async {
    const String apiUrl =
        'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/student_payment_api.php';

    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> studentPayments = jsonDecode(response.body);

        for (var paymentsData in studentPayments) {
          StudentPayment fetchedPayments = StudentPayment(
            id: int.tryParse(paymentsData['fid'] ?? '0') ?? 0,
            studentName: paymentsData['studentName'] ?? '',
            studentSurname: paymentsData['studentSurname'] ?? '',
            studentClass: paymentsData['studentClass'] ?? '',
            phoneNumber: paymentsData['phoneNumber'] ?? '',
            paymentPurpose: paymentsData['paymentPurpose'] ?? '',
            amountToPay: paymentsData['amountToPay'] != null
                ? double.tryParse(paymentsData['amountToPay'].toString()) ?? 0.0
                : 0.0,
            paymentDate: DateTime.tryParse(paymentsData['paymentDate']) ??
                DateTime.now(),
            receiptNumber: paymentsData['receiptNumber'],
            termId: paymentsData['termId'],
          );

          // Check if the record exists in Hive using schoolCode
          var existingPurposeList = _student_paymentsBox!.values
              .where(
                (studentPayments) =>
                    studentPayments.receiptNumber ==
                    fetchedPayments.receiptNumber,
              )
              .toList();

          StudentPayment? existingPurposes =
              existingPurposeList.isNotEmpty ? existingPurposeList.first : null;

          if (fetchedPayments.receiptNumber != null) {
            if (existingPurposes != null) {
              // Update existing record
              existingPurposes
                ..id = fetchedPayments.id
                ..studentName = fetchedPayments.studentName
                ..studentSurname = fetchedPayments.studentSurname
                ..studentClass = fetchedPayments.studentClass
                ..phoneNumber = fetchedPayments.phoneNumber
                ..paymentPurpose = fetchedPayments.paymentPurpose
                ..amountToPay = fetchedPayments.amountToPay
                ..paymentDate = fetchedPayments.paymentDate
                ..receiptNumber = fetchedPayments.receiptNumber
                ..termId = fetchedPayments.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();
              await existingPurposes.save();
              print(
                  'StudentPayment ${fetchedPayments.receiptNumber} updated successfully in Hive.');
            } else {
              // Create a new record
              await _student_paymentsBox!.add(fetchedPayments);
              print(
                  'StudentPayment ${fetchedPayments.receiptNumber} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Other StudentPayment Record Was Found with no Receipt Numbers and was Skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch StudentPayment from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing StudentPayment: $e');
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
        title: const Center(child: Text('Fetch and Save StudentPayment')),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            if (admin || secretary || accountant || subadmin)
              await _fetchAndSyncStudentPayments();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('StudentPayment data Saved successfully.'),
            ));
          },
          child: const Text('Fetch and Save StudentPayment'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
