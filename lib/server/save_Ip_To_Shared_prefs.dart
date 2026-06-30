import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/database/network_utils/network_settings.dart';

/// Synchronizes local host IP using ACTIVE NETWORK SETTINGS.
///
/// RULES:
/// ------------------------------------------------------
/// ✅ MODEL = SOURCE OF TRUTH
/// ✅ If prefs empty -> overwrite prefs
/// ✅ If prefs invalid -> overwrite prefs
/// ✅ If prefs mismatch model -> overwrite prefs
/// ✅ If model invalid -> do nothing
/// ------------------------------------------------------
Future<String?> saveLocalIpToPrefs() async {
  try {
    final prefs = await SharedPreferences.getInstance();

    /// Current SharedPreferences value
    final prefsIp = prefs.getString('host_ip')?.trim();

    /// Model IP
    final modelIp = await getActiveNetworkHostIp();

    print('================ HOST IP SYNC =================');
    print('📦 Prefs Host IP : $prefsIp');
    print('🌐 Model Host IP : $modelIp');

    /// MODEL ALWAYS WINS
    if (modelIp != null && modelIp.isNotEmpty && _isValidIPv4(modelIp)) {
      /// Save if:
      /// - prefs empty
      /// - prefs invalid
      /// - prefs mismatch
      if (prefsIp == null ||
          prefsIp.isEmpty ||
          !_isValidIPv4(prefsIp) ||
          prefsIp != modelIp) {
        await prefs.setString('host_ip', modelIp);

        print('✅ SharedPreferences synchronized');
        print('🎯 New host_ip: $modelIp');
      } else {
        print('✅ Preferences already synchronized');
      }

      print('================================================');

      return modelIp;
    }

    print('⚠️ No valid host IP found in model');
    print('================================================');

    return null;
  } catch (e) {
    print('❌ Failed syncing local IP prefs: $e');
    return null;
  }
}

/// Fetch HOST IP from ACTIVE NETWORK SETTINGS
Future<String?> getActiveNetworkHostIp() async {
  try {
    final box = await Hive.openBox<NetworkSettings>(
      'network_settings_box',
    );

    if (box.isEmpty) {
      print('⚠️ Network settings box is empty');
      return null;
    }

    NetworkSettings? activeNetwork;

    /// Find ACTIVE NETWORK
    for (int i = 0; i < box.length; i++) {
      final network = box.getAt(i);

      if (network == null) continue;

      print('🌐 Checking Network: ${network.networkName}');
      print('📡 Host IP: ${network.hostIpAddress}');
      print('🟢 Active: ${network.isActive}');

      if (network.isActive == true) {
        activeNetwork = network;
        break;
      }
    }

    /// FALLBACK:
    /// Use first available record
    activeNetwork ??= box.getAt(0);

    if (activeNetwork == null) {
      print('⚠️ No network records found');
      return null;
    }

    final hostIp = activeNetwork.hostIpAddress?.trim();

    if (hostIp == null || hostIp.isEmpty || !_isValidIPv4(hostIp)) {
      print('⚠️ Invalid host IP in active network');
      return null;
    }

    print('✅ Active Network Host IP: $hostIp');

    return hostIp;
  } catch (e) {
    print('❌ Error reading active network host IP: $e');
    return null;
  }
}

/// IPv4 validator
bool _isValidIPv4(String ip) {
  final regex = RegExp(
    r'^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$',
  );

  return regex.hasMatch(ip);
}
