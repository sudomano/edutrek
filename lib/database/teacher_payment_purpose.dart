import 'package:hive/hive.dart';

part 'teacher_payment_purpose.g.dart';

@HiveType(typeId: 11)
class TeacherPaymentsPurposes extends HiveObject {
  @HiveField(0)
  int id; // Unique identifier

  @HiveField(1)
  String paymentPurpose; // Name of the payment purpose

  @HiveField(2)
  double purposeAmount; // Amount for the payment purpose

  @HiveField(3)
  String? termId; // Nullable termId

  @HiveField(4)
  bool? syncStatus; // Nullable field to track sync status

  @HiveField(5)
  DateTime? lastModified; // Nullable field to track last modification time

  @HiveField(6)
  String? operationType; // Nullable field for 'create', 'update', or 'delete'

  @HiveField(7)
  List<String>? associatedStaff; // List of associated class IDs or names

  @HiveField(8)
  String? purposeCode;

  @HiveField(9)
  List<String>? modifiedFields; // Tracks fields that were modified

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

  TeacherPaymentsPurposes({
    required this.id,
    required this.paymentPurpose,
    required this.purposeAmount,
    this.termId,
    this.syncStatus,
    this.lastModified,
    this.operationType,
    this.associatedStaff,
    this.purposeCode,
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

  TeacherPaymentsPurposes copyWith({
    int? id,
    String? paymentPurpose,
    double? purposeAmount,
    String? termId,
    bool? syncStatus,
    DateTime? lastModified,
    String? operationType,
    List<String>? associatedStaff, // List of associated class IDs or names
    String? purposeCode,
    List<String>? modifiedFields,
  }) {
    return TeacherPaymentsPurposes(
      id: id ?? this.id,
      paymentPurpose: paymentPurpose ?? this.paymentPurpose,
      purposeAmount: purposeAmount ?? this.purposeAmount,
      termId: termId ?? this.termId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      operationType: operationType ?? this.operationType,
      associatedStaff: associatedStaff ?? this.associatedStaff,
      purposeCode: purposeCode ?? this.purposeCode,
      modifiedFields: modifiedFields ?? this.modifiedFields,
    );
  }
}
