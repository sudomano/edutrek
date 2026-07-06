import 'package:hive/hive.dart';

part 'assets.g.dart';

@HiveType(typeId: 23)
class Asset extends HiveObject {
  // General Asset Information
  @HiveField(0)
  int? id;

  @HiveField(1)
  String? assetName;

  @HiveField(2)
  String? assetType; // e.g., "asset"

  @HiveField(36)
  String? assetSubType; // e.g., "Tangible" or "Intangible"

  @HiveField(3)
  String? assetCode; // e.g., "Equipment", "Vehicle"

  @HiveField(37)
  String? assetSerialNo;

  @HiveField(4)
  DateTime? acquisitionDate;

  @HiveField(5)
  double? acquisitionCost;

  @HiveField(38)
  String? acquisitionMethod; // e.g., "cash" or "financing"

  // Asset Location and Tracking
  @HiveField(6)
  String? department; // For internal transfers

  @HiveField(7)
  String? location;

  // Depreciation & Valuation
  @HiveField(8)
  double? depreciationRate;

  @HiveField(9)
  String? depreciationMethod; // e.g., "Straight Line", "Diminishing Balance"

  @HiveField(10)
  DateTime? lastDepreciationDate;

  @HiveField(11)
  double? accumulatedDepreciation;

  @HiveField(12)
  double? bookValue;

  @HiveField(13)
  bool? isImpaired; // If an asset has undergone impairment

  @HiveField(14)
  double? impairmentLoss;

  @HiveField(15)
  DateTime? revaluationDate;

  @HiveField(16)
  double? revaluationAmount;

  // Maintenance & Improvement
  @HiveField(17)
  DateTime? lastMaintenanceDate;

  @HiveField(18)
  double? maintenanceCost;

  @HiveField(19)
  String? maintenanceDescription;

  @HiveField(20)
  double? capitalImprovementCost;

  @HiveField(21)
  String? capitalImprovementDescription;

  // Disposal Information
  @HiveField(22)
  DateTime? disposalDate;

  @HiveField(23)
  double? disposalProceeds;

  @HiveField(24)
  String? disposalReason;

  @HiveField(25)
  double? gainOrLossOnDisposal;

  // Leasing Details
  @HiveField(26)
  bool? isLeased;

  @HiveField(27)
  String? leaseType; // e.g., "Operating" or "Finance"

  @HiveField(28)
  DateTime? leaseStartDate;

  @HiveField(29)
  DateTime? leaseEndDate;

  @HiveField(30)
  double? leasePaymentAmount;

  // Sync & Audit Fields
  @HiveField(31)
  DateTime? lastAuditDate;

  @HiveField(32)
  bool? syncStatus; // e.g., true for synced, false otherwise

  // Additional Fields (if needed)
  @HiveField(33)
  String? notes; // General notes or comments

  @HiveField(34)
  DateTime? createdAt;

  @HiveField(35)
  DateTime? lastModified;

  @HiveField(39)
  String?
      operationType; // e.g., "Operation" type such as "Purchase", "Transfer"
  @HiveField(40)
  String? usefulLife;
  @HiveField(41)
  bool? hasDebitBalance;
  @HiveField(42)
  bool? hasCreditBalance;
  @HiveField(43)
  String? option;
  @HiveField(44)
  List<String>? modifiedFields; // Tracks fields that were modified

  // ✅ NEW: Deletion Fields
  @HiveField(45)
  bool? isDeleted; // Soft delete flag

  @HiveField(46)
  DateTime? deletedAt; // When deleted

  @HiveField(47)
  String? deletedBy; // Who deleted

  @HiveField(48)
  String? deleteReason; // Why deleted

  @HiveField(49)
  bool? deletedSyncStatus; // Track if deletion was synced
  // Constructor
  Asset({
    this.id,
    this.assetName,
    this.assetType,
    this.assetSubType,
    this.assetCode,
    this.assetSerialNo,
    this.acquisitionDate,
    this.acquisitionCost,
    this.acquisitionMethod,
    this.department,
    this.location,
    this.depreciationRate,
    this.depreciationMethod,
    this.lastDepreciationDate,
    this.accumulatedDepreciation,
    this.bookValue,
    this.isImpaired,
    this.impairmentLoss,
    this.revaluationDate,
    this.revaluationAmount,
    this.lastMaintenanceDate,
    this.maintenanceCost,
    this.maintenanceDescription,
    this.capitalImprovementCost,
    this.capitalImprovementDescription,
    this.disposalDate,
    this.disposalProceeds,
    this.disposalReason,
    this.gainOrLossOnDisposal,
    this.isLeased,
    this.leaseType,
    this.leaseStartDate,
    this.leaseEndDate,
    this.leasePaymentAmount,
    this.lastAuditDate,
    this.syncStatus,
    this.notes,
    this.createdAt,
    this.lastModified,
    this.operationType,
    this.usefulLife,
    this.hasDebitBalance,
    this.hasCreditBalance,
    this.option,
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

  // CopyWith Method
  Asset copyWith({
    int? id,
    String? assetName,
    String? assetType,
    String? assetSubType,
    String? assetCode,
    String? assetSerialNo,
    DateTime? acquisitionDate,
    double? acquisitionCost,
    String? acquisitionMethod,
    String? department,
    String? location,
    double? depreciationRate,
    String? depreciationMethod,
    DateTime? lastDepreciationDate,
    double? accumulatedDepreciation,
    double? bookValue,
    bool? isImpaired,
    double? impairmentLoss,
    DateTime? revaluationDate,
    double? revaluationAmount,
    DateTime? lastMaintenanceDate,
    double? maintenanceCost,
    String? maintenanceDescription,
    double? capitalImprovementCost,
    String? capitalImprovementDescription,
    DateTime? disposalDate,
    double? disposalProceeds,
    String? disposalReason,
    double? gainOrLossOnDisposal,
    bool? isLeased,
    String? leaseType,
    DateTime? leaseStartDate,
    DateTime? leaseEndDate,
    double? leasePaymentAmount,
    DateTime? lastAuditDate,
    bool? syncStatus,
    String? notes,
    DateTime? createdAt,
    DateTime? lastModified,
    String? operationType,
    String? usefulLife,
    bool? hasDebitBalance,
    bool? hasCreditBalance,
    String? option,
    List<String>? modifiedFields,
  }) {
    return Asset(
      id: id ?? this.id,
      assetName: assetName ?? this.assetName,
      assetType: assetType ?? this.assetType,
      assetSubType: assetSubType ?? this.assetSubType,
      assetCode: assetCode ?? this.assetCode,
      assetSerialNo: assetSerialNo ?? this.assetSerialNo,
      acquisitionDate: acquisitionDate ?? this.acquisitionDate,
      acquisitionCost: acquisitionCost ?? this.acquisitionCost,
      acquisitionMethod: acquisitionMethod ?? this.acquisitionMethod,
      department: department ?? this.department,
      location: location ?? this.location,
      depreciationRate: depreciationRate ?? this.depreciationRate,
      depreciationMethod: depreciationMethod ?? this.depreciationMethod,
      lastDepreciationDate: lastDepreciationDate ?? this.lastDepreciationDate,
      accumulatedDepreciation:
          accumulatedDepreciation ?? this.accumulatedDepreciation,
      bookValue: bookValue ?? this.bookValue,
      isImpaired: isImpaired ?? this.isImpaired,
      impairmentLoss: impairmentLoss ?? this.impairmentLoss,
      revaluationDate: revaluationDate ?? this.revaluationDate,
      revaluationAmount: revaluationAmount ?? this.revaluationAmount,
      lastMaintenanceDate: lastMaintenanceDate ?? this.lastMaintenanceDate,
      maintenanceCost: maintenanceCost ?? this.maintenanceCost,
      maintenanceDescription:
          maintenanceDescription ?? this.maintenanceDescription,
      capitalImprovementCost:
          capitalImprovementCost ?? this.capitalImprovementCost,
      capitalImprovementDescription:
          capitalImprovementDescription ?? this.capitalImprovementDescription,
      disposalDate: disposalDate ?? this.disposalDate,
      disposalProceeds: disposalProceeds ?? this.disposalProceeds,
      disposalReason: disposalReason ?? this.disposalReason,
      gainOrLossOnDisposal: gainOrLossOnDisposal ?? this.gainOrLossOnDisposal,
      isLeased: isLeased ?? this.isLeased,
      leaseType: leaseType ?? this.leaseType,
      leaseStartDate: leaseStartDate ?? this.leaseStartDate,
      leaseEndDate: leaseEndDate ?? this.leaseEndDate,
      leasePaymentAmount: leasePaymentAmount ?? this.leasePaymentAmount,
      lastAuditDate: lastAuditDate ?? this.lastAuditDate,
      syncStatus: syncStatus ?? this.syncStatus,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
      operationType: operationType ?? this.operationType,
      usefulLife: usefulLife ?? this.usefulLife,
      hasDebitBalance: hasDebitBalance ?? this.hasDebitBalance,
      hasCreditBalance: hasCreditBalance ?? this.hasCreditBalance,
      option: option ?? this.option,
      modifiedFields: modifiedFields ?? this.modifiedFields,
    );
  }
}
