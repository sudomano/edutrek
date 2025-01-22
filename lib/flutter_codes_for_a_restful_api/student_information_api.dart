import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';

// Model class for Student
class Student {
  final int id;
  final String name;
  final String surname;
  final String regNumber;
  final String className;
  final String gender;
  final int age;
  final String phoneNumber;
  final String paymentStatus;
  final bool isPresent;
  final String? presentDates;
  final String? absentDates;
  final int? termId;

  Student({
    required this.id,
    required this.name,
    required this.surname,
    required this.regNumber,
    required this.className,
    required this.gender,
    required this.age,
    required this.phoneNumber,
    required this.paymentStatus,
    this.isPresent = true,
    this.presentDates,
    this.absentDates,
    this.termId,
  });

  // Factory method to create a Student object from JSON
  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'],
      name: json['name'],
      surname: json['surname'],
      regNumber: json['regNumber'],
      className: json['class'],
      gender: json['gender'],
      age: json['age'],
      phoneNumber: json['phoneNumber'],
      paymentStatus: json['paymentStatus'],
      isPresent: json['isPresent'],
      presentDates: json['presentDates'],
      absentDates: json['absentDates'],
      termId: json['termId'],
    );
  }

  // Method to convert Student object to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'surname': surname,
      'regNumber': regNumber,
      'class': className,
      'gender': gender,
      'age': age,
      'phoneNumber': phoneNumber,
      'paymentStatus': paymentStatus,
      'isPresent': isPresent,
      'presentDates': presentDates,
      'absentDates': absentDates,
      'termId': termId,
    };
  }
}

// Function to fetch students from the MySQL database via API
Future<List<Student>> fetchStudents() async {
  final response = await http.get(Uri.parse(
      'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/students'));

  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((data) => Student.fromJson(data)).toList();
  } else {
    throw Exception('Failed to load students');
  }
}

// Function to update local Hive database with fetched students
Future<void> updateHiveWithFetchedStudents(List<Student> students) async {
  var box = await Hive.openBox<Student>('studentsBox');

  for (var student in students) {
    await box.put(student.id, student);
  }

  await box.close();
}

// Function to create a new student in MySQL
Future<void> createStudentInMySQL(Student newStudent) async {
  final response = await http.post(
    Uri.parse(
        'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/students'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(newStudent.toJson()),
  );

  if (response.statusCode != 201) {
    throw Exception('Failed to create student');
  }
}

// Function to update a student in MySQL
Future<void> updateStudentInMySQL(Student updatedStudent) async {
  final response = await http.put(
    Uri.parse(
        'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/students/${updatedStudent.id}'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(updatedStudent.toJson()),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to update student');
  }
}

// Function to delete a student from MySQL
Future<void> deleteStudentFromMySQL(int id) async {
  final response = await http.delete(
    Uri.parse(
        'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/students/$id'),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to delete student');
  }
}

// Example usage: Sync data between MySQL and Hive
Future<void> syncData() async {
  try {
    // Fetch students from MySQL
    List<Student> students = await fetchStudents();

    // Update local Hive database with fetched students
    await updateHiveWithFetchedStudents(students);
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Add a new student and sync with MySQL
Future<void> addNewStudent(Student newStudent) async {
  try {
    // Create a new student in MySQL
    await createStudentInMySQL(newStudent);

    // Optionally, fetch the updated list of students
    await syncData();
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Update student locally and sync with MySQL
Future<void> updateStudentLocally(Student updatedStudent) async {
  try {
    // Open Hive box
    var box = await Hive.openBox<Student>('studentsBox');

    // Update student in Hive
    await box.put(updatedStudent.id, updatedStudent);

    // Send the updated student to MySQL
    await updateStudentInMySQL(updatedStudent);

    await box.close();
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Delete a student and sync with MySQL
Future<void> deleteStudent(int id) async {
  try {
    // Delete the student from MySQL
    await deleteStudentFromMySQL(id);

    // Optionally, fetch the updated list of students
    await syncData();
  } catch (e) {
    print('Error: $e');
  }
}
