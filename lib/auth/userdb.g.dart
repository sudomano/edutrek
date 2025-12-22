// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'userdb.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserAdapter extends TypeAdapter<User> {
  @override
  final int typeId = 8;

  @override
  User read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return User(
      username: fields[0] as String,
      password: fields[1] as String,
      role: fields[2] as String,
      securityQuestions: (fields[3] as List).cast<String>(),
      securityAnswers: (fields[4] as List).cast<String>(),
      phone: fields[5] as String,
      termId: fields[6] as String?,
      syncStatus: fields[7] as bool?,
      lastModified: fields[8] as DateTime?,
      operationType: fields[9] as String?,
      id: fields[10] as int?,
      isLogged: fields[11] as bool?,
      userCode: fields[12] as String?,
      modifiedFields: (fields[13] as List?)?.cast<String>(),
      email: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.username)
      ..writeByte(1)
      ..write(obj.password)
      ..writeByte(2)
      ..write(obj.role)
      ..writeByte(3)
      ..write(obj.securityQuestions)
      ..writeByte(4)
      ..write(obj.securityAnswers)
      ..writeByte(5)
      ..write(obj.phone)
      ..writeByte(6)
      ..write(obj.termId)
      ..writeByte(7)
      ..write(obj.syncStatus)
      ..writeByte(8)
      ..write(obj.lastModified)
      ..writeByte(9)
      ..write(obj.operationType)
      ..writeByte(10)
      ..write(obj.id)
      ..writeByte(11)
      ..write(obj.isLogged)
      ..writeByte(12)
      ..write(obj.userCode)
      ..writeByte(13)
      ..write(obj.modifiedFields)
      ..writeByte(14)
      ..write(obj.email);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
