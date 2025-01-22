import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';

// Model class for School
class School {
  final int id;
  final String schoolName;
  final String schoolAddress;
  final String schoolPhoneNumber;
  final String schoolEmail;
  final int? termId;

  School({
    required this.id,
    required this.schoolName,
    required this.schoolAddress,
    required this.schoolPhoneNumber,
    required this.schoolEmail,
    this.termId,
  });

  // Factory method to create a School object from JSON
  factory School.fromJson(Map<String, dynamic> json) {
    return School(
      id: json['id'],
      schoolName: json['schoolName'],
      schoolAddress: json['schoolAddress'],
      schoolPhoneNumber: json['schoolPhoneNumber'],
      schoolEmail: json['schoolEmail'],
      termId: json['termId'],
    );
  }

  // Method to convert School object to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'schoolName': schoolName,
      'schoolAddress': schoolAddress,
      'schoolPhoneNumber': schoolPhoneNumber,
      'schoolEmail': schoolEmail,
      'termId': termId,
    };
  }
}

// Function to fetch schools from the MySQL database via API
Future<List<School>> fetchSchools() async {
  final response = await http.get(Uri.parse(
      'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/school'));

  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((data) => School.fromJson(data)).toList();
  } else {
    throw Exception('Failed to load schools');
  }
}

// Function to update local Hive database with fetched schools
Future<void> updateHiveWithFetchedSchools(List<School> schools) async {
  var box = await Hive.openBox<School>('schoolBox');

  for (var school in schools) {
    await box.put(school.id, school);
  }

  await box.close();
}

// Function to create a new school in MySQL
Future<void> createSchoolInMySQL(School school) async {
  final response = await http.post(
    Uri.parse(
        'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/school'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(school.toJson()),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to create school');
  }
}

// Function to update a school in MySQL
Future<void> updateSchoolInMySQL(School school) async {
  final response = await http.put(
    Uri.parse(
        'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/school'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(school.toJson()),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to update school');
  }
}

// Function to delete a school from MySQL
Future<void> deleteSchoolFromMySQL(int id) async {
  final response = await http.delete(
    Uri.parse(
        'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/school?id=$id'),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to delete school');
  }
}

// Example usage: Sync data between MySQL and Hive
Future<void> syncData() async {
  try {
    // Fetch schools from MySQL
    List<School> schools = await fetchSchools();

    // Update local Hive database with fetched schools
    await updateHiveWithFetchedSchools(schools);
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Add a new school and sync with MySQL
Future<void> addNewSchool(School school) async {
  try {
    // Create a new school in MySQL
    await createSchoolInMySQL(school);

    // Optionally, fetch the updated list of schools
    await syncData();
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Update a school locally and sync with MySQL
Future<void> updateSchoolLocally(School updatedSchool) async {
  try {
    // Open Hive box
    var box = await Hive.openBox<School>('schoolBox');

    // Update school in Hive
    await box.put(updatedSchool.id, updatedSchool);

    // Send the updated school to MySQL
    await updateSchoolInMySQL(updatedSchool);

    await box.close();
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Delete a school and sync with MySQL
Future<void> deleteSchool(int id) async {
  try {
    // Delete the school from MySQL
    await deleteSchoolFromMySQL(id);

    // Optionally, fetch the updated list of schools
    await syncData();
  } catch (e) {
    print('Error: $e');
  }
}
