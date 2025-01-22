import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';

// Model class for TeacherPayment
class TeacherPayment {
  final int id;
  final String studentName;
  final String studentSurname;
  final String studentClass;
  final String phoneNumber;
  final String paymentPurpose;
  final double amountToPay;
  final String paymentDate;
  final int? termId;

  TeacherPayment({
    required this.id,
    required this.studentName,
    required this.studentSurname,
    required this.studentClass,
    required this.phoneNumber,
    required this.paymentPurpose,
    required this.amountToPay,
    required this.paymentDate,
    this.termId,
  });

  // Factory method to create a TeacherPayment object from JSON
  factory TeacherPayment.fromJson(Map<String, dynamic> json) {
    return TeacherPayment(
      id: json['id'],
      studentName: json['studentName'],
      studentSurname: json['studentSurname'],
      studentClass: json['studentClass'],
      phoneNumber: json['phoneNumber'],
      paymentPurpose: json['paymentPurpose'],
      amountToPay: json['amountToPay'],
      paymentDate: json['paymentDate'],
      termId: json['termId'],
    );
  }

  // Method to convert TeacherPayment object to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentName': studentName,
      'studentSurname': studentSurname,
      'studentClass': studentClass,
      'phoneNumber': phoneNumber,
      'paymentPurpose': paymentPurpose,
      'amountToPay': amountToPay,
      'paymentDate': paymentDate,
      'termId': termId,
    };
  }
}

// Function to fetch teacher payments from the MySQL database via API
Future<List<TeacherPayment>> fetchTeacherPayments() async {
  final response = await http.get(Uri.parse(
      'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/teacher_payments'));

  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((data) => TeacherPayment.fromJson(data)).toList();
  } else {
    throw Exception('Failed to load teacher payments');
  }
}

// Function to update local Hive database with fetched teacher payments
Future<void> updateHiveWithFetchedTeacherPayments(
    List<TeacherPayment> payments) async {
  var box = await Hive.openBox<TeacherPayment>('teacherPaymentsBox');

  for (var payment in payments) {
    await box.put(payment.id, payment);
  }

  await box.close();
}

// Function to create a new teacher payment in MySQL
Future<void> createTeacherPaymentInMySQL(TeacherPayment newPayment) async {
  final response = await http.post(
    Uri.parse(
        'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/teacher_payments'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(newPayment.toJson()),
  );

  if (response.statusCode != 201) {
    throw Exception('Failed to create teacher payment');
  }
}

// Function to update a teacher payment in MySQL
Future<void> updateTeacherPaymentInMySQL(TeacherPayment updatedPayment) async {
  final response = await http.put(
    Uri.parse(
        'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/teacher_payments/${updatedPayment.id}'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(updatedPayment.toJson()),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to update teacher payment');
  }
}

// Function to delete a teacher payment from MySQL
Future<void> deleteTeacherPaymentFromMySQL(int id) async {
  final response = await http.delete(
    Uri.parse(
        'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/teacher_payments/$id'),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to delete teacher payment');
  }
}

// Example usage: Sync data between MySQL and Hive
Future<void> syncTeacherPayments() async {
  try {
    // Fetch teacher payments from MySQL
    List<TeacherPayment> payments = await fetchTeacherPayments();

    // Update local Hive database with fetched teacher payments
    await updateHiveWithFetchedTeacherPayments(payments);
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Add a new teacher payment and sync with MySQL
Future<void> addNewTeacherPayment(TeacherPayment newPayment) async {
  try {
    // Create a new teacher payment in MySQL
    await createTeacherPaymentInMySQL(newPayment);

    // Optionally, fetch the updated list of teacher payments
    await syncTeacherPayments();
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Update teacher payment locally and sync with MySQL
Future<void> updateTeacherPaymentLocally(TeacherPayment updatedPayment) async {
  try {
    // Open Hive box
    var box = await Hive.openBox<TeacherPayment>('teacherPaymentsBox');

    // Update teacher payment in Hive
    await box.put(updatedPayment.id, updatedPayment);

    // Send the updated teacher payment to MySQL
    await updateTeacherPaymentInMySQL(updatedPayment);

    await box.close();
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Delete a teacher payment and sync with MySQL
Future<void> deleteTeacherPayment(int id) async {
  try {
    // Delete the teacher payment from MySQL
    await deleteTeacherPaymentFromMySQL(id);

    // Optionally, fetch the updated list of teacher payments
    await syncTeacherPayments();
  } catch (e) {
    print('Error: $e');
  }
}
