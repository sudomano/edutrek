import 'package:hive/hive.dart';

part 'teacher_payments.g.dart';

@HiveType(typeId: 12)
class TeacherPayment extends HiveObject {
  @HiveField(0)
  String studentName; // Student's name

  @HiveField(1)
  String studentSurname; // Student's surname

  @HiveField(2)
  String studentClass; // Student's class

  @HiveField(3)
  String phoneNumber; // Student's phone number

  @HiveField(4)
  String paymentPurpose; // Payment purpose

  @HiveField(5)
  double amountToPay; // Payment amount

  @HiveField(6)
  DateTime paymentDate; // Payment date

  @HiveField(7)
  String? termId; // Nullable termId

  @HiveField(8)
  bool? syncStatus; // Nullable field to track sync status

  @HiveField(9)
  DateTime? lastModified; // Nullable field to track last modification time

  @HiveField(10)
  String? operationType; // Nullable field for 'create', 'update', or 'delete'

  @HiveField(11)
  int? id; // New field for unique identifier

  @HiveField(12)
  List<String>? associatedStaff; // List of associated class IDs or names

  @HiveField(13)
  String? receiptNumber;

  @HiveField(14)
  List<String>? modifiedFields; // Tracks fields that were modified

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
  TeacherPayment({
    required this.studentName,
    required this.studentSurname,
    required this.studentClass,
    required this.phoneNumber,
    required this.paymentPurpose,
    required this.amountToPay,
    required this.paymentDate,
    this.termId,
    this.syncStatus,
    this.lastModified,
    this.operationType,
    this.id,
    this.associatedStaff,
    this.receiptNumber,
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

  TeacherPayment copyWith({
    String? studentName,
    String? studentSurname,
    String? studentClass,
    String? phoneNumber,
    String? paymentPurpose,
    double? amountToPay,
    DateTime? paymentDate,
    String? termId,
    bool? syncStatus,
    DateTime? lastModified,
    String? operationType,
    int? id,
    List<String>? associatedStaff,
    String? receiptNumber,
    List<String>? modifiedFields,
  }) {
    return TeacherPayment(
      studentName: studentName ?? this.studentName,
      studentSurname: studentSurname ?? this.studentSurname,
      studentClass: studentClass ?? this.studentClass,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      paymentPurpose: paymentPurpose ?? this.paymentPurpose,
      amountToPay: amountToPay ?? this.amountToPay,
      paymentDate: paymentDate ?? this.paymentDate,
      termId: termId ?? this.termId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      operationType: operationType ?? this.operationType,
      id: id ?? this.id,
      associatedStaff: associatedStaff ?? this.associatedStaff,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      modifiedFields: modifiedFields ?? this.modifiedFields,
    );
  }
}
