import 'dart:convert';

import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/reusable_codes/serializers/utilities/parse_string_list.dart';

Map<String, dynamic> usersToJson(User user) => {
      'username': user.username,
      'password': user.password,
      'role': user.role,
      'securityQuestions':
          user.securityQuestions.isNotEmpty ? user.securityQuestions : [],
      'securityAnswers':
          user.securityAnswers.isNotEmpty ? user.securityAnswers : [],
      'phone': user.phone,
      'termId': user.termId,
      'syncStatus': user.syncStatus,
      'lastModified': user.lastModified?.toIso8601String(),
      'operationType': user.operationType,
      'id': user.id,
      'isLogged': user.isLogged,
      'userCode': user.userCode,
      'modifiedFields':
          user.modifiedFields != null && user.modifiedFields!.isNotEmpty
              ? jsonEncode(user.modifiedFields)
              : null,
      'email': user.email,
      'assignedClasses': user.assignedClasses ?? [],
      'isActive': user.isActive ?? true,
      'createdAt': user.createdAt?.toIso8601String(),
    };

User usersFromJson(Map<String, dynamic> json) {
  // ✅ Helper to parse security questions/answers safely
  List<String> parseStringListSafe(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return List<String>.from(value);
    }
    if (value is String) {
      // If it's a string, try to parse it as JSON or split it
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return List<String>.from(decoded);
        }
      } catch (_) {
        // If it's a plain string, return as a single-element list or split by comma
        if (value.isEmpty) return [];
        return value.split(',').map((e) => e.trim()).toList();
      }
    }
    return [];
  }

  return User(
    username: json['username'] ?? '',
    password: json['password'] ?? '',
    role: json['role'] ?? '',
    securityQuestions: parseStringListSafe(json['securityQuestions']),
    securityAnswers: parseStringListSafe(json['securityAnswers']),
    phone: json['phone'] ?? '',
    termId: json['termId'],
    syncStatus: json['syncStatus'] ?? true,
    lastModified: json['lastModified'] != null
        ? DateTime.parse(json['lastModified'])
        : null,
    operationType: json['operationType'] ?? 'create',
    id: json['id'],
    isLogged: json['isLogged'] ?? false,
    userCode: json['userCode'] ?? '',
    modifiedFields: json['modifiedFields'] != null
        ? parseStringListSafe(json['modifiedFields'])
        : [],
    email: json['email'],
    assignedClasses: json['assignedClasses'] != null
        ? parseStringListSafe(json['assignedClasses'])
        : [],
    isActive: json['isActive'] ?? true,
    createdAt:
        json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
  );
}
