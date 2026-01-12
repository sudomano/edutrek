// lib/host/host_runner.dart
import 'package:flutter/foundation.dart';

Future<void> startHostIfSupported(Future<void> Function() hostStart) async {
  if (kIsWeb) return; // 🚫 Web NEVER hosts
  await hostStart();
}
