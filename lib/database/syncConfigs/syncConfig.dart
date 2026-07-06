import 'package:hive/hive.dart';

part 'syncConfig.g.dart';

@HiveType(
    typeId:
        39) // Choose a unique typeId that doesn't conflict with your other models.
class DomainRecord extends HiveObject {
  @HiveField(0)
  String? domainName;

  @HiveField(1)
  bool? areDomainsActive = false;

  @HiveField(2)
  bool? syncStatus;

  @HiveField(3)
  String? operationType;

  @HiveField(4)
  DateTime? lastModified;
  @HiveField(5)
  List<String>? modifiedFields; // Tracks fields that were modified
  @HiveField(6)
  bool? isDeleted; // Soft delete flag

  @HiveField(7)
  DateTime? deletedAt; // When deleted

  @HiveField(8)
  String? deletedBy; // Who deleted

  @HiveField(9)
  String? deleteReason; // Why deleted

  @HiveField(10)
  bool? deletedSyncStatus; // Track if deletion was synced
  DomainRecord({
    required this.domainName,
    required this.areDomainsActive,
    required this.syncStatus,
    required this.operationType,
    required this.lastModified,
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
}
