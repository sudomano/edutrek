import 'package:hive/hive.dart';

part 'student_payments.g.dart';

@HiveType(typeId: 2)
class StudentPayment extends HiveObject {
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
  String? studentRegNumber;

  @HiveField(13)
  String? receiptNumber;
  @HiveField(14)
  List<String>? modifiedFields; // Tracks fields that were modified

  @HiveField(15)
  String? username;

  @HiveField(16)
  String? role;

  @HiveField(17, defaultValue: 'cash')
  String paymentMethodType;

  @HiveField(18, defaultValue: 0.0)
  double paymentMethodAmount;

  @HiveField(19, defaultValue: '')
  String paymentReference;

  @HiveField(20, defaultValue: '')
  String mobileMoneyPhone;

  @HiveField(21, defaultValue: '')
  String mobileMoneyProvider;

  @HiveField(22, defaultValue: '')
  String bankAccountNumber;

  @HiveField(23, defaultValue: '')
  String bankAccountName;

  @HiveField(24, defaultValue: 0.0)
  double changeGiven;

  // ✅ NEW: Deletion Fields
  @HiveField(25)
  bool? isDeleted; // Soft delete flag

  @HiveField(26)
  DateTime? deletedAt; // When deleted

  @HiveField(27)
  String? deletedBy; // Who deleted

  @HiveField(28)
  String? deleteReason; // Why deleted

  @HiveField(29)
  bool? deletedSyncStatus; // Track if deletion was synced

  StudentPayment({
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
    this.receiptNumber,
    this.studentRegNumber,
    this.modifiedFields,
    this.username, // ✅ NEW
    this.role, // ✅ NEW
    this.paymentMethodType = 'cash',
    this.paymentMethodAmount = 0.0,
    this.paymentReference = '',
    this.mobileMoneyPhone = '',
    this.mobileMoneyProvider = '',
    this.bankAccountNumber = '',
    this.bankAccountName = '',
    this.changeGiven = 0.0,
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

  StudentPayment copyWith({
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
    String? studentRegNumber,
    String? receiptNumber,
    List<String>? modifiedFields,
    String? username, // ✅ NEW
    String? role, // ✅ NEW

    String? paymentMethodType,
    double? paymentMethodAmount,
    String? paymentReference,
    String? mobileMoneyPhone,
    String? mobileMoneyProvider,
    String? bankAccountNumber,
    String? bankAccountName,
    double? changeGiven,
    // ✅ Deletion fields
    bool? isDeleted,
    DateTime? deletedAt,
    String? deletedBy,
    String? deleteReason,
    bool? deletedSyncStatus,
  }) {
    return StudentPayment(
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
      studentRegNumber: studentRegNumber ?? this.studentRegNumber,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      modifiedFields: modifiedFields ?? this.modifiedFields,
      username: username ?? this.username, // ✅
      role: role ?? this.role, // ✅
      paymentMethodType: paymentMethodType ?? this.paymentMethodType,
      paymentMethodAmount: paymentMethodAmount ?? this.paymentMethodAmount,
      paymentReference: paymentReference ?? this.paymentReference,
      mobileMoneyPhone: mobileMoneyPhone ?? this.mobileMoneyPhone,
      mobileMoneyProvider: mobileMoneyProvider ?? this.mobileMoneyProvider,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      changeGiven: changeGiven ?? this.changeGiven,
      // ✅ Include deletion fields
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      deleteReason: deleteReason ?? this.deleteReason,
      deletedSyncStatus: deletedSyncStatus ?? this.deletedSyncStatus,
    );
  }
}
