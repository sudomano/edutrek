import 'package:hive/hive.dart';

part 'withdrawalshome.g.dart'; // Required for code generation

@HiveType(typeId: 3) // Unique identifier for Hive
class Withdrawal extends HiveObject {
  @HiveField(0)
  late DateTime date;

  @HiveField(1)
  late double amount;

  @HiveField(2)
  late String withdrawalPurpose;

  @HiveField(3)
  String? termId; // Nullable termId

  @HiveField(4)
  bool? syncStatus; // Nullable field to track sync status

  @HiveField(5)
  DateTime? lastModified; // Nullable field to track last modification time

  @HiveField(6)
  String? operationType; // Nullable field for 'create', 'update', or 'delete'

  @HiveField(7)
  int? id; // New field for unique identifier

  @HiveField(8)
  String? withdrawalCode;

  @HiveField(9)
  List<String>? modifiedFields; // Tracks fields that were modified

  Withdrawal({
    required this.date,
    required this.amount,
    required this.withdrawalPurpose,
    this.termId,
    this.syncStatus,
    this.lastModified,
    this.operationType,
    this.id,
    this.withdrawalCode,
    this.modifiedFields,
  });

  Withdrawal copyWith({
    DateTime? date,
    double? amount,
    String? withdrawalPurpose,
    String? termId,
    bool? syncStatus,
    DateTime? lastModified,
    String? operationType,
    int? id,
    String? withdrawalCode,
    List<String>? modifiedFields,
  }) {
    return Withdrawal(
      date: date ?? this.date,
      amount: amount ?? this.amount,
      withdrawalPurpose: withdrawalPurpose ?? this.withdrawalPurpose,
      termId: termId ?? this.termId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      operationType: operationType ?? this.operationType,
      id: id ?? this.id,
      withdrawalCode: withdrawalCode ?? this.withdrawalCode,
      modifiedFields: modifiedFields ?? this.modifiedFields,
    );
  }
}
