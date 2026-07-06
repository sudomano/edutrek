import 'package:hive/hive.dart';

part 'payment_receipts_log.g.dart';

@HiveType(typeId: 55)
class PaymentLog extends HiveObject {
  @HiveField(0)
  int receiptNumber;

  @HiveField(1)
  String studentName;

  @HiveField(2)
  String className;

  @HiveField(3)
  String dateTime;

  @HiveField(4)
  List<Map<String, dynamic>> receiptLines; // FULL LineText list as JSON

  @HiveField(5)
  String? parentName;

  @HiveField(6)
  String? parentPhone;

  @HiveField(7)
  bool? isReprint;

  @HiveField(8)
  String? originalReceiptNumber;

  @HiveField(9)
  int? reprintCount;

  // ✅ CRITICAL: Sync Fields (MISSING - NOW ADDED)
  @HiveField(10)
  bool? syncStatus; // Nullable field to track sync status

  @HiveField(11)
  DateTime?
      lastModified; // Nullable field to track when the log was last modified

  @HiveField(12)
  String? operationType; // Nullable field for 'create', 'update', or 'delete'

  @HiveField(13)
  String? logId; // Unique identifier for sync (similar to classCode)

  @HiveField(14)
  List<String>? modifiedFields; // Tracks fields that were modified

// ✅ NEW: Deletion Fields
  @HiveField(15)
  bool? isDeleted; // Soft delete flag

  @HiveField(16)
  DateTime? deletedAt; // When deleted

  @HiveField(17)
  String? deletedBy; // Who deleted

  @HiveField(18)
  String? deleteReason; // Why deleted

  @HiveField(19)
  bool? deletedSyncStatus; // Track if deletion was synced

  PaymentLog({
    required this.receiptNumber,
    required this.studentName,
    required this.className,
    required this.dateTime,
    required this.receiptLines,
    this.parentName,
    this.parentPhone,
    this.isReprint,
    this.originalReceiptNumber,
    this.reprintCount,
    // ✅ New sync fields with defaults
    this.syncStatus,
    this.lastModified,
    this.operationType,
    this.logId,
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

  PaymentLog copyWith({
    int? receiptNumber,
    String? studentName,
    String? className,
    String? dateTime,
    List<Map<String, dynamic>>? receiptLines,
    String? parentName,
    String? parentPhone,
    bool? isReprint,
    String? originalReceiptNumber,
    int? reprintCount,
    bool? syncStatus,
    DateTime? lastModified,
    String? operationType,
    String? logId,
    List<String>? modifiedFields,
  }) {
    return PaymentLog(
      receiptNumber: receiptNumber ?? this.receiptNumber,
      studentName: studentName ?? this.studentName,
      className: className ?? this.className,
      dateTime: dateTime ?? this.dateTime,
      receiptLines: receiptLines ?? this.receiptLines,
      parentName: parentName ?? this.parentName,
      parentPhone: parentPhone ?? this.parentPhone,
      isReprint: isReprint ?? this.isReprint,
      originalReceiptNumber:
          originalReceiptNumber ?? this.originalReceiptNumber,
      reprintCount: reprintCount ?? this.reprintCount,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      operationType: operationType ?? this.operationType,
      logId: logId ?? this.logId,
      modifiedFields: modifiedFields ?? this.modifiedFields,
    );
  }
}
