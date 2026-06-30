// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SettingsAdapter extends TypeAdapter<Settings> {
  @override
  final int typeId = 121;

  @override
  Settings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Settings(
      id: fields[0] as String,
      lastUpdated: fields[1] as DateTime,
      allowAttendanceUpdate: fields[2] as bool?,
      allowStudentSync: fields[3] as bool?,
      allowPaymentSync: fields[4] as bool?,
      autoSyncEnabled: fields[5] as bool?,
      syncIntervalMinutes: fields[6] as int?,
      maintenanceMode: fields[7] as bool?,
      schoolName: fields[8] as String?,
      schoolAddress: fields[9] as String?,
      schoolPhone: fields[10] as String?,
      schoolEmail: fields[11] as String?,
      enableBackup: fields[12] as bool?,
      backupFrequency: fields[13] as String?,
      maxStudentsPerClass: fields[14] as int?,
      allowMultipleTerms: fields[15] as bool?,
      defaultTermId: fields[16] as String?,
      enableNotifications: fields[17] as bool?,
      debugMode: fields[18] as bool?,
      modifiedFields: (fields[19] as List?)?.cast<String>(),
      operationType: fields[20] as String?,
      syncStatus: fields[21] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, Settings obj) {
    writer
      ..writeByte(22)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.lastUpdated)
      ..writeByte(2)
      ..write(obj.allowAttendanceUpdate)
      ..writeByte(3)
      ..write(obj.allowStudentSync)
      ..writeByte(4)
      ..write(obj.allowPaymentSync)
      ..writeByte(5)
      ..write(obj.autoSyncEnabled)
      ..writeByte(6)
      ..write(obj.syncIntervalMinutes)
      ..writeByte(7)
      ..write(obj.maintenanceMode)
      ..writeByte(8)
      ..write(obj.schoolName)
      ..writeByte(9)
      ..write(obj.schoolAddress)
      ..writeByte(10)
      ..write(obj.schoolPhone)
      ..writeByte(11)
      ..write(obj.schoolEmail)
      ..writeByte(12)
      ..write(obj.enableBackup)
      ..writeByte(13)
      ..write(obj.backupFrequency)
      ..writeByte(14)
      ..write(obj.maxStudentsPerClass)
      ..writeByte(15)
      ..write(obj.allowMultipleTerms)
      ..writeByte(16)
      ..write(obj.defaultTermId)
      ..writeByte(17)
      ..write(obj.enableNotifications)
      ..writeByte(18)
      ..write(obj.debugMode)
      ..writeByte(19)
      ..write(obj.modifiedFields)
      ..writeByte(20)
      ..write(obj.operationType)
      ..writeByte(21)
      ..write(obj.syncStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
