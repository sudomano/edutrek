import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zitf_system/entry_point/app_bootstrap_layer_1/hive_path_io.dart'
    if (dart.library.html) 'package:zitf_system/entry_point/app_bootstrap_layer_1/hive_paths_stub.dart';

import '../../main.dart'; // for DeviceRole

class HiveBootstrap {
  static Future<void> initialize(DeviceRole role) async {
    if (kIsWeb) {
      // Web always uses default IndexedDB-backed Hive
      await Hive.initFlutter();
      return;
    }

    // Non-web platforms
    if (role == DeviceRole.host) {
      final path = await resolveHivePath();
      await Hive.initFlutter(path);
    } else {
      // Client (LOCAL for now)
      await Hive.initFlutter();
    }
  }
}
