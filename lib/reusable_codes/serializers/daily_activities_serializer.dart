import 'dart:convert';

import 'package:zitf_system/database/projects/project_daily_activity_model.dart';
import 'package:zitf_system/reusable_codes/serializers/utilities/parse_string_list.dart';

Map<String, dynamic> dailyActivitiesToJson(DailyActivity a) => {
      'projectDailyActiviyCode': a.projectDailyActiviyCode,
      'projectCode': a.projectCode,
      'date': a.date.toIso8601String(),
      'type': a.type,
      'description': a.description,
      'amount': a.amount,
      'syncStatus': a.syncStatus,
      'lastModified': a.lastModified?.toIso8601String(),
      'operationType': a.operationType,
      'modifiedFields': a.modifiedFields != null
          ? jsonEncode(a.modifiedFields) // JSON encode the list
          : null,
    };

DailyActivity dailyActivitiesFromJson(Map<String, dynamic> json) =>
    DailyActivity(
      projectDailyActiviyCode: json['projectDailyActiviyCode'],
      projectCode: json['projectCode'],
      date: DateTime.parse(json['date']),
      type: json['type'],
      description: json['description'],
      amount: json['amount'],
      syncStatus: json['syncStatus'],
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null,
      operationType: json['operationType'],
      modifiedFields: parseStringList(json['modifiedFields']),
    );
