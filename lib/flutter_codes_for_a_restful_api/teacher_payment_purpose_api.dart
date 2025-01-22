import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';

// Model class for TeacherPaymentsPurpose
class TeacherPaymentsPurpose {
  final int id;
  final String paymentPurpose;
  final double purposeAmount;
  final int? termId;

  TeacherPaymentsPurpose({
    required this.id,
    required this.paymentPurpose,
    required this.purposeAmount,
    this.termId,
  });

  // Factory method to create a TeacherPaymentsPurpose object from JSON
  factory TeacherPaymentsPurpose.fromJson(Map<String, dynamic> json) {
    return TeacherPaymentsPurpose(
      id: json['id'],
      paymentPurpose: json['paymentPurpose'],
      purposeAmount: json['purposeAmount'],
      termId: json['termId'],
    );
  }

  // Method to convert TeacherPaymentsPurpose object to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'paymentPurpose': paymentPurpose,
      'purposeAmount': purposeAmount,
      'termId': termId,
    };
  }
}

// Function to fetch teacher payment purposes from the MySQL database via API
Future<List<TeacherPaymentsPurpose>> fetchTeacherPaymentsPurposes() async {
  final response = await http.get(Uri.parse(
      'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/teacher_payments_purposes'));

  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse
        .map((data) => TeacherPaymentsPurpose.fromJson(data))
        .toList();
  } else {
    throw Exception('Failed to load teacher payments purposes');
  }
}

// Function to update local Hive database with fetched teacher payment purposes
Future<void> updateHiveWithFetchedTeacherPaymentsPurposes(
    List<TeacherPaymentsPurpose> purposes) async {
  var box =
      await Hive.openBox<TeacherPaymentsPurpose>('teacherPaymentsPurposesBox');

  for (var purpose in purposes) {
    await box.put(purpose.id, purpose);
  }

  await box.close();
}

// Function to create a new teacher payment purpose in MySQL
Future<void> createTeacherPaymentsPurposeInMySQL(
    TeacherPaymentsPurpose newPurpose) async {
  final response = await http.post(
    Uri.parse(
        'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/teacher_payments_purposes'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(newPurpose.toJson()),
  );

  if (response.statusCode != 201) {
    throw Exception('Failed to create teacher payment purpose');
  }
}

// Function to update a teacher payment purpose in MySQL
Future<void> updateTeacherPaymentsPurposeInMySQL(
    TeacherPaymentsPurpose updatedPurpose) async {
  final response = await http.put(
    Uri.parse(
        'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/teacher_payments_purposes/${updatedPurpose.id}'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(updatedPurpose.toJson()),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to update teacher payment purpose');
  }
}

// Function to delete a teacher payment purpose from MySQL
Future<void> deleteTeacherPaymentsPurposeFromMySQL(int id) async {
  final response = await http.delete(
    Uri.parse(
        'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/teacher_payments_purposes/$id'),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to delete teacher payment purpose');
  }
}

// Example usage: Sync data between MySQL and Hive
Future<void> syncTeacherPaymentsPurposes() async {
  try {
    // Fetch teacher payment purposes from MySQL
    List<TeacherPaymentsPurpose> purposes =
        await fetchTeacherPaymentsPurposes();

    // Update local Hive database with fetched teacher payment purposes
    await updateHiveWithFetchedTeacherPaymentsPurposes(purposes);
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Add a new teacher payment purpose and sync with MySQL
Future<void> addNewTeacherPaymentsPurpose(
    TeacherPaymentsPurpose newPurpose) async {
  try {
    // Create a new teacher payment purpose in MySQL
    await createTeacherPaymentsPurposeInMySQL(newPurpose);

    // Optionally, fetch the updated list of teacher payment purposes
    await syncTeacherPaymentsPurposes();
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Update teacher payment purpose locally and sync with MySQL
Future<void> updateTeacherPaymentsPurposeLocally(
    TeacherPaymentsPurpose updatedPurpose) async {
  try {
    // Open Hive box
    var box = await Hive.openBox<TeacherPaymentsPurpose>(
        'teacherPaymentsPurposesBox');

    // Update teacher payment purpose in Hive
    await box.put(updatedPurpose.id, updatedPurpose);

    // Send the updated teacher payment purpose to MySQL
    await updateTeacherPaymentsPurposeInMySQL(updatedPurpose);

    await box.close();
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Delete a teacher payment purpose and sync with MySQL
Future<void> deleteTeacherPaymentsPurpose(int id) async {
  try {
    // Delete the teacher payment purpose from MySQL
    await deleteTeacherPaymentsPurposeFromMySQL(id);

    // Optionally, fetch the updated list of teacher payment purposes
    await syncTeacherPaymentsPurposes();
  } catch (e) {
    print('Error: $e');
  }
}
