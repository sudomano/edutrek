import 'dart:convert';

import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/reusable_codes/serializers/utilities/parse_string_list.dart';

Map<String, dynamic> usersToJson(User user) => {
      'username': user.username,
      'password': user.password,
      'role': user.role,
      'securityQuestions': user.securityQuestions,
      'securityAnswers': user.securityAnswers,
      'phone': user.phone,
      'termId': user.termId,
      'syncStatus': user.syncStatus,
      'lastModified': user.lastModified?.toIso8601String(),
      'operationType': user.operationType,
      'id': user.id,
      'isLogged': user.isLogged,
      'userCode': user.userCode,
      'modifiedFields': user.modifiedFields != null
          ? jsonEncode(user.modifiedFields) // JSON encode the list
          : null,
      'email': user.email,
    };
User usersFromJson(Map<String, dynamic> json) => User(
      username: json['username'],
      password: json['password'],
      role: json['role'],
      securityQuestions: List<String>.from(json['securityQuestions']),
      securityAnswers: List<String>.from(json['securityAnswers']),
      phone: json['phone'],
      termId: json['termId'],
      syncStatus: json['syncStatus'],
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null,
      operationType: json['operationType'],
      id: json['id'],
      isLogged: json['isLogged'],
      userCode: json['userCode'],
      modifiedFields: parseStringList(json['modifiedFields']),
      email: json['email'],
    );
