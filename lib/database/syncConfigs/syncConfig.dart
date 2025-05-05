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

  DomainRecord({
    required this.domainName,
    required this.areDomainsActive,
    required this.syncStatus,
    required this.operationType,
    required this.lastModified,
    this.modifiedFields,
  });
}
