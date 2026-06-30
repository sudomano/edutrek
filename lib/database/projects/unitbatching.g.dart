// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unitbatching.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BatchUnitAdapter extends TypeAdapter<BatchUnit> {
  @override
  final int typeId = 65;

  @override
  BatchUnit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BatchUnit(
      level: fields[0] as PackagingLevel,
      unitsPerPackage: fields[1] as double,
      quantity: fields[2] as int,
      buyingPrice: fields[3] as double,
      syncStatus: fields[4] as bool?,
      lastModified: fields[5] as DateTime?,
      operationType: fields[6] as String?,
      modifiedFields: (fields[7] as List?)?.cast<String>(),
      unitBatchCode: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BatchUnit obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.level)
      ..writeByte(1)
      ..write(obj.unitsPerPackage)
      ..writeByte(2)
      ..write(obj.quantity)
      ..writeByte(3)
      ..write(obj.buyingPrice)
      ..writeByte(4)
      ..write(obj.syncStatus)
      ..writeByte(5)
      ..write(obj.lastModified)
      ..writeByte(6)
      ..write(obj.operationType)
      ..writeByte(7)
      ..write(obj.modifiedFields)
      ..writeByte(8)
      ..write(obj.unitBatchCode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatchUnitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
