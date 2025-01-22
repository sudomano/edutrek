import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';

// Model class for Classes
class Classes {
  final int id;
  final String date;
  final String className;
  final int? termId;

  Classes({
    required this.id,
    required this.date,
    required this.className,
    this.termId,
  });

  // Factory method to create a Classes object from JSON
  factory Classes.fromJson(Map<String, dynamic> json) {
    return Classes(
      id: json['id'],
      date: json['date'],
      className: json['class_name'],
      termId: json['term_id'],
    );
  }

  // Method to convert Classes object to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'class_name': className,
      'term_id': termId,
    };
  }
}

// Function to fetch classes from the MySQL database via API
Future<List<Classes>> fetchClasses() async {
  final response = await http.get(Uri.parse(
      'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/classes'));

  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((data) => Classes.fromJson(data)).toList();
  } else {
    throw Exception('Failed to load classes');
  }
}

// Function to update local Hive database with fetched classes
Future<void> updateHiveWithFetchedClasses(List<Classes> classes) async {
  var box = await Hive.openBox<Classes>('classesBox');

  for (var cls in classes) {
    await box.put(cls.id, cls);
  }

  await box.close();
}

// Function to create a new class in MySQL
Future<void> createClassInMySQL(Classes newClass) async {
  final response = await http.post(
    Uri.parse(
        'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/classes'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(newClass.toJson()),
  );

  if (response.statusCode != 201) {
    throw Exception('Failed to create class');
  }
}

// Function to update a class in MySQL
Future<void> updateClassInMySQL(Classes updatedClass) async {
  final response = await http.put(
    Uri.parse(
        'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/classes/${updatedClass.id}'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(updatedClass.toJson()),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to update class');
  }
}

// Function to delete a class from MySQL
Future<void> deleteClassFromMySQL(int id) async {
  final response = await http.delete(
    Uri.parse(
        'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/classes/$id'),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to delete class');
  }
}

// Example usage: Sync data between MySQL and Hive
Future<void> syncData() async {
  try {
    // Fetch classes from MySQL
    List<Classes> classes = await fetchClasses();

    // Update local Hive database with fetched classes
    await updateHiveWithFetchedClasses(classes);
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Add a new class and sync with MySQL
Future<void> addNewClass(Classes newClass) async {
  try {
    // Create a new class in MySQL
    await createClassInMySQL(newClass);

    // Optionally, fetch the updated list of classes
    await syncData();
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Update class locally and sync with MySQL
Future<void> updateClassLocally(Classes updatedClass) async {
  try {
    // Open Hive box
    var box = await Hive.openBox<Classes>('classesBox');

    // Update class in Hive
    await box.put(updatedClass.id, updatedClass);

    // Send the updated class to MySQL
    await updateClassInMySQL(updatedClass);

    await box.close();
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Delete a class and sync with MySQL
Future<void> deleteClass(int id) async {
  try {
    // Delete the class from MySQL
    await deleteClassFromMySQL(id);

    // Optionally, fetch the updated list of classes
    await syncData();
  } catch (e) {
    print('Error: $e');
  }
}
