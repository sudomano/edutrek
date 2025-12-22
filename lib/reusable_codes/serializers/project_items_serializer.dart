import 'dart:convert';

import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/reusable_codes/serializers/utilities/parse_string_list.dart';

Map<String, dynamic> projectItemsToJson(ProjectItem i) => {
      'projectItemCode': i.projectItemCode,
      'projectCode': i.projectCode,
      'name': i.name,
      'amount': i.amount,
      'isStudentFee': i.isStudentFee,
      'syncStatus': i.syncStatus,
      'lastModified': i.lastModified?.toIso8601String(),
      'operationType': i.operationType,
      'modifiedFields': i.modifiedFields != null
          ? jsonEncode(i.modifiedFields) // JSON encode the list
          : null,
    };
ProjectItem projectItemsFromJson(Map<String, dynamic> json) => ProjectItem(
      projectItemCode: json['projectItemCode'],
      projectCode: json['projectCode'],
      name: json['name'],
      amount: json['amount'],
      isStudentFee: json['isStudentFee'],
      syncStatus: json['syncStatus'],
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null,
      operationType: json['operationType'],
      modifiedFields: parseStringList(json['modifiedFields']),
    );
