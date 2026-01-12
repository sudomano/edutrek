// lib/host/host_bootstrap.dart
import 'dart:io';

import 'package:zitf_system/server/alfred_server.dart';
import 'package:zitf_system/server/save_Ip_To_Shared_prefs.dart';
import 'package:zitf_system/server/save_gateway_to_shared_prefs.dart';

class HostBootstrap {
  static Future<void> start() async {
    await startAlfredServer();
    saveLocalIpToPrefs();
    saveGatewayToPrefs();
  }
}
