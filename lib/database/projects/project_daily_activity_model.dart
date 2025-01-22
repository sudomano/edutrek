import 'package:hive/hive.dart';

part 'project_daily_activity_model.g.dart';

@HiveType(typeId: 26)
class DailyActivity extends HiveObject {
  @HiveField(0)
  String projectDailyActiviyCode;

  @HiveField(1)
  String projectCode;

  @HiveField(2)
  DateTime date;

  @HiveField(3)
  String type; // "income" or "expense"

  @HiveField(4)
  String description;

  @HiveField(5)
  double amount;

  @HiveField(6)
  bool? syncStatus;

  @HiveField(7)
  DateTime? lastModified;

  @HiveField(8)
  String? operationType;

  @HiveField(9)
  List<String>? modifiedFields; // Tracks fields that were modified

  DailyActivity({
    required this.projectDailyActiviyCode,
    required this.projectCode,
    required this.date,
    required this.type,
    required this.description,
    required this.amount,
    this.syncStatus,
    this.lastModified,
    this.operationType,
    this.modifiedFields,
  });

  DailyActivity copyWith({
    String? projectDailyActiviyCode,
    String? projectCode,
    DateTime? date,
    String? type,
    String? description,
    double? amount,
    bool? syncStatus,
    DateTime? lastModified,
    String? operationType,
    List<String>? modifiedFields,
  }) {
    return DailyActivity(
      projectDailyActiviyCode:
          projectDailyActiviyCode ?? this.projectDailyActiviyCode,
      projectCode: projectCode ?? this.projectCode,
      date: date ?? this.date,
      type: type ?? this.type,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      operationType: operationType ?? this.operationType,
      modifiedFields: modifiedFields ?? this.modifiedFields,
    );
  }
}
