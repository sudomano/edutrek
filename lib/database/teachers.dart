import 'package:hive/hive.dart';

part 'teachers.g.dart';

@HiveType(typeId: 10)
class Teachers extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String surname;

  @HiveField(2)
  String IdNumber;

  @HiveField(3)
  String? assignedClass;

  @HiveField(4)
  String gender;

  @HiveField(5)
  DateTime dateOfBirth;

  @HiveField(6)
  String phoneNumber;

  @HiveField(7)
  String paymentPurpose;

  @HiveField(8)
  bool isPaid;

  @HiveField(9)
  double paymentAmount;

  @HiveField(10)
  DateTime? paymentDate;

  @HiveField(11)
  String email;

  @HiveField(12)
  String address;

  @HiveField(13)
  DateTime hireDate;

  @HiveField(14)
  String qualifications;

  @HiveField(15)
  String employmentStatus;

  @HiveField(16)
  String? termId; // Nullable termId

  @HiveField(17)
  bool? syncStatus; // Nullable field to track sync status

  @HiveField(18)
  DateTime? lastModified; // Nullable field to track last modification time

  @HiveField(19)
  String? operationType; // Nullable field for 'create', 'update', or 'delete'

  @HiveField(20)
  int? id;
  @HiveField(21)
  List<String>? assignedClasses; // New field for unique identifier

  @HiveField(22)
  List<String>? modifiedFields; // Tracks fields that were modified

  @HiveField(23)
  List<String>? terms;

  // ✅ NEW: Deletion Fields
  @HiveField(24)
  bool? isDeleted; // Soft delete flag

  @HiveField(25)
  DateTime? deletedAt; // When deleted

  @HiveField(26)
  String? deletedBy; // Who deleted

  @HiveField(27)
  String? deleteReason; // Why deleted

  @HiveField(28)
  bool? deletedSyncStatus; // Track if deletion was synced

  Teachers({
    required this.name,
    required this.surname,
    required this.IdNumber,
    this.assignedClass,
    this.assignedClasses,
    required this.gender,
    required this.dateOfBirth,
    required this.phoneNumber,
    required this.paymentPurpose,
    this.isPaid = true,
    this.paymentDate,
    required this.paymentAmount,
    required this.email,
    required this.address,
    required this.hireDate,
    required this.qualifications,
    required this.employmentStatus,
    this.termId,
    this.syncStatus,
    this.lastModified,
    this.operationType,
    this.id,
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

  Teachers copyWith({
    String? name,
    String? surname,
    String? IdNumber,
    String? assignedClass,
    List<String>? assignedClasses,
    String? gender,
    DateTime? dateOfBirth,
    String? phoneNumber,
    String? paymentPurpose,
    bool? isPaid,
    double? paymentAmount,
    DateTime? paymentDate,
    String? email,
    String? address,
    DateTime? hireDate,
    String? qualifications,
    String? employmentStatus,
    String? termId,
    bool? syncStatus,
    DateTime? lastModified,
    String? operationType,
    int? id,
    List<String>? modifiedFields,
    List<String>? terms,
  }) {
    return Teachers(
      name: name ?? this.name,
      surname: surname ?? this.surname,
      IdNumber: IdNumber ?? this.IdNumber,
      assignedClass: assignedClass ?? this.assignedClass,
      assignedClasses: assignedClasses ?? this.assignedClasses,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      paymentPurpose: paymentPurpose ?? this.paymentPurpose,
      isPaid: isPaid ?? this.isPaid,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      paymentDate: paymentDate ?? this.paymentDate,
      email: email ?? this.email,
      address: address ?? this.address,
      hireDate: hireDate ?? this.hireDate,
      qualifications: qualifications ?? this.qualifications,
      employmentStatus: employmentStatus ?? this.employmentStatus,
      termId: termId ?? this.termId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      operationType: operationType ?? this.operationType,
      id: id ?? this.id,
      modifiedFields: modifiedFields ?? this.modifiedFields,
      terms: terms ?? this.terms,
    );
  }
}
