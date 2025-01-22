import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';

// Model class for User
class User {
  final int id;
  final String username;
  final String password;
  final String role;
  final List<String> securityQuestions;
  final List<String> securityAnswers;
  final String phone;
  final int? termId;

  User({
    required this.id,
    required this.username,
    required this.password,
    required this.role,
    required this.securityQuestions,
    required this.securityAnswers,
    required this.phone,
    this.termId,
  });

  // Factory method to create a User object from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      password: json['password'],
      role: json['role'],
      securityQuestions:
          List<String>.from(jsonDecode(json['securityQuestions'])),
      securityAnswers: List<String>.from(jsonDecode(json['securityAnswers'])),
      phone: json['phone'],
      termId: json['termId'],
    );
  }

  // Method to convert User object to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'role': role,
      'securityQuestions': jsonEncode(securityQuestions),
      'securityAnswers': jsonEncode(securityAnswers),
      'phone': phone,
      'termId': termId,
    };
  }
}

// API URL
const String apiUrl =
    'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/users';

// Function to fetch users from the API
Future<List<User>> fetchUsers() async {
  final response = await http.get(Uri.parse(apiUrl));

  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((data) => User.fromJson(data)).toList();
  } else {
    throw Exception('Failed to load users');
  }
}

// Function to fetch a specific user by ID
Future<User> fetchUserById(int id) async {
  final response = await http.get(Uri.parse('$apiUrl/$id'));

  if (response.statusCode == 200) {
    return User.fromJson(json.decode(response.body));
  } else {
    throw Exception('Failed to load user');
  }
}

// Function to create a new user in the API
Future<void> createUser(User newUser) async {
  final response = await http.post(
    Uri.parse(apiUrl),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(newUser.toJson()),
  );

  if (response.statusCode != 201) {
    throw Exception('Failed to create user');
  }
}

// Function to update an existing user in the API
Future<void> updateUser(User updatedUser) async {
  final response = await http.put(
    Uri.parse('$apiUrl/${updatedUser.id}'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(updatedUser.toJson()),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to update user');
  }
}

// Function to delete a user from the API
Future<void> deleteUser(int id) async {
  final response = await http.delete(
    Uri.parse('$apiUrl/$id'),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to delete user');
  }
}

// Function to update local Hive database with fetched users
Future<void> updateHiveWithFetchedUsers(List<User> users) async {
  var box = await Hive.openBox<User>('usersBox');

  for (var user in users) {
    await box.put(user.id, user);
  }

  await box.close();
}

// Example usage: Sync data between API and Hive
Future<void> syncUsers() async {
  try {
    // Fetch users from API
    List<User> users = await fetchUsers();

    // Update local Hive database with fetched users
    await updateHiveWithFetchedUsers(users);
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Add a new user and sync with API
Future<void> addNewUser(User newUser) async {
  try {
    // Create a new user in the API
    await createUser(newUser);

    // Optionally, fetch the updated list of users
    await syncUsers();
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Update user locally and sync with API
Future<void> updateUserLocally(User updatedUser) async {
  try {
    // Open Hive box
    var box = await Hive.openBox<User>('usersBox');

    // Update user in Hive
    await box.put(updatedUser.id, updatedUser);

    // Send the updated user to API
    await updateUser(updatedUser);

    await box.close();
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Delete a user and sync with API
Future<void> deleteUserLocally(int id) async {
  try {
    // Delete the user from API
    await deleteUser(id);

    // Optionally, fetch the updated list of users
    await syncUsers();
  } catch (e) {
    print('Error: $e');
  }
}
