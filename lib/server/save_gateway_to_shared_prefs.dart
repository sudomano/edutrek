import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:network_info_plus/network_info_plus.dart';

/// On the CLIENT side, find the likely GATEWAY IP (host IP)
/// and store it for use in API communication.
Future<void> saveGatewayToPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  final gatewayIp = await getActualGatewayIp();
  if (gatewayIp != null) {
    await prefs.setString('host_ip', gatewayIp);
    print("✅ Gateway IP saved to prefs: $gatewayIp");
  } else {
    print("⚠️ No gateway IP detected");
  }
}

Future<String?> getActualGatewayIp() async {
  try {
    if (Platform.isWindows) {
      return await getWindowsGateway();
    } else {
      return await getUnixGateway();
    }
  } catch (e) {
    print("⚠️ Failed to get gateway IP: $e");
    return null;
  }
}

Future<String?> getWindowsGateway() async {
  final result = await Process.run('ipconfig', []);
  final lines = result.stdout.toString().split('\n');
  for (var line in lines) {
    if (line.toLowerCase().contains("default gateway")) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length >= 3) {
        return parts.last.trim();
      }
    }
  }
  return null;
}

Future<String?> getUnixGateway() async {
  final prefs = await SharedPreferences.getInstance();
  final interfaces = await NetworkInterface.list();

  for (var interface in interfaces) {
    for (var addr in interface.addresses) {
      final ip = addr.address;

      if (addr.type == InternetAddressType.IPv4 &&
          !ip.startsWith("127.") &&
          !ip.endsWith(".255") && // Skip broadcast
          ip != "0.0.0.0") {
        // Convert to assumed gateway IP
        final segments = ip.split('.');
        if (segments.length == 4) {
          final gatewayIp = '${segments[0]}.${segments[1]}.${segments[2]}.2';
          await prefs.setString('host_ip', gatewayIp);
          print("📡 Found IP: $ip");
          print("🎯 Converted to Gateway IP: $gatewayIp");
          print("✅ Saved host_ip to SharedPreferences");
          return gatewayIp;
        }
      }
    }
  }

  print("⚠️ No suitable local IP address found.");
  return null;
}
