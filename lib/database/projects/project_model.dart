import 'package:hive/hive.dart';

part 'project_model.g.dart';

@HiveType(typeId: 24)
class Project extends HiveObject {
  @HiveField(0)
  String projectCode;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? description;

  @HiveField(3)
  String status; // e.g., "active", "closed"

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime updatedAt;

  @HiveField(6)
  bool? syncStatus; // Nullable field to track sync status

  @HiveField(7)
  DateTime? lastModified; // Nullable field to track last modification time

  @HiveField(8)
  String? operationType; // Nullable field for 'create', 'update', or 'delete'

  @HiveField(9)
  List<String>? modifiedFields; // Tracks fields that were modified

  Project({
    required this.projectCode,
    required this.name,
    this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus,
    this.lastModified,
    this.operationType,
    this.modifiedFields,
  });

  Project copyWith({
    String? projectCode,
    String? name,
    String? description,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? syncStatus,
    DateTime? lastModified,
    String? operationType,
    List<String>? modifiedFields,
  }) {
    return Project(
      projectCode: projectCode ?? this.projectCode,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      operationType: operationType ?? this.operationType,
      modifiedFields: modifiedFields ?? this.modifiedFields,
    );
  }
}
