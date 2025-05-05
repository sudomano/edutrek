import 'package:hive/hive.dart';

part 'auto_logou_timer.g.dart';

@HiveType(typeId: 38)
class AutoLogoutSettings extends HiveObject {
  /// The auto‑logout timeout (in minutes). Default is 1.
  @HiveField(0)
  int logoutTimeoutMinutes;

  AutoLogoutSettings({this.logoutTimeoutMinutes = 30});
}
