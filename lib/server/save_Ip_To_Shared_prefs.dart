import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

Future<String?> saveLocalIpToPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  final interfaces = await NetworkInterface.list();

  for (var interface in interfaces) {
    for (var addr in interface.addresses) {
      if (addr.type == InternetAddressType.IPv4 &&
          !addr.address.startsWith("127.") &&
          addr.address.endsWith(".1")) {
        final ip = addr.address;
        await prefs.setString('host_ip', ip);
        print("📡 Local IP: $ip");
        print("✅ Saved host IP to SharedPreferences: $ip");
        return ip;
      }
    }
  }

  print("⚠️ No suitable local IP address found.");
  return null;
}
