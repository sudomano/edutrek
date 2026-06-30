import 'dart:io';

import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/database/network_utils/network_settings.dart';

/// Synchronizes SharedPreferences host_ip
/// with the ACTIVE NETWORK model.
///
/// RULES:
/// 1. MODEL is the source of truth.
/// 2. If prefs is empty -> overwrite prefs.
/// 3. If prefs mismatches model -> overwrite prefs.
/// 4. If model has no valid IP -> do nothing.
/// 5. Always validate before saving.
Future<String?> saveGatewayToPrefs() async {
  try {
    print('\n');
    print('============= GATEWAY PREF SYNC START =============');

    final prefs = await SharedPreferences.getInstance();

    print('📦 SharedPreferences opened');

    final box = await Hive.openBox<NetworkSettings>(
      'network_settings_box',
    );

    print('📂 Hive box opened');
    print('📊 Total network records: ${box.length}');

    if (box.isEmpty) {
      print('❌ NETWORK SETTINGS BOX IS EMPTY');
      print('==================================================');
      return null;
    }

    NetworkSettings? activeNetwork;

    for (int i = 0; i < box.length; i++) {
      final network = box.getAt(i);

      if (network == null) {
        print('⚠️ NULL network at index $i');
        continue;
      }

      print('----------------------------------------');
      print('📌 RECORD INDEX: $i');
      print('🌐 Network Name: ${network.networkName}');
      print('📡 Host IP: ${network.hostIpAddress}');
      print('🛣 Gateway: ${network.gateway}');
      print('🟢 isActive: ${network.isActive}');
      print('----------------------------------------');

      if (network.isActive == true) {
        activeNetwork = network;

        print('✅ ACTIVE NETWORK FOUND');
        break;
      }
    }

    /// FALLBACK TO FIRST RECORD
    activeNetwork ??= box.getAt(0);

    if (activeNetwork == null) {
      print('❌ ACTIVE NETWORK STILL NULL');
      print('==================================================');
      return null;
    }

    print('🎯 FINAL NETWORK SELECTED:');
    print('🌐 ${activeNetwork.networkName}');
    print('📡 ${activeNetwork.hostIpAddress}');

    final modelIp = activeNetwork.hostIpAddress?.trim();

    print('🧹 Trimmed IP: $modelIp');

    if (modelIp == null || modelIp.isEmpty) {
      print('❌ MODEL IP IS NULL OR EMPTY');
      print('==================================================');
      return null;
    }

    final isValid = _isValidIPv4(modelIp);

    print('🧪 IPv4 Validation Result: $isValid');

    if (!isValid) {
      print('❌ INVALID IPv4 FORMAT');
      print('==================================================');
      return null;
    }

    final prefsIp = prefs.getString('host_ip')?.trim();

    print('📦 Existing Pref IP: $prefsIp');

    if (prefsIp != modelIp) {
      print('🔄 PREFS MISMATCH DETECTED');
      print('📥 Saving model IP into prefs...');

      await prefs.setString(
        'host_ip',
        modelIp,
      );

      print('✅ PREFS UPDATED SUCCESSFULLY');
    } else {
      print('✅ PREFS ALREADY MATCH MODEL');
    }

    final verifyIp = prefs.getString('host_ip');

    print('🔍 VERIFIED SAVED PREF IP: $verifyIp');

    print('============= GATEWAY PREF SYNC END =============');
    print('\n');

    return verifyIp;
  } catch (e, stack) {
    print('❌ GATEWAY SYNC CRASH: $e');
    print(stack);

    return null;
  }
}

/// Fetch ACTIVE NETWORK HOST IP from Hive
Future<String?> getActiveNetworkGatewayIp() async {
  try {
    final box = await Hive.openBox<NetworkSettings>(
      'network_settings_box',
    );

    if (box.isEmpty) {
      print('⚠️ Network settings box empty');
      return null;
    }

    NetworkSettings? activeNetwork;

    /// Find ACTIVE NETWORK
    for (int i = 0; i < box.length; i++) {
      final network = box.getAt(i);

      if (network == null) continue;

      print('🌐 Checking: ${network.networkName}');
      print('📡 Host IP: ${network.hostIpAddress}');
      print('🟢 Active : ${network.isActive}');

      if (network.isActive == true) {
        activeNetwork = network;
        break;
      }
    }

    /// FALLBACK:
    /// Use first available network if none active
    activeNetwork ??= box.getAt(0);

    if (activeNetwork == null) {
      print('⚠️ No network records found');
      return null;
    }

    final hostIp = activeNetwork.hostIpAddress?.trim();

    if (hostIp == null || hostIp.isEmpty || !_isValidIPv4(hostIp)) {
      print('⚠️ Invalid host IP in model');
      return null;
    }

    print('✅ Active Network IP Selected: $hostIp');

    return hostIp;
  } catch (e) {
    print('❌ Error fetching active network IP: $e');
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

/// LEGACY COMPATIBILITY
Future<String?> getActualGatewayIp() async {
  return await getActiveNetworkGatewayIp();
}

/// LEGACY WINDOWS METHOD
Future<String?> getWindowsGateway() async {
  return await getActiveNetworkGatewayIp();
}

/// LEGACY UNIX METHOD
Future<String?> getUnixGateway() async {
  return await getActiveNetworkGatewayIp();
}
