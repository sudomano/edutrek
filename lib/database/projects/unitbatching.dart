import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:zitf_system/database/projects/packaging_level.dart';

part 'unitbatching.g.dart';

@HiveType(typeId: 65)
class BatchUnit extends HiveObject {
  @HiveField(0)
  PackagingLevel level;

  /// How many base units in this package
  /// e.g. carton = 24 pcs
  @HiveField(1)
  double unitsPerPackage;

  /// Number of packages bought
  @HiveField(2)
  int quantity;

  /// Buying price per package
  @HiveField(3)
  double buyingPrice;

  @HiveField(4)
  bool? syncStatus; // Nullable field to track sync status

  @HiveField(5)
  DateTime?
      lastModified; // Nullable field to track when the class was last modified

  @HiveField(6)
  String? operationType; // Nullable field for 'create', 'update', or 'delete'

  @HiveField(7)
  List<String>? modifiedFields; // Tracks fields that were modified

  @HiveField(8)
  String? unitBatchCode;

  BatchUnit({
    required this.level,
    required this.unitsPerPackage,
    required this.quantity,
    required this.buyingPrice,
    this.syncStatus, // Can be null initially
    this.lastModified, // Can be null initially
    this.operationType, // Can be null initially
    this.modifiedFields,
    String? unitBatchCode,
  }) : unitBatchCode = unitBatchCode ?? const Uuid().v4();

  double get totalUnits => unitsPerPackage * quantity;
  double get totalCost => buyingPrice * quantity;

  BatchUnit copyWith({
    PackagingLevel? level,
    double? unitsPerPackage,
    int? quantity,
    double? buyingPrice,
    bool? syncStatus,
    DateTime? lastModified,
    String? operationType,
    List<String>? modifiedFields,
    String? unitBatchCode,
  }) {
    return BatchUnit(
      level: level ?? this.level,
      unitsPerPackage: unitsPerPackage ?? this.unitsPerPackage,
      quantity: quantity ?? this.quantity,
      buyingPrice: buyingPrice ?? this.buyingPrice,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      operationType: operationType ?? this.operationType,
      modifiedFields: modifiedFields ?? this.modifiedFields,
      unitBatchCode: unitBatchCode ?? this.unitBatchCode,
    );
  }
}
