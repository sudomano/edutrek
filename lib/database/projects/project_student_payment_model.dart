import 'package:hive/hive.dart';

part 'project_student_payment_model.g.dart';

@HiveType(typeId: 27)
class ProjectStudentPayment extends HiveObject {
  @HiveField(0)
  String projectStudentPaymentCode;

  @HiveField(1)
  String studentId;

  @HiveField(2)
  String projectCode;

  @HiveField(3)
  String itemId;

  @HiveField(4)
  double amountPaid;

  @HiveField(5)
  double balance;

  @HiveField(6)
  bool? syncStatus;

  @HiveField(7)
  DateTime? lastModified;

  @HiveField(8)
  String? operationType;

  @HiveField(9)
  List<String>? modifiedFields; // Tracks fields that were modified

  ProjectStudentPayment({
    required this.projectStudentPaymentCode,
    required this.studentId,
    required this.projectCode,
    required this.itemId,
    required this.amountPaid,
    required this.balance,
    this.syncStatus,
    this.lastModified,
    this.operationType,
    this.modifiedFields,
  });

  ProjectStudentPayment copyWith({
    String? projectStudentPaymentCode,
    String? studentId,
    String? projectCode,
    String? itemId,
    double? amountPaid,
    double? balance,
    bool? syncStatus,
    DateTime? lastModified,
    String? operationType,
    List<String>? modifiedFields,
  }) {
    return ProjectStudentPayment(
      projectStudentPaymentCode:
          projectStudentPaymentCode ?? this.projectStudentPaymentCode,
      studentId: studentId ?? this.studentId,
      projectCode: projectCode ?? this.projectCode,
      itemId: itemId ?? this.itemId,
      amountPaid: amountPaid ?? this.amountPaid,
      balance: balance ?? this.balance,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      operationType: operationType ?? this.operationType,
      modifiedFields: modifiedFields ?? this.modifiedFields,
    );
  }
}
