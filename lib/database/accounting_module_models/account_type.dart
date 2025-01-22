import 'package:hive/hive.dart';

part 'account_type.g.dart';

@HiveType(typeId: 22) // Unique typeId for the Accounts table
class Account extends HiveObject {
  @HiveField(0)
  int? id;

  @HiveField(1)
  String? accountType;

  @HiveField(2)
  String? accountSubType;

  @HiveField(3)
  String? accountName;

  @HiveField(4)
  String? accountCode;

  @HiveField(5)
  String? operationType;

  @HiveField(6)
  bool syncStatus;

  @HiveField(7)
  DateTime? lastModified;
  @HiveField(8)
  bool? isALiquidAccount;
  @HiveField(9)
  List<String>? modifiedFields; // Tracks fields that were modified

  Account({
    this.id,
    this.accountType,
    this.accountSubType,
    this.accountName,
    this.accountCode,
    this.operationType,
    this.syncStatus = false,
    this.lastModified,
    this.isALiquidAccount,
    this.modifiedFields,
  });

  Account copyWith({
    int? id,
    String? accountType,
    String? accountSubType,
    String? accountName,
    String? accountCode,
    String? operationType,
    bool? syncStatus,
    DateTime? lastModified,
    bool? isALiquidAccount,
    List<String>? modifiedFields,
  }) {
    return Account(
      id: id ?? this.id,
      accountType: accountType ?? this.accountType,
      accountSubType: accountSubType ?? this.accountSubType,
      accountName: accountName ?? this.accountName,
      accountCode: accountCode ?? this.accountCode,
      operationType: operationType ?? this.operationType,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      isALiquidAccount: isALiquidAccount ?? this.isALiquidAccount,
      modifiedFields: modifiedFields ?? this.modifiedFields,
    );
  }
}
