import 'dart:convert';

import 'package:zitf_system/database/syncConfigs/syncConfig.dart';
import 'package:zitf_system/reusable_codes/serializers/utilities/parse_string_list.dart';

Map<String, dynamic> domainsToJson(DomainRecord domain) => {
      'domainName': domain.domainName,
      'areDomainsActive': domain.areDomainsActive,
      'syncStatus': domain.syncStatus,
      'operationType': domain.operationType,
      'lastModified': domain.lastModified?.toIso8601String(),
      'modifiedFields': domain.modifiedFields != null
          ? jsonEncode(domain.modifiedFields) // JSON encode the list
          : null,
    };

DomainRecord domainsFromJson(Map<String, dynamic> json) => DomainRecord(
      domainName: json['domainName'],
      areDomainsActive: json['areDomainsActive'],
      syncStatus: json['syncStatus'],
      operationType: json['operationType'],
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null,
      modifiedFields: parseStringList(json['modifiedFields']),
    );
