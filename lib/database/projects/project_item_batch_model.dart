import 'package:hive/hive.dart';
import 'package:zitf_system/database/projects/unitbatching.dart';
import 'package:zitf_system/database/projects/stock_unit_type.dart';

part 'project_item_batch_model.g.dart';

@HiveType(typeId: 62)
class ProductBatch extends HiveObject {
  @HiveField(0)
  String? batchCode;

  @HiveField(1)
  String? productCode;

  /// Supplier invoice / GRN
  @HiveField(2)
  String? reference;

  /// Base unit type for this product
  /// piece / weight / volume
  @HiveField(3)
  StockUnitType? baseUnitType;

  /// Base unit label: pcs, kg, g, L, ml
  @HiveField(4)
  String? baseUnit;

  /// All packaging levels bought in this batch
  @HiveField(5)
  List<BatchUnit>? units;

  /// Normalized totals (derived, but stored for speed)
  @HiveField(6)
  double? totalBaseUnits;

  @HiveField(7)
  double? remainingBaseUnits;

  @HiveField(8)
  double? totalBuyingCost;

  @HiveField(9)
  DateTime? purchaseDate;

  @HiveField(10)
  DateTime? createdAt;

  @HiveField(11)
  bool? syncStatus;

  @HiveField(12)
  DateTime? lastModified;

  @HiveField(13)
  String? operationType;

  @HiveField(14)
  List<String>? modifiedFields;
// ✅ NEW — how much one unit represents (2L, 5kg, etc)
  @HiveField(15)
  double? baseUnitSize;

  ProductBatch({
    this.batchCode,
    this.productCode,
    this.reference,
    this.baseUnitType,
    this.baseUnit,
    this.units,
    this.totalBaseUnits,
    this.remainingBaseUnits,
    this.totalBuyingCost,
    this.purchaseDate,
    this.createdAt,
    this.syncStatus,
    this.lastModified,
    this.operationType,
    this.modifiedFields,
    this.baseUnitSize,
  });

  double get remainingQuantity => remainingBaseUnits ?? 0;

  ProductBatch copyWith({
    String? batchCode,
    String? productCode,
    String? reference,
    double? totalBuyingCost,
    double? totalBaseUnits,
    double? remainingBaseUnits,
    DateTime? purchaseDate,
    DateTime? createdAt,
    bool? syncStatus,
    DateTime? lastModified,
    String? operationType,
    List<String>? modifiedFields,
    List<BatchUnit>? units,
    StockUnitType? baseUnitType,
    String? baseUnit,
    double? baseUnitSize,
  }) {
    return ProductBatch(
      batchCode: batchCode ?? this.batchCode,
      productCode: productCode ?? this.productCode,
      reference: reference ?? this.reference,
      totalBuyingCost: totalBuyingCost ?? this.totalBuyingCost,
      totalBaseUnits: totalBaseUnits ?? this.totalBaseUnits,
      remainingBaseUnits: remainingBaseUnits ?? this.remainingBaseUnits,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      createdAt: createdAt ?? this.createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      operationType: operationType ?? this.operationType,
      modifiedFields: modifiedFields ?? this.modifiedFields,
      units: units ?? this.units,
      baseUnitType: baseUnitType ?? this.baseUnitType,
      baseUnit: baseUnit ?? this.baseUnit,
      baseUnitSize: baseUnitSize ?? this.baseUnitSize,
    );
  }
}
