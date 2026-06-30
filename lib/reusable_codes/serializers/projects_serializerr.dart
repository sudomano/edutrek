import 'dart:convert';

import 'package:zitf_system/database/projects/project_model.dart';

Map<String, dynamic> projectsToJson(Project project) => {
      'projectCode': project.projectCode,
      'name': project.name,
      'description': project.description,
      'status': project.status,
      'createdAt': project.createdAt.toIso8601String(),
      'updatedAt': project.updatedAt.toIso8601String(),
      'syncStatus': project.syncStatus,
      'lastModified': project.lastModified?.toIso8601String(),
      'operationType': project.operationType,
      'modifiedFields': project.modifiedFields != null
          ? jsonEncode(project.modifiedFields)
          : null,
      'projectType': project.projectType,
      'participationType': project.participationType,
      'studentPayable': project.studentPayable,
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
      modifiedFields: json['modifiedFields'] != null
          ? List<String>.from(jsonDecode(json['modifiedFields']))
          : null,
      projectType: json['projectType'],
      participationType: json['participationType'],
      studentPayable: json['studentPayable'],
    );
