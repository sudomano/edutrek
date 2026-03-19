import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zitf_system/entry_point/app_bootstrap_layer_1/hive_path_io.dart'
    if (dart.library.html) 'package:zitf_system/entry_point/app_bootstrap_layer_1/hive_paths_stub.dart';

import '../../main.dart'; // for DeviceRole

class HiveBootstrap {
  static Future<void> initialize(DeviceRole role) async {
    // 🌐 Web
    if (kIsWeb) {
      await Hive.initFlutter();
      return;
    }

    // 📱 Mobile (Android / iOS)
    if (Platform.isAndroid || Platform.isIOS) {
      await Hive.initFlutter(); // sandboxed, SAF compliant
      return;
    }

    // 🖥 Desktop only
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      if (role == DeviceRole.host) {
        final path = await resolveHivePath();
        await Hive.initFlutter(path);
      } else {
        await Hive.initFlutter();
      }
      return;
    }
  }
}
