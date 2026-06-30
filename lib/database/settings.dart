import 'package:hive/hive.dart';

part 'settings.g.dart'; // Required for code generation

@HiveType(typeId: 121) // Unique identifier for Hive (use next available number)
class Settings extends HiveObject {
  @HiveField(0)
  late String
      id; // Unique identifier for the settings record (e.g., 'app_settings')

  @HiveField(1)
  late DateTime lastUpdated; // When the settings were last updated

  @HiveField(2)
  bool? allowAttendanceUpdate; // Allow clients to update existing attendance

  @HiveField(3)
  bool? allowStudentSync; // Allow clients to sync students

  @HiveField(4)
  bool? allowPaymentSync; // Allow clients to sync payments

  @HiveField(5)
  bool? autoSyncEnabled; // Enable automatic sync

  @HiveField(6)
  int? syncIntervalMinutes; // Sync interval in minutes

  @HiveField(7)
  bool? maintenanceMode; // Put the system in maintenance mode

  @HiveField(8)
  String? schoolName; // School name for display

  @HiveField(9)
  String? schoolAddress; // School address

  @HiveField(10)
  String? schoolPhone; // School phone number

  @HiveField(11)
  String? schoolEmail; // School email

  @HiveField(12)
  bool? enableBackup; // Enable automatic backup

  @HiveField(13)
  String? backupFrequency; // Daily, Weekly, Monthly

  @HiveField(14)
  int? maxStudentsPerClass; // Maximum students per class

  @HiveField(15)
  bool? allowMultipleTerms; // Allow multiple terms per student

  @HiveField(16)
  String? defaultTermId; // Default term ID to use

  @HiveField(17)
  bool? enableNotifications; // Enable push notifications

  @HiveField(18)
  bool? debugMode; // Enable debug mode

  @HiveField(19)
  List<String>? modifiedFields; // Tracks fields that were modified

  @HiveField(20)
  String? operationType; // 'create', 'update', or 'delete'

  @HiveField(21)
  bool? syncStatus; // Track sync status

  Settings({
    required this.id,
    required this.lastUpdated,
    this.allowAttendanceUpdate = false, // Default: block updates
    this.allowStudentSync = true,
    this.allowPaymentSync = true,
    this.autoSyncEnabled = false,
    this.syncIntervalMinutes = 5,
    this.maintenanceMode = false,
    this.schoolName,
    this.schoolAddress,
    this.schoolPhone,
    this.schoolEmail,
    this.enableBackup = false,
    this.backupFrequency = 'Daily',
    this.maxStudentsPerClass = 30,
    this.allowMultipleTerms = true,
    this.defaultTermId,
    this.enableNotifications = true,
    this.debugMode = false,
    this.modifiedFields,
    this.operationType,
    this.syncStatus = true,
  });

  Settings copyWith({
    String? id,
    DateTime? lastUpdated,
    bool? allowAttendanceUpdate,
    bool? allowStudentSync,
    bool? allowPaymentSync,
    bool? autoSyncEnabled,
    int? syncIntervalMinutes,
    bool? maintenanceMode,
    String? schoolName,
    String? schoolAddress,
    String? schoolPhone,
    String? schoolEmail,
    bool? enableBackup,
    String? backupFrequency,
    int? maxStudentsPerClass,
    bool? allowMultipleTerms,
    String? defaultTermId,
    bool? enableNotifications,
    bool? debugMode,
    List<String>? modifiedFields,
    String? operationType,
    bool? syncStatus,
  }) {
    return Settings(
      id: id ?? this.id,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      allowAttendanceUpdate:
          allowAttendanceUpdate ?? this.allowAttendanceUpdate,
      allowStudentSync: allowStudentSync ?? this.allowStudentSync,
      allowPaymentSync: allowPaymentSync ?? this.allowPaymentSync,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      schoolName: schoolName ?? this.schoolName,
      schoolAddress: schoolAddress ?? this.schoolAddress,
      schoolPhone: schoolPhone ?? this.schoolPhone,
      schoolEmail: schoolEmail ?? this.schoolEmail,
      enableBackup: enableBackup ?? this.enableBackup,
      backupFrequency: backupFrequency ?? this.backupFrequency,
      maxStudentsPerClass: maxStudentsPerClass ?? this.maxStudentsPerClass,
      allowMultipleTerms: allowMultipleTerms ?? this.allowMultipleTerms,
      defaultTermId: defaultTermId ?? this.defaultTermId,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      debugMode: debugMode ?? this.debugMode,
      modifiedFields: modifiedFields ?? this.modifiedFields,
      operationType: operationType ?? this.operationType,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  // ✅ Factory method to create default settings
  static Settings createDefault() {
    return Settings(
      id: 'app_settings',
      lastUpdated: DateTime.now(),
      allowAttendanceUpdate: false, // Block updates by default
      allowStudentSync: true,
      allowPaymentSync: true,
      autoSyncEnabled: false,
      syncIntervalMinutes: 5,
      maintenanceMode: false,
      enableBackup: false,
      backupFrequency: 'Daily',
      maxStudentsPerClass: 30,
      allowMultipleTerms: true,
      enableNotifications: true,
      debugMode: false,
      syncStatus: true,
      modifiedFields: [],
      operationType: 'create',
    );
  }

  // ✅ Helper method to mark a field as modified
  void markFieldModified(String fieldName) {
    if (modifiedFields == null) {
      modifiedFields = [];
    }
    if (!modifiedFields!.contains(fieldName)) {
      modifiedFields!.add(fieldName);
    }
    lastUpdated = DateTime.now();
    operationType = 'update';
    syncStatus = false;
  }

  // ✅ Helper method to reset modified fields
  void resetModifiedFields() {
    modifiedFields = [];
    operationType = 'create';
    syncStatus = true;
  }

  // ✅ Helper method to check if updates are allowed
  bool isAttendanceUpdateAllowed() {
    return allowAttendanceUpdate ?? false;
  }

  // ✅ Helper method to toggle attendance update permission
  void toggleAttendanceUpdate(bool allowed) {
    allowAttendanceUpdate = allowed;
    markFieldModified('allowAttendanceUpdate');
  }
}
