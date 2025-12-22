import 'dart:convert';

import 'package:zitf_system/database/accounting_module_models/account_type.dart';
import 'package:zitf_system/reusable_codes/serializers/utilities/parse_string_list.dart';

Map<String, dynamic> accountToJson(Account acc) => {
      'id': acc.id,
      'accountType': acc.accountType,
      'accountSubType': acc.accountSubType,
      'accountName': acc.accountName,
      'accountCode': acc.accountCode,
      'operationType': acc.operationType,
      'syncStatus': acc.syncStatus,
      'lastModified': acc.lastModified?.toIso8601String(),
      'isALiquidAccount': acc.isALiquidAccount,
      'modifiedFields': acc.modifiedFields != null
          ? jsonEncode(acc.modifiedFields) // JSON encode the list
          : null,
    };

Account accountFromJson(Map<String, dynamic> json) => Account(
      id: json['id'],
      accountType: json['accountType'],
      accountSubType: json['accountSubType'],
      accountName: json['accountName'],
      accountCode: json['accountCode'],
      operationType: json['operationType'],
      syncStatus: json['syncStatus'],
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null,
      isALiquidAccount: json['isALiquidAccount'],
      modifiedFields: parseStringList(json['modifiedFields']),
    );
