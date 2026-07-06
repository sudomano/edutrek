import 'package:hive/hive.dart';

part 'school_info.g.dart'; // Required for code generation

@HiveType(typeId: 14) // Unique identifier for Hive
class School extends HiveObject {
  @HiveField(0)
  late String? schoolName;

  @HiveField(1)
  late String? schoolAddress;

  @HiveField(2)
  late String? schoolPhoneNumber;

  @HiveField(3)
  late String? schoolEmail;

  @HiveField(4)
  String? termId; // Nullable termId

  @HiveField(5)
  bool? syncStatus; // Nullable field to track sync status

  @HiveField(6)
  DateTime? lastModified; // Nullable field to track last modification time

  @HiveField(7)
  String? operationType; // Nullable field for 'create', 'update', or 'delete'

  @HiveField(8)
  int? id; // New field for unique identifier

  @HiveField(9)
  String? schoolLogoPath; // New field to store the school logo image path

  @HiveField(10)
  String? schoolCode;

  @HiveField(11)
  List<String>? modifiedFields; // Tracks fields that were modified

  // ✅ NEW: Deletion Fields
  @HiveField(12)
  bool? isDeleted; // Soft delete flag

  @HiveField(13)
  DateTime? deletedAt; // When deleted

  @HiveField(14)
  String? deletedBy; // Who deleted

  @HiveField(15)
  String? deleteReason; // Why deleted

  @HiveField(16)
  bool? deletedSyncStatus; // Track if deletion was synced

  School({
    this.schoolName,
    this.schoolAddress,
    this.schoolPhoneNumber,
    this.schoolEmail,
    this.termId,
    this.syncStatus,
    this.lastModified,
    this.operationType,
    this.id,
    this.schoolLogoPath,
    this.schoolCode,
    this.modifiedFields,
    // ✅ New deletion fields
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
    this.deleteReason,
    this.deletedSyncStatus = false,
  });

  // ✅ Helper: Mark as deleted
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

  // ✅ Helper: Restore deleted
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

  // ✅ Helper: Check if deleted
  bool get isUserDeleted => isDeleted ?? false;

  // ✅ FIX: Updated copyWith to include all deletion fields
  School copyWith({
    String? schoolName,
    String? schoolAddress,
    String? schoolPhoneNumber,
    String? schoolEmail,
    String? termId,
    bool? syncStatus,
    DateTime? lastModified,
    String? operationType,
    int? id,
    String? schoolLogoPath,
    String? schoolCode,
    List<String>? modifiedFields,
    // ✅ New deletion fields
    bool? isDeleted,
    DateTime? deletedAt,
    String? deletedBy,
    String? deleteReason,
    bool? deletedSyncStatus,
  }) {
    return School(
      schoolName: schoolName ?? this.schoolName,
      schoolAddress: schoolAddress ?? this.schoolAddress,
      schoolPhoneNumber: schoolPhoneNumber ?? this.schoolPhoneNumber,
      schoolEmail: schoolEmail ?? this.schoolEmail,
      termId: termId ?? this.termId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      operationType: operationType ?? this.operationType,
      id: id ?? this.id,
      schoolLogoPath: schoolLogoPath ?? this.schoolLogoPath,
      schoolCode: schoolCode ?? this.schoolCode,
      modifiedFields: modifiedFields ?? this.modifiedFields,
      // ✅ Include deletion fields in copyWith
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      deleteReason: deleteReason ?? this.deleteReason,
      deletedSyncStatus: deletedSyncStatus ?? this.deletedSyncStatus,
    );
  }
}
