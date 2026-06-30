import 'package:zitf_system/database/id_range.dart';

Map<String, dynamic> idRangeToJson(IdRange range) {
  return {
    'startId': range.startId,
    'endId': range.endId,
    'assignedTo': range.assignedTo,
    'assignedAt': range.assignedAt.toIso8601String(),
    'isFullyUsed': range.isFullyUsed,
  };
}

IdRange idRangeFromJson(Map<String, dynamic> json) {
  return IdRange(
    startId: json['startId'] ?? 0,
    endId: json['endId'] ?? 0,
    assignedTo: json['assignedTo'] ?? 'unknown',
    assignedAt: json['assignedAt'] != null
        ? DateTime.parse(json['assignedAt'])
        : DateTime.now(),
    isFullyUsed: json['isFullyUsed'] ?? false,
  );
}

List<IdRange> idRangesFromJson(List<dynamic> jsonList) {
  return jsonList
      .map((json) => idRangeFromJson(Map<String, dynamic>.from(json)))
      .toList();
}

List<Map<String, dynamic>> idRangesToJson(List<IdRange> ranges) {
  return ranges.map((range) => idRangeToJson(range)).toList();
}

// Specialized methods
Map<String, dynamic> idRangeSummaryToJson(IdRange range) {
  return {
    'range': '${range.startId} - ${range.endId}',
    'count': range.endId - range.startId + 1,
    'assignedTo': range.assignedTo,
    'assignedAt': range.assignedAt.toIso8601String(),
    'isFullyUsed': range.isFullyUsed,
  };
}
