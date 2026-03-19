import 'package:hive/hive.dart';

part 'packaging_level.g.dart';

@HiveType(typeId: (67)) // ⚠️ must be UNIQUE across your app
enum PackagingLevel {
  @HiveField(0)
  single,

  @HiveField(1)
  pack,

  @HiveField(2)
  carton,

  @HiveField(3)
  batch,
}
