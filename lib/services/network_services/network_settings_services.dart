import 'package:hive/hive.dart';
import 'package:zitf_system/database/network_utils/network_settings.dart';

class NetworkSettingsService {
  static const String _boxName = 'network_settings_box';
  late Box<NetworkSettings> _box;

  Future<void> init() async {
    _box = await Hive.openBox<NetworkSettings>(_boxName);
  }

  // Create
  Future<void> createSetting(NetworkSettings setting) async {
    await _box.put(setting.id, setting);
  }

  // Read (get all)
  List<NetworkSettings> getAllSettings() {
    return _box.values.toList();
  }

  // Read (get active setting)
  NetworkSettings? getActiveSetting() {
    try {
      return _box.values.firstWhere((setting) => setting.isActive);
    } catch (e) {
      return null;
    }
  }

  // Read (get by id)
  NetworkSettings? getSettingById(String id) {
    return _box.get(id);
  }

  // Update
  Future<void> updateSetting(NetworkSettings setting) async {
    await _box.put(setting.id, setting);
  }

  // Delete
  Future<void> deleteSetting(String id) async {
    await _box.delete(id);
  }

  // Set active setting (deactivate others)
  Future<void> setActiveSetting(String? id) async {
    for (var setting in _box.values) {
      final updatedSetting = setting.copyWith(isActive: setting.id == id);
      await _box.put(setting.id, updatedSetting);
    }
  }

  // Clear all settings
  Future<void> clearAllSettings() async {
    await _box.clear();
  }
}
