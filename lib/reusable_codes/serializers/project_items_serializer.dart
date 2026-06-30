import 'dart:convert';

import 'package:zitf_system/database/projects/project_item_model.dart';

Map<String, dynamic> projectItemsToJson(ProjectItem projectItem) => {
      'projectItemCode': projectItem.projectItemCode,
      'projectCode': projectItem.projectCode,
      'name': projectItem.name,
      'itemType': projectItem.itemType,
      'active': projectItem.active,
      'trackStock': projectItem.trackStock,
      'syncStatus': projectItem.syncStatus,
      'lastModified': projectItem.lastModified?.toIso8601String(),
      'operationType': projectItem.operationType,
      'modifiedFields': projectItem.modifiedFields != null
          ? jsonEncode(projectItem.modifiedFields)
          : null,
    };

ProjectItem projectItemsFromJson(Map<String, dynamic> json) => ProjectItem(
      projectItemCode: json['projectItemCode'],
      projectCode: json['projectCode'],
      name: json['name'],
      itemType: json['itemType'],
      active: json['active'],
      trackStock: json['trackStock'],
      syncStatus: json['syncStatus'],
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null,
      operationType: json['operationType'],
      modifiedFields: json['modifiedFields'] != null
          ? List<String>.from(jsonDecode(json['modifiedFields']))
          : null,
    );
