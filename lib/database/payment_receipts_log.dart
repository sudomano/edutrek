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
  PaymentLog({
    required this.receiptNumber,
    required this.studentName,
    required this.className,
    required this.dateTime,
    required this.receiptLines,
    this.parentName,
    this.parentPhone,
  });
}
