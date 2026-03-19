import 'package:hive/hive.dart';
import 'package:zitf_system/database/projects/packaging_level.dart';
import 'package:zitf_system/database/projects/stock_unit_type.dart';

part 'project_item_batch_sell_model.g.dart';

@HiveType(typeId: 63)
class BatchSellUnit extends HiveObject {
  @HiveField(0)
  String sellUnitCode;

  @HiveField(1)
  String batchCode;

  /// e.g. Single, Pack, Box, Carton
  @HiveField(2)
  String unitName;

  /// How many base units this represents
  @HiveField(3)
  int quantityMultiplier;

  /// Selling price for THIS unit
  @HiveField(4)
  double sellingPrice;

  @HiveField(5)
  bool active;

  @HiveField(6)
  DateTime? deletedAt;
  @HiveField(8)
  bool? syncStatus;

  @HiveField(9)
  DateTime? lastModified;

  @HiveField(10)
  String? operationType;

  @HiveField(11)
  List<String>? modifiedFields; // Tracks fields that were modified

  // 🔗 DERIVED / SNAPSHOT FROM BATCH
  @HiveField(12)
  PackagingLevel? packagingLevel;

  @HiveField(13)
  double? baseUnitsPerSellUnit; // e.g. 12 L

  @HiveField(14)
  String? baseUnit; // "L", "kg", "pcs"

  @HiveField(15)
  StockUnitType? baseUnitType;

  BatchSellUnit({
    required this.batchCode,
    required this.sellUnitCode,
    required this.unitName,
    required this.quantityMultiplier,
    required this.sellingPrice,
    required this.active,
    this.syncStatus,
    this.lastModified,
    this.operationType,
    this.modifiedFields,
    this.packagingLevel,
    this.baseUnitsPerSellUnit,
    this.baseUnit,
    this.baseUnitType,
    this.deletedAt,
  });

  BatchSellUnit copyWith({
    String? batchCode,
    String? sellUnitCode,
    String? unitName,
    int? quantityMultiplier,
    double? sellingPrice,
    bool? active,
    bool? syncStatus,
    DateTime? lastModified,
    String? operationType,
    List<String>? modifiedFields,
    PackagingLevel? packagingLevel,
    double? baseUnitsPerSellUnit,
    String? baseUnit,
    StockUnitType? baseUnitType,
    DateTime? deletedAt,
  }) {
    return BatchSellUnit(
      batchCode: batchCode ?? this.batchCode,
      sellUnitCode: sellUnitCode ?? this.sellUnitCode,
      unitName: unitName ?? this.unitName,
      quantityMultiplier: quantityMultiplier ?? this.quantityMultiplier,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      active: active ?? this.active,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      operationType: operationType ?? this.operationType,
      modifiedFields: modifiedFields ?? this.modifiedFields,
      packagingLevel: packagingLevel ?? this.packagingLevel,
      baseUnitsPerSellUnit: baseUnitsPerSellUnit ?? this.baseUnitsPerSellUnit,
      baseUnit: baseUnit ?? this.baseUnit,
      baseUnitType: baseUnitType ?? this.baseUnitType,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
