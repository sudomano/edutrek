import 'package:hive/hive.dart';

part 'project_item_model.g.dart';

@HiveType(typeId: 25)
class ProjectItem extends HiveObject {
  @HiveField(0)
  String projectItemCode;

  @HiveField(1)
  String projectCode;

  @HiveField(2)
  String name; // e.g., "Lab Fee"

  @HiveField(3)
  double amount;

  @HiveField(4)
  bool isStudentFee;

  @HiveField(5)
  bool? syncStatus;

  @HiveField(6)
  DateTime? lastModified;

  @HiveField(7)
  String? operationType;

  @HiveField(8)
  List<String>? modifiedFields; // Tracks fields that were modified

  ProjectItem({
    required this.projectItemCode,
    required this.projectCode,
    required this.name,
    required this.amount,
    required this.isStudentFee,
    this.syncStatus,
    this.lastModified,
    this.operationType,
    this.modifiedFields,
  });

  ProjectItem copyWith({
    String? projectItemCode,
    String? projectCode,
    String? name,
    double? amount,
    bool? isStudentFee,
    bool? syncStatus,
    DateTime? lastModified,
    String? operationType,
    List<String>? modifiedFields,
  }) {
    return ProjectItem(
      projectItemCode: projectItemCode ?? this.projectItemCode,
      projectCode: projectCode ?? this.projectCode,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      isStudentFee: isStudentFee ?? this.isStudentFee,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      operationType: operationType ?? this.operationType,
      modifiedFields: modifiedFields ?? this.modifiedFields,
    );
  }
}
