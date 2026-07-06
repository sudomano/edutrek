import 'package:hive/hive.dart';

part 'terms.g.dart';

@HiveType(typeId: 21)
class Terms extends HiveObject {
  @HiveField(0)
  String termId;

  @HiveField(1)
  String termName;

  @HiveField(2)
  DateTime startDate;

  @HiveField(3)
  DateTime? endDate;

  @HiveField(4)
  bool isActive;

  @HiveField(5)
  String status;

  @HiveField(6)
  bool? syncStatus; // Nullable field to track sync status

  @HiveField(7)
  DateTime? lastModified; // Nullable field to track last modification time

  @HiveField(8)
  String? operationType; // Nullable field for 'create', 'update', or 'delete'

  @HiveField(9)
  int? id; // New field for unique identifier

  @HiveField(10)
  List<String>? modifiedFields; // Tracks fields that were modified
  // ✅ NEW: Deletion Fields
  @HiveField(11)
  bool? isDeleted; // Soft delete flag

  @HiveField(12)
  DateTime? deletedAt; // When deleted

  @HiveField(13)
  String? deletedBy; // Who deleted

  @HiveField(14)
  String? deleteReason; // Why deleted

  @HiveField(15)
  bool? deletedSyncStatus; // Track if deletion was synced

  Terms({
    required this.termId,
    required this.termName,
    required this.startDate,
    this.endDate,
    required this.isActive,
    required this.status,
    this.syncStatus,
    this.lastModified,
    this.operationType,
    this.id,
    this.modifiedFields,
    // ✅ New deletion fields
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
    this.deleteReason,
    this.deletedSyncStatus = false,
  });
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

  Terms copyWith({
    String? termId,
    String? termName,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    String? status,
    bool? syncStatus,
    DateTime? lastModified,
    String? operationType,
    int? id,
    List<String>? modifiedFields,
    // ✅ Deletion fields
    bool? isDeleted,
    DateTime? deletedAt,
    String? deletedBy,
    String? deleteReason,
    bool? deletedSyncStatus,
  }) {
    return Terms(
      termId: termId ?? this.termId,
      termName: termName ?? this.termName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      operationType: operationType ?? this.operationType,
      id: id ?? this.id,
      modifiedFields: modifiedFields ?? this.modifiedFields,
      // ✅ Include deletion fields
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      deleteReason: deleteReason ?? this.deleteReason,
      deletedSyncStatus: deletedSyncStatus ?? this.deletedSyncStatus,
    );
  }
}
