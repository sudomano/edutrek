import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';

// Model class for StudentPayment
class StudentPayment {
  final int id;
  final String studentName;
  final String studentSurname;
  final String studentClass;
  final String phoneNumber;
  final String paymentPurpose;
  final double amountToPay;
  final String paymentDate;
  final int? termId;

  StudentPayment({
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

  // Factory method to create a StudentPayment object from JSON
  factory StudentPayment.fromJson(Map<String, dynamic> json) {
    return StudentPayment(
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

  // Method to convert StudentPayment object to JSON
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

// Function to fetch student payments from the MySQL database via API
Future<List<StudentPayment>> fetchStudentPayments() async {
  final response = await http.get(Uri.parse(
      'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/student_payments'));

  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((data) => StudentPayment.fromJson(data)).toList();
  } else {
    throw Exception('Failed to load student payments');
  }
}

// Function to update local Hive database with fetched student payments
Future<void> updateHiveWithFetchedStudentPayments(
    List<StudentPayment> payments) async {
  var box = await Hive.openBox<StudentPayment>('studentPaymentsBox');

  for (var payment in payments) {
    await box.put(payment.id, payment);
  }

  await box.close();
}

// Function to create a new student payment in MySQL
Future<void> createStudentPaymentInMySQL(StudentPayment newPayment) async {
  final response = await http.post(
    Uri.parse(
        'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/student_payments'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(newPayment.toJson()),
  );

  if (response.statusCode != 201) {
    throw Exception('Failed to create student payment');
  }
}

// Function to update a student payment in MySQL
Future<void> updateStudentPaymentInMySQL(StudentPayment updatedPayment) async {
  final response = await http.put(
    Uri.parse(
        'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/student_payments/${updatedPayment.id}'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(updatedPayment.toJson()),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to update student payment');
  }
}

// Function to delete a student payment from MySQL
Future<void> deleteStudentPaymentFromMySQL(int id) async {
  final response = await http.delete(
    Uri.parse(
        'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/student_payments/$id'),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to delete student payment');
  }
}

// Example usage: Sync data between MySQL and Hive
Future<void> syncStudentPayments() async {
  try {
    // Fetch student payments from MySQL
    List<StudentPayment> payments = await fetchStudentPayments();

    // Update local Hive database with fetched student payments
    await updateHiveWithFetchedStudentPayments(payments);
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Add a new student payment and sync with MySQL
Future<void> addNewStudentPayment(StudentPayment newPayment) async {
  try {
    // Create a new student payment in MySQL
    await createStudentPaymentInMySQL(newPayment);

    // Optionally, fetch the updated list of student payments
    await syncStudentPayments();
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Update student payment locally and sync with MySQL
Future<void> updateStudentPaymentLocally(StudentPayment updatedPayment) async {
  try {
    // Open Hive box
    var box = await Hive.openBox<StudentPayment>('studentPaymentsBox');

    // Update student payment in Hive
    await box.put(updatedPayment.id, updatedPayment);

    // Send the updated student payment to MySQL
    await updateStudentPaymentInMySQL(updatedPayment);

    await box.close();
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Delete a student payment and sync with MySQL
Future<void> deleteStudentPayment(int id) async {
  try {
    // Delete the student payment from MySQL
    await deleteStudentPaymentFromMySQL(id);

    // Optionally, fetch the updated list of student payments
    await syncStudentPayments();
  } catch (e) {
    print('Error: $e');
  }
}
