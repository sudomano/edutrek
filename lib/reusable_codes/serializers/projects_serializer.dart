import 'dart:convert';

import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/reusable_codes/serializers/utilities/parse_string_list.dart';

Map<String, dynamic> projectsToJson(Project p) => {
      'projectCode': p.projectCode,
      'name': p.name,
      'description': p.description,
      'status': p.status,
      'createdAt': p.createdAt.toIso8601String(),
      'updatedAt': p.updatedAt.toIso8601String(),
      'syncStatus': p.syncStatus,
      'lastModified': p.lastModified?.toIso8601String(),
      'operationType': p.operationType,
      'modifiedFields': p.modifiedFields != null
          ? jsonEncode(p.modifiedFields) // JSON encode the list
          : null,
    };

Project projectsFromJson(Map<String, dynamic> json) => Project(
      projectCode: json['projectCode'],
      name: json['name'],
      description: json['description'],
      status: json['status'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      syncStatus: json['syncStatus'],
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null,
      operationType: json['operationType'],
      modifiedFields: parseStringList(json['modifiedFields']),
      projectType: json['projectType'],
      participationType: json['participationType'],
    );
