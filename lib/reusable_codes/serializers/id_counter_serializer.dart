// id_counter_serializer.dart

import 'package:zitf_system/database/id_counter.dart';

Map<String, dynamic> idCounterToJson(IdCounter counter) {
  return {
    'lastAssignedId': counter.lastAssignedId,
    'lastUpdated': counter.lastUpdated.toIso8601String(),
    'totalIdsAssigned': counter.totalIdsAssigned,
    'lastClientId': counter.lastClientId,
  };
}

IdCounter idCounterFromJson(Map<String, dynamic> json) {
  return IdCounter(
    lastAssignedId: json['lastAssignedId'] ?? 0,
    lastUpdated: json['lastUpdated'] != null
        ? DateTime.parse(json['lastUpdated'])
        : DateTime.now(),
    totalIdsAssigned: json['totalIdsAssigned'] ?? 0,
    lastClientId: json['lastClientId'],
  );
}

List<IdCounter> idCountersFromJson(List<dynamic> jsonList) {
  return jsonList
      .map((json) => idCounterFromJson(Map<String, dynamic>.from(json)))
      .toList();
}

List<Map<String, dynamic>> idCountersToJson(List<IdCounter> counters) {
  return counters.map((counter) => idCounterToJson(counter)).toList();
}
