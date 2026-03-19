import 'package:hive/hive.dart';

part 'stock_unit_type.g.dart';

@HiveType(typeId: (66)) // ⚠️ must be UNIQUE across your app
enum StockUnitType {
  @HiveField(0)
  piece,

  @HiveField(1)
  weight,

  @HiveField(2)
  volume,
}
