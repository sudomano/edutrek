import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';

// Model class for Teacher
class Teacher {
  final int id;
  final String name;
  final String surname;
  final String idNumber;
  final String? assignedClass;
  final String gender;
  final String dateOfBirth;
  final String phoneNumber;
  final String paymentPurpose;
  final bool isPaid;
  final double paymentAmount;
  final String? paymentDate;
  final String email;
  final String address;
  final String hireDate;
  final String qualifications;
  final String employmentStatus;
  final int? termId;

  Teacher({
    required this.id,
    required this.name,
    required this.surname,
    required this.idNumber,
    this.assignedClass,
    required this.gender,
    required this.dateOfBirth,
    required this.phoneNumber,
    required this.paymentPurpose,
    required this.isPaid,
    required this.paymentAmount,
    this.paymentDate,
    required this.email,
    required this.address,
    required this.hireDate,
    required this.qualifications,
    required this.employmentStatus,
    this.termId,
  });

  // Factory method to create a Teacher object from JSON
  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: json['id'],
      name: json['name'],
      surname: json['surname'],
      idNumber: json['IdNumber'],
      assignedClass: json['assignedClass'],
      gender: json['gender'],
      dateOfBirth: json['dateOfBirth'],
      phoneNumber: json['phoneNumber'],
      paymentPurpose: json['paymentPurpose'],
      isPaid: json['isPaid'] == 1,
      paymentAmount: json['paymentAmount'],
      paymentDate: json['paymentDate'],
      email: json['email'],
      address: json['address'],
      hireDate: json['hireDate'],
      qualifications: json['qualifications'],
      employmentStatus: json['employmentStatus'],
      termId: json['termId'],
    );
  }

  // Method to convert Teacher object to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'surname': surname,
      'IdNumber': idNumber,
      'assignedClass': assignedClass,
      'gender': gender,
      'dateOfBirth': dateOfBirth,
      'phoneNumber': phoneNumber,
      'paymentPurpose': paymentPurpose,
      'isPaid': isPaid ? 1 : 0,
      'paymentAmount': paymentAmount,
      'paymentDate': paymentDate,
      'email': email,
      'address': address,
      'hireDate': hireDate,
      'qualifications': qualifications,
      'employmentStatus': employmentStatus,
      'termId': termId,
    };
  }
}

// Function to fetch teachers from the MySQL database via API
Future<List<Teacher>> fetchTeachers() async {
  final response = await http.get(Uri.parse(
      'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/teachers'));

  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((data) => Teacher.fromJson(data)).toList();
  } else {
    throw Exception('Failed to load teachers');
  }
}

// Function to update local Hive database with fetched teachers
Future<void> updateHiveWithFetchedTeachers(List<Teacher> teachers) async {
  var box = await Hive.openBox<Teacher>('teachersBox');

  for (var teacher in teachers) {
    await box.put(teacher.id, teacher);
  }

  await box.close();
}

// Function to create a new teacher in MySQL
Future<void> createTeacherInMySQL(Teacher newTeacher) async {
  final response = await http.post(
    Uri.parse(
        'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/teachers'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(newTeacher.toJson()),
  );

  if (response.statusCode != 201) {
    throw Exception('Failed to create teacher');
  }
}

// Function to update a teacher in MySQL
Future<void> updateTeacherInMySQL(Teacher updatedTeacher) async {
  final response = await http.put(
    Uri.parse(
        'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/teachers/${updatedTeacher.id}'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(updatedTeacher.toJson()),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to update teacher');
  }
}

// Function to delete a teacher from MySQL
Future<void> deleteTeacherFromMySQL(int id) async {
  final response = await http.delete(
    Uri.parse(
        'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/teachers/$id'),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to delete teacher');
  }
}

// Example usage: Sync data between MySQL and Hive
Future<void> syncTeachers() async {
  try {
    // Fetch teachers from MySQL
    List<Teacher> teachers = await fetchTeachers();

    // Update local Hive database with fetched teachers
    await updateHiveWithFetchedTeachers(teachers);
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Add a new teacher and sync with MySQL
Future<void> addNewTeacher(Teacher newTeacher) async {
  try {
    // Create a new teacher in MySQL
    await createTeacherInMySQL(newTeacher);

    // Optionally, fetch the updated list of teachers
    await syncTeachers();
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Update teacher locally and sync with MySQL
Future<void> updateTeacherLocally(Teacher updatedTeacher) async {
  try {
    // Open Hive box
    var box = await Hive.openBox<Teacher>('teachersBox');

    // Update teacher in Hive
    await box.put(updatedTeacher.id, updatedTeacher);

    // Send the updated teacher to MySQL
    await updateTeacherInMySQL(updatedTeacher);

    await box.close();
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Delete a teacher and sync with MySQL
Future<void> deleteTeacher(int id) async {
  try {
    // Delete the teacher from MySQL
    await deleteTeacherFromMySQL(id);

    // Optionally, fetch the updated list of teachers
    await syncTeachers();
  } catch (e) {
    print('Error: $e');
  }
}
