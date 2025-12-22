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
  });

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
    );
  }
}
