import 'package:hive/hive.dart';

part 'reprint_project_receipt.g.dart';

@HiveType(typeId: 79) // choose unused typeId
class ReceiptSnapshot extends HiveObject {
  @HiveField(0)
  String receiptCode;

  @HiveField(1)
  DateTime receiptDate;

  @HiveField(2)
  String cashier;

  @HiveField(3)
  double totalExpected;

  @HiveField(4)
  double totalPaid;

  @HiveField(5)
  double amountReceived;

  @HiveField(6)
  double change;

  @HiveField(7)
  String currency;

  @HiveField(8)
  List<Map<String, dynamic>> receiptLinesJson;

  @HiveField(9)
  bool isReprint;

  @HiveField(10)
  String studentName;

  @HiveField(11)
  String? studentClass;

  @HiveField(12)
  bool? syncStatus; // Nullable field to track sync status

  @HiveField(13)
  DateTime?
      lastModified; // Nullable field to track when the class was last modified

  @HiveField(14)
  String? operationType; // Nullable field for 'create', 'update', or 'delete'

  @HiveField(15)
  List<String>? modifiedFields; // Tracks fields that were modified

  ReceiptSnapshot({
    required this.receiptCode,
    required this.receiptDate,
    required this.cashier,
    required this.totalExpected,
    required this.totalPaid,
    required this.amountReceived,
    required this.change,
    required this.currency,
    required this.receiptLinesJson,
    this.isReprint = false,
    required this.studentName,
    this.studentClass,
    this.syncStatus, // Can be null initially
    this.lastModified, // Can be null initially
    this.operationType, // Can be null initially
    this.modifiedFields,
  });
}
