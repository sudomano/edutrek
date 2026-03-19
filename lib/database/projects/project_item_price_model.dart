import 'package:hive/hive.dart';

part 'project_item_price_model.g.dart';

@HiveType(typeId: 60)
class ProjectItemPrice extends HiveObject {
  @HiveField(0)
  String priceCode;

  @HiveField(1)
  String projectItemCode;

  @HiveField(2)
  double amount;

  /// per_unit | flat | per_term
  @HiveField(3)
  String pricingType;

  /// optional (classId, studentType, etc.)
  @HiveField(4)
  String? appliesTo;

  @HiveField(5)
  DateTime effectiveFrom;

  @HiveField(6)
  DateTime? effectiveTo;

  @HiveField(7)
  bool? syncStatus;

  @HiveField(8)
  DateTime? lastModified;

  @HiveField(9)
  String? operationType;

  @HiveField(10)
  List<String>? modifiedFields; // Tracks fields that were modified

  ProjectItemPrice({
    required this.priceCode,
    required this.projectItemCode,
    required this.amount,
    required this.pricingType,
    this.appliesTo,
    required this.effectiveFrom,
    this.effectiveTo,
    this.syncStatus,
    this.lastModified,
    this.operationType,
    this.modifiedFields,
  });

  ProjectItemPrice copyWith({
    String? priceCode,
    String? projectItemCode,
    double? amount,
    String? pricingType,
    String? appliesTo,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    bool? syncStatus,
    DateTime? lastModified,
    String? operationType,
    List<String>? modifiedFields,
  }) {
    return ProjectItemPrice(
      priceCode: priceCode ?? this.priceCode,
      projectItemCode: projectItemCode ?? this.projectItemCode,
      amount: amount ?? this.amount,
      pricingType: pricingType ?? this.pricingType,
      appliesTo: appliesTo ?? this.appliesTo,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo: effectiveTo ?? this.effectiveTo,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      operationType: operationType ?? this.operationType,
      modifiedFields: modifiedFields ?? this.modifiedFields,
    );
  }
}
