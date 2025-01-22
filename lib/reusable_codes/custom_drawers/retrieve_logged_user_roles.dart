Map<String, bool> getUserRoles(String role) {
  // Initialize roles to false
  bool secretary = false;
  bool admin = false;
  bool guest = false;

  // Normalize the role string to lowercase and compare
  if (role.toLowerCase() == "secretary") {
    secretary = true;
  } else if (role.toLowerCase() == "admin") {
    admin = true;
  } else {
    guest = true;
  }

  // Return a map containing the role status
  return {
    'secretary': secretary,
    'admin': admin,
    'guest': guest,
  };
}


/*
  final role = loggedInUser.role;
    final user = loggedInUser.username;
    bool secretary = false;
    bool admin = false;
    bool guest = false;
    if (role.toLowerCase() == "secretary") {
      secretary = true;
    } else if (role.toLowerCase() == "admin") {
      admin = true;
    } else {
      guest = true;
    }

   if (admin || secretary)

                                  


*/