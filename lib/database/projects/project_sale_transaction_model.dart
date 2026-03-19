import 'package:hive/hive.dart';
import 'package:zitf_system/database/projects/stock_unit_type.dart';

part 'project_sale_transaction_model.g.dart';

@HiveType(typeId: 27)
class ProjectSaleTransaction extends HiveObject {
  @HiveField(0)
  String transactionCode;

  @HiveField(1)
  String studentId;

  @HiveField(2)
  String projectCode;

  @HiveField(3)
  String projectItemCode;

  @HiveField(4)
  String batchCode;

  @HiveField(5)
  String sellUnitCode;

  @HiveField(6)
  String sellUnitNameSnapshot;

  @HiveField(7)
  int quantitySold;

  @HiveField(8)
  double unitSellingPrice;

  @HiveField(9)
  double totalAmount;

  @HiveField(10)
  double baseUnitsPerSellUnit;

  @HiveField(11)
  double totalBaseUnitsSold;

  @HiveField(12)
  String baseUnit;

  @HiveField(13)
  StockUnitType baseUnitType;

  @HiveField(14)
  DateTime transactionDate;

  @HiveField(15)
  String paymentMethod;

  @HiveField(16)
  String reference;

  @HiveField(17)
  bool? syncStatus;

  @HiveField(18)
  DateTime? lastModified;

  @HiveField(19)
  String? operationType;

  @HiveField(20)
  List<String>? modifiedFields;

  // 🔴 Soft delete flag
  @HiveField(21)
  bool? isDeleted;

  // 🗑️ When this transaction was deleted (can be multiple times)
  @HiveField(22)
  List<DateTime>? deletedAt;

  // ♻️ When this transaction was restored
  @HiveField(23)
  List<DateTime>? restoredAt;

  @HiveField(24)
  List<String>? deletedByUsers;
  @HiveField(25)
  List<String>? restoredByUsers;
  @HiveField(26)
  double amountPaid;
  @HiveField(27)
  double arrears;

  @HiveField(28)
  String? paymentMethodCode;

  @HiveField(29)
  String? methodType;
  // cash | mobile_money | bank_transfer | card | cheque | voucher | other

  @HiveField(30)
  double? amountPaidInPaymentMethod;

  @HiveField(31)
  String? currency;

  // ---------- OPTIONAL DETAILS ----------
  @HiveField(32)
  String? provider;

  @HiveField(33)
  String? referenceNumber;

  @HiveField(34)
  String? phoneNumber;

  @HiveField(36)
  String? accountNumber;

  @HiveField(37)
  String? accountName;

  @HiveField(38)
  DateTime? paymentDatetransacted;

  // ---------- AUDIT ----------
  @HiveField(39)
  bool? isReversed;

  @HiveField(40)
  List<String>? lineTransactionCodes; // 🔥 LINKS TO LINES

  @HiveField(41)
  String financialType;
// sale | payment | refund | adjustment

  @HiveField(42)
  String? parentTransactionCode;

  @HiveField(43)
  bool affectsStock;

  @HiveField(44)
  bool createsObligation;

  @HiveField(45)
  bool settlesObligation;

  ProjectSaleTransaction({
    required this.transactionCode,
    required this.studentId,
    required this.projectCode,
    required this.projectItemCode,
    required this.batchCode,
    required this.sellUnitCode,
    required this.sellUnitNameSnapshot,
    required this.quantitySold,
    required this.unitSellingPrice,
    required this.totalAmount,
    required this.baseUnitsPerSellUnit,
    required this.totalBaseUnitsSold,
    required this.baseUnit,
    required this.baseUnitType,
    required this.transactionDate,
    required this.paymentMethod,
    required this.reference,
    required this.amountPaid,
    required this.arrears,
    bool? isDeleted,
    List<DateTime>? deletedAt,
    List<DateTime>? restoredAt,
    List<String>? deletedByUsers,
    List<String>? restoredByUsers,
    this.syncStatus,
    this.lastModified,
    this.operationType,
    this.modifiedFields,
    this.paymentMethodCode,
    this.methodType,
    this.amountPaidInPaymentMethod,
    this.currency,
    this.provider,
    this.referenceNumber,
    this.phoneNumber,
    this.accountNumber,
    this.accountName,
    this.paymentDatetransacted,
    this.isReversed,
    List<String>? lineTransactionCodes,
    this.financialType = 'sale',
    this.parentTransactionCode,
    this.affectsStock = true,
    this.createsObligation = false,
    this.settlesObligation = false,
  })  : isDeleted = isDeleted ?? false,
        deletedAt = deletedAt ?? <DateTime>[],
        restoredAt = restoredAt ?? <DateTime>[],
        deletedByUsers = deletedByUsers ?? <String>[],
        restoredByUsers = restoredByUsers ?? <String>[];
  double get safeAmountPaidInPaymentMethod => amountPaidInPaymentMethod ?? 0.0;
  String get safeCurrency => currency ?? 'USD';
  bool get safeIsReversed => isReversed ?? false;
  String get safeMethodType => methodType ?? 'cash';

  ProjectSaleTransaction copyWith({
    String? transactionCode,
    String? projectCode,
    String? studentId,
    String? projectItemCode,
    double? totalAmount,
    DateTime? transactionDate,
    String? batchCode,
    String? sellUnitCode,
    int? quantitySold,
    String? paymentMethod,
    String? reference,
    bool? syncStatus,
    DateTime? lastModified,
    String? operationType,
    List<String>? modifiedFields,
    StockUnitType? baseUnitType,
    String? baseUnit,
    double? baseUnitsPerSellUnit,
    double? totalBaseUnitsSold,
    String? sellUnitNameSnapshot,
    double? unitSellingPrice,
    bool? isDeleted,
    List<DateTime>? deletedAt,
    List<DateTime>? restoredAt,
    List<String>? deletedByUsers,
    List<String>? restoredByUsers,
    double? amountPaid,
    double? arrears,
    String? paymentMethodCode,
    String? methodType,
    double? amountPaidInPaymentMethod,
    String? currency,
    String? provider,
    String? referenceNumber,
    String? phoneNumber,
    String? accountNumber,
    String? accountName,
    DateTime? paymentDatetransacted,
    bool? isReversed,
    List<String>? lineTransactionCodes,
    String? financialType,
    String? parentTransactionCode,
    bool? affectsStock,
    bool? createsObligation,
    bool? settlesObligation,
  }) {
    return ProjectSaleTransaction(
      transactionCode: transactionCode ?? this.transactionCode,
      studentId: studentId ?? this.studentId,
      projectCode: projectCode ?? this.projectCode,
      projectItemCode: projectItemCode ?? this.projectItemCode,
      batchCode: batchCode ?? this.batchCode,
      sellUnitCode: sellUnitCode ?? this.sellUnitCode,
      sellUnitNameSnapshot: sellUnitNameSnapshot ?? this.sellUnitNameSnapshot,
      quantitySold: quantitySold ?? this.quantitySold,
      unitSellingPrice: unitSellingPrice ?? this.unitSellingPrice,
      totalAmount: totalAmount ?? this.totalAmount,
      baseUnitsPerSellUnit: baseUnitsPerSellUnit ?? this.baseUnitsPerSellUnit,
      totalBaseUnitsSold: totalBaseUnitsSold ?? this.totalBaseUnitsSold,
      baseUnit: baseUnit ?? this.baseUnit,
      baseUnitType: baseUnitType ?? this.baseUnitType,
      transactionDate: transactionDate ?? this.transactionDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      reference: reference ?? this.reference,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      operationType: operationType ?? this.operationType,
      modifiedFields: modifiedFields ?? this.modifiedFields,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? List<DateTime>.from(this.deletedAt!),
      restoredAt: restoredAt ?? List<DateTime>.from(this.restoredAt!),
      deletedByUsers: deletedByUsers ?? List<String>.from(this.deletedByUsers!),
      restoredByUsers:
          restoredByUsers ?? List<String>.from(this.restoredByUsers!),
      amountPaid: amountPaid ?? this.amountPaid,
      arrears: arrears ?? this.arrears,
      paymentMethodCode: paymentMethodCode ?? this.paymentMethodCode,
      methodType: methodType ?? this.methodType,
      amountPaidInPaymentMethod:
          amountPaidInPaymentMethod ?? this.amountPaidInPaymentMethod,
      currency: currency ?? this.currency,
      provider: provider ?? this.provider,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      accountNumber: accountNumber ?? this.accountNumber,
      accountName: accountName ?? this.accountName,
      paymentDatetransacted:
          paymentDatetransacted ?? this.paymentDatetransacted,
      isReversed: isReversed ?? this.isReversed,
      lineTransactionCodes:
          lineTransactionCodes ?? List<String>.from(this.lineTransactionCodes!),
      financialType: financialType ?? this.financialType,
      parentTransactionCode:
          parentTransactionCode ?? this.parentTransactionCode,
      affectsStock: affectsStock ?? this.affectsStock,
      createsObligation: createsObligation ?? this.createsObligation,
      settlesObligation: settlesObligation ?? this.settlesObligation,
    );
  }
}
