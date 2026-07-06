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
  // ✅ NEW: Deletion Fields
  @HiveField(10)
  bool? isDeleted; // Soft delete flag

  @HiveField(11)
  DateTime? deletedAt; // When deleted

  @HiveField(12)
  String? deletedBy; // Who deleted

  @HiveField(13)
  String? deleteReason; // Why deleted

  @HiveField(14)
  bool? deletedSyncStatus; // Track if deletion was synced

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
