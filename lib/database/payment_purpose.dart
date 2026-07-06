import 'package:hive/hive.dart';
import 'package:zitf_system/database/exceptional_students/exceptional_students.dart';

part 'payment_purpose.g.dart';

@HiveType(typeId: 1)
class PaymentPurpose extends HiveObject {
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
  DateTime?
      lastModified; // Nullable field to track when the payment purpose was last modified

  @HiveField(6)
  String? operationType; // Nullable field for 'create', 'update', or 'delete'

  @HiveField(7)
  List<String>? associatedClasses; // List of associated class IDs or names

  @HiveField(8)
  String? purposeCode;

  @HiveField(9)
  List<String>? modifiedFields; // Tracks fields that were modified

  @HiveField(10)
  List<ExceptionalStudents>? exceptions; // Link to exception entries

  @HiveField(11)
  bool? forNewcomersOnly; // Whether this payment is only for newcomers
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

  PaymentPurpose({
    required this.id,
    required this.paymentPurpose,
    required this.purposeAmount,
    this.termId,
    this.syncStatus, // Can be null initially
    this.lastModified, // Can be null initially
    this.operationType, // Can be null initially
    this.associatedClasses, // Can be null initially
    this.purposeCode,
    this.modifiedFields,
    this.exceptions,
    this.forNewcomersOnly, // ✅ NEW
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
  PaymentPurpose copyWith({
    int? id,
    String? paymentPurpose,
    double? purposeAmount,
    String? termId,
    bool? syncStatus,
    DateTime? lastModified,
    String? operationType,
    List<String>? associatedClasses,
    String? purposeCode,
    List<String>? modifiedFields,
    List<ExceptionalStudents>? exceptions,
    bool? forNewcomersOnly, // ✅ NEW
  }) {
    return PaymentPurpose(
      id: id ?? this.id,
      paymentPurpose: paymentPurpose ?? this.paymentPurpose,
      purposeAmount: purposeAmount ?? this.purposeAmount,
      termId: termId ?? this.termId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      operationType: operationType ?? this.operationType,
      associatedClasses: associatedClasses ?? this.associatedClasses,
      purposeCode: purposeCode ?? this.purposeCode,
      modifiedFields: modifiedFields ?? this.modifiedFields,
      exceptions: exceptions ?? this.exceptions,
      forNewcomersOnly: forNewcomersOnly ?? this.forNewcomersOnly,
    );
  }
}
