// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'teachers.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TeachersAdapter extends TypeAdapter<Teachers> {
  @override
  final int typeId = 10;

  @override
  Teachers read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Teachers(
      name: fields[0] as String,
      surname: fields[1] as String,
      IdNumber: fields[2] as String,
      assignedClass: fields[3] as String?,
      assignedClasses: (fields[21] as List?)?.cast<String>(),
      gender: fields[4] as String,
      dateOfBirth: fields[5] as DateTime,
      phoneNumber: fields[6] as String,
      paymentPurpose: fields[7] as String,
      isPaid: fields[8] as bool,
      paymentDate: fields[10] as DateTime?,
      paymentAmount: fields[9] as double,
      email: fields[11] as String,
      address: fields[12] as String,
      hireDate: fields[13] as DateTime,
      qualifications: fields[14] as String,
      employmentStatus: fields[15] as String,
      termId: fields[16] as String?,
      syncStatus: fields[17] as bool?,
      lastModified: fields[18] as DateTime?,
      operationType: fields[19] as String?,
      id: fields[20] as int?,
      modifiedFields: (fields[22] as List?)?.cast<String>(),
      terms: (fields[23] as List?)?.cast<String>(),
      isDeleted: fields[24] as bool?,
      deletedAt: fields[25] as DateTime?,
      deletedBy: fields[26] as String?,
      deleteReason: fields[27] as String?,
      deletedSyncStatus: fields[28] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, Teachers obj) {
    writer
      ..writeByte(29)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.surname)
      ..writeByte(2)
      ..write(obj.IdNumber)
      ..writeByte(3)
      ..write(obj.assignedClass)
      ..writeByte(4)
      ..write(obj.gender)
      ..writeByte(5)
      ..write(obj.dateOfBirth)
      ..writeByte(6)
      ..write(obj.phoneNumber)
      ..writeByte(7)
      ..write(obj.paymentPurpose)
      ..writeByte(8)
      ..write(obj.isPaid)
      ..writeByte(9)
      ..write(obj.paymentAmount)
      ..writeByte(10)
      ..write(obj.paymentDate)
      ..writeByte(11)
      ..write(obj.email)
      ..writeByte(12)
      ..write(obj.address)
      ..writeByte(13)
      ..write(obj.hireDate)
      ..writeByte(14)
      ..write(obj.qualifications)
      ..writeByte(15)
      ..write(obj.employmentStatus)
      ..writeByte(16)
      ..write(obj.termId)
      ..writeByte(17)
      ..write(obj.syncStatus)
      ..writeByte(18)
      ..write(obj.lastModified)
      ..writeByte(19)
      ..write(obj.operationType)
      ..writeByte(20)
      ..write(obj.id)
      ..writeByte(21)
      ..write(obj.assignedClasses)
      ..writeByte(22)
      ..write(obj.modifiedFields)
      ..writeByte(23)
      ..write(obj.terms)
      ..writeByte(24)
      ..write(obj.isDeleted)
      ..writeByte(25)
      ..write(obj.deletedAt)
      ..writeByte(26)
      ..write(obj.deletedBy)
      ..writeByte(27)
      ..write(obj.deleteReason)
      ..writeByte(28)
      ..write(obj.deletedSyncStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeachersAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
