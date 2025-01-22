// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'student.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StudentAdapter extends TypeAdapter<Student> {
  @override
  final int typeId = 0;

  @override
  Student read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Student(
      name: fields[0] as String,
      surname: fields[1] as String,
      regNumber: fields[2] as String,
      class_: fields[3] as String,
      gender: fields[4] as String,
      age: fields[5] as DateTime,
      phoneNumber: fields[6] as String,
      paymentStatus: fields[7] as String,
      isPresent: fields[8] as bool,
      presentDates: (fields[9] as List?)?.cast<DateTime>(),
      absentDates: (fields[10] as List?)?.cast<DateTime>(),
      termId: fields[11] as String?,
      syncStatus: fields[12] as bool?,
      lastModified: fields[13] as DateTime?,
      operationType: fields[14] as String?,
      id: fields[15] as int?,
      physicalAddress: fields[16] as String?,
      formerSchool: fields[17] as String?,
      religion: fields[18] as String?,
      denomination: fields[19] as String?,
      studentIdNumber: fields[20] as String?,
      nationalIdNumber: fields[21] as String?,
      nationality: fields[22] as String?,
      district: fields[23] as String?,
      previousSchoolPerformanceResults: fields[24] as String?,
      enrollmentStatus: fields[25] as String?,
      emergencyContactName: fields[28] as String?,
      emergencyContactNumber: fields[29] as String?,
      healthStauts: fields[30] as String?,
      healthDetailedInformation: fields[31] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Student obj) {
    writer
      ..writeByte(30)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.surname)
      ..writeByte(2)
      ..write(obj.regNumber)
      ..writeByte(3)
      ..write(obj.class_)
      ..writeByte(4)
      ..write(obj.gender)
      ..writeByte(5)
      ..write(obj.age)
      ..writeByte(6)
      ..write(obj.phoneNumber)
      ..writeByte(7)
      ..write(obj.paymentStatus)
      ..writeByte(8)
      ..write(obj.isPresent)
      ..writeByte(9)
      ..write(obj.presentDates)
      ..writeByte(10)
      ..write(obj.absentDates)
      ..writeByte(11)
      ..write(obj.termId)
      ..writeByte(12)
      ..write(obj.syncStatus)
      ..writeByte(13)
      ..write(obj.lastModified)
      ..writeByte(14)
      ..write(obj.operationType)
      ..writeByte(15)
      ..write(obj.id)
      ..writeByte(16)
      ..write(obj.physicalAddress)
      ..writeByte(17)
      ..write(obj.formerSchool)
      ..writeByte(18)
      ..write(obj.religion)
      ..writeByte(19)
      ..write(obj.denomination)
      ..writeByte(20)
      ..write(obj.studentIdNumber)
      ..writeByte(21)
      ..write(obj.nationalIdNumber)
      ..writeByte(22)
      ..write(obj.nationality)
      ..writeByte(23)
      ..write(obj.district)
      ..writeByte(24)
      ..write(obj.previousSchoolPerformanceResults)
      ..writeByte(25)
      ..write(obj.enrollmentStatus)
      ..writeByte(28)
      ..write(obj.emergencyContactName)
      ..writeByte(29)
      ..write(obj.emergencyContactNumber)
      ..writeByte(30)
      ..write(obj.healthStauts)
      ..writeByte(31)
      ..write(obj.healthDetailedInformation);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
