import 'package:hive/hive.dart';
import 'package:zitf_system/auth/userdb.dart';

// Function to fetch the logged-in user
User getLoggedInUser() {
  final userBox = Hive.box<User>('users');

  // Find the user with isLogged flag set to true
  final loggedInUser = userBox.values.firstWhere(
    (user) => user.isLogged == true,
    orElse: () => User(
      role: 'guest',
      username: 'Guest',
      password: '',
      securityQuestions: [],
      securityAnswers: [],
      phone: '',
    ),
  );

  return loggedInUser;
}



/*
    final loggedInUser = getLoggedInUser();

*/