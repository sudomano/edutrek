import 'package:hive/hive.dart';

part 'project_item_model.g.dart';

@HiveType(typeId: 25)
class ProjectItem extends HiveObject {
  @HiveField(0)
  String? projectItemCode; // nullable for safety

  @HiveField(1)
  String? projectCode;

  @HiveField(2)
  String? name; // nullable

  /// goods | service
  @HiveField(3)
  String? itemType;

  @HiveField(4)
  bool? active; // make nullable

  @HiveField(5)
  bool? syncStatus;

  @HiveField(6)
  DateTime? lastModified;

  @HiveField(7)
  String? operationType;

  /// true if stock is tracked
  @HiveField(8)
  bool? trackStock; // nullable

  @HiveField(9)
  List<String>? modifiedFields; // already nullable

  ProjectItem({
    this.projectItemCode,
    this.projectCode,
    this.name,
    this.itemType,
    this.active,
    this.trackStock,
    this.syncStatus,
    this.lastModified,
    this.operationType,
    this.modifiedFields,
  });

  ProjectItem copyWith({
    String? projectItemCode,
    String? projectCode,
    String? name,
    String? itemType,
    bool? active,
    bool? trackStock,
    bool? syncStatus,
    DateTime? lastModified,
    String? operationType,
    List<String>? modifiedFields,
  }) {
    return ProjectItem(
      projectItemCode: projectItemCode ?? this.projectItemCode,
      projectCode: projectCode ?? this.projectCode,
      name: name ?? this.name,
      itemType: itemType ?? this.itemType,
      active: active ?? this.active,
      trackStock: trackStock ?? this.trackStock,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      operationType: operationType ?? this.operationType,
      modifiedFields: modifiedFields ?? this.modifiedFields,
    );
  }
}
