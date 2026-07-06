import 'package:hive/hive.dart';

part 'classes.g.dart'; // Required for code generation

@HiveType(typeId: 4) // Unique identifier for Hive
class Classes extends HiveObject {
  @HiveField(0)
  late int id;

  @HiveField(1)
  late DateTime date;

  @HiveField(2)
  late String className;

  @HiveField(3)
  String? termId; // Nullable termId

  @HiveField(4)
  bool? syncStatus; // Nullable field to track sync status

  @HiveField(5)
  DateTime?
      lastModified; // Nullable field to track when the class was last modified

  @HiveField(6)
  String? operationType; // Nullable field for 'create', 'update', or 'delete'
  @HiveField(7)
  String? classCode;

  @HiveField(8)
  List<String>? modifiedFields; // Tracks fields that were modified

  @HiveField(9)
  List<String>? terms;

  // ✅ NEW: Deletion Fields
  @HiveField(10)
  bool? isDeleted; // Soft delete flag

  @HiveField(11)
  DateTime? deletedAt; // When deleted

  @HiveField(12)
  String? deletedBy; // Who deleted

  @HiveField(13)
  String? deleteReason; // Why deleted

  @HiveField(14)
  bool? deletedSyncStatus; // Track if deletion was synced

  Classes({
    required this.id,
    required this.date,
    required this.className,
    this.termId,
    this.syncStatus, // Can be null initially
    this.lastModified, // Can be null initially
    this.operationType, // Can be null initially
    this.classCode,
    this.modifiedFields,
    List<String>? terms,
    // ✅ New deletion fields
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
    this.deleteReason,
    this.deletedSyncStatus = false,
  }) : terms = terms ?? [];
  // ✅ Helper: Mark user as deleted
  void markDeleted({
    required String deletedBy,
    String? reason,
  }) {
    isDeleted = true;
    deletedAt = DateTime.now();
    this.deletedBy = deletedBy;
    deleteReason = reason;
    syncStatus = false;
    deletedSyncStatus = false;
    operationType = 'delete';
    lastModified = DateTime.now();
    modifiedFields = ['isDeleted', 'deletedAt', 'deletedBy', 'deleteReason'];
  }

  // ✅ Helper: Restore deleted user
  void restoreDeleted() {
    isDeleted = false;
    deletedAt = null;
    deletedBy = null;
    deleteReason = null;
    syncStatus = false;
    deletedSyncStatus = false;
    operationType = 'update';
    lastModified = DateTime.now();
    modifiedFields = ['isDeleted', 'deletedAt', 'deletedBy', 'deleteReason'];
  }

  // ✅ Helper: Check if user is deleted
  bool get isUserDeleted => isDeleted ?? false;

  Classes copyWith({
    int? id,
    DateTime? date,
    String? className,
    String? termId,
    bool? syncStatus,
    DateTime? lastModified,
    String? operationType,
    String? classCode,
    List<String>? modifiedFields,
    List<String>? terms,
    // ✅ Deletion fields
    bool? isDeleted,
    DateTime? deletedAt,
    String? deletedBy,
    String? deleteReason,
    bool? deletedSyncStatus,
  }) {
    return Classes(
      id: id ?? this.id,
      date: date ?? this.date,
      className: className ?? this.className,
      termId: termId ?? this.termId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      operationType: operationType ?? this.operationType,
      classCode: classCode ?? this.classCode,
      modifiedFields: modifiedFields ?? this.modifiedFields,
      terms: terms ?? this.terms,
      // ✅ Include deletion fields
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      deleteReason: deleteReason ?? this.deleteReason,
      deletedSyncStatus: deletedSyncStatus ?? this.deletedSyncStatus,
    );
  }
}
