import 'package:hive/hive.dart';
import 'package:zitf_system/database/settings.dart';

class SettingsHelper {
  static final String _boxName = 'settings';

  // ✅ Get the settings box
  static Future<Box<Settings>> _getBox() async {
    return await Hive.openBox<Settings>(_boxName);
  }

  // ✅ Get settings (or create default if none exist)
  static Future<Settings> getSettings() async {
    final box = await _getBox();

    if (box.isEmpty) {
      // Create default settings if none exist
      final defaultSettings = Settings.createDefault();
      await box.add(defaultSettings);
      return defaultSettings;
    }

    return box.values.first;
  }

  // ✅ Update settings
  static Future<void> updateSettings(Settings settings) async {
    final box = await _getBox();
    await settings.save();
  }

  // ✅ Get a specific setting value
  static Future<T?> getSetting<T>(String fieldName) async {
    final settings = await getSettings();
    switch (fieldName) {
      case 'allowAttendanceUpdate':
        return settings.allowAttendanceUpdate as T?;
      case 'allowStudentSync':
        return settings.allowStudentSync as T?;
      case 'allowPaymentSync':
        return settings.allowPaymentSync as T?;
      case 'autoSyncEnabled':
        return settings.autoSyncEnabled as T?;
      case 'syncIntervalMinutes':
        return settings.syncIntervalMinutes as T?;
      case 'maintenanceMode':
        return settings.maintenanceMode as T?;
      case 'schoolName':
        return settings.schoolName as T?;
      case 'schoolAddress':
        return settings.schoolAddress as T?;
      case 'schoolPhone':
        return settings.schoolPhone as T?;
      case 'schoolEmail':
        return settings.schoolEmail as T?;
      case 'enableBackup':
        return settings.enableBackup as T?;
      case 'backupFrequency':
        return settings.backupFrequency as T?;
      case 'maxStudentsPerClass':
        return settings.maxStudentsPerClass as T?;
      case 'allowMultipleTerms':
        return settings.allowMultipleTerms as T?;
      case 'defaultTermId':
        return settings.defaultTermId as T?;
      case 'enableNotifications':
        return settings.enableNotifications as T?;
      case 'debugMode':
        return settings.debugMode as T?;
      default:
        return null;
    }
  }

  // ✅ Update a specific setting
  static Future<void> updateSetting<T>(String fieldName, T value) async {
    final settings = await getSettings();

    switch (fieldName) {
      case 'allowAttendanceUpdate':
        settings.allowAttendanceUpdate = value as bool?;
        break;
      case 'allowStudentSync':
        settings.allowStudentSync = value as bool?;
        break;
      case 'allowPaymentSync':
        settings.allowPaymentSync = value as bool?;
        break;
      case 'autoSyncEnabled':
        settings.autoSyncEnabled = value as bool?;
        break;
      case 'syncIntervalMinutes':
        settings.syncIntervalMinutes = value as int?;
        break;
      case 'maintenanceMode':
        settings.maintenanceMode = value as bool?;
        break;
      case 'schoolName':
        settings.schoolName = value as String?;
        break;
      case 'schoolAddress':
        settings.schoolAddress = value as String?;
        break;
      case 'schoolPhone':
        settings.schoolPhone = value as String?;
        break;
      case 'schoolEmail':
        settings.schoolEmail = value as String?;
        break;
      case 'enableBackup':
        settings.enableBackup = value as bool?;
        break;
      case 'backupFrequency':
        settings.backupFrequency = value as String?;
        break;
      case 'maxStudentsPerClass':
        settings.maxStudentsPerClass = value as int?;
        break;
      case 'allowMultipleTerms':
        settings.allowMultipleTerms = value as bool?;
        break;
      case 'defaultTermId':
        settings.defaultTermId = value as String?;
        break;
      case 'enableNotifications':
        settings.enableNotifications = value as bool?;
        break;
      case 'debugMode':
        settings.debugMode = value as bool?;
        break;
      default:
        throw Exception('Unknown setting field: $fieldName');
    }

    settings.markFieldModified(fieldName);
    await settings.save();
  }

  // ✅ Toggle attendance update permission
  static Future<void> toggleAttendanceUpdate(bool allowed) async {
    final settings = await getSettings();
    settings.toggleAttendanceUpdate(allowed);
    await settings.save();
  }

  // ✅ Check if attendance updates are allowed
  static Future<bool> isAttendanceUpdateAllowed() async {
    final settings = await getSettings();
    return settings.isAttendanceUpdateAllowed();
  }
}
