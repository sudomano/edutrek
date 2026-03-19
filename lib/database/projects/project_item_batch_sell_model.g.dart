// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_item_batch_sell_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BatchSellUnitAdapter extends TypeAdapter<BatchSellUnit> {
  @override
  final int typeId = 63;

  @override
  BatchSellUnit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BatchSellUnit(
      batchCode: fields[1] as String,
      sellUnitCode: fields[0] as String,
      unitName: fields[2] as String,
      quantityMultiplier: fields[3] as int,
      sellingPrice: fields[4] as double,
      active: fields[5] as bool,
      syncStatus: fields[8] as bool?,
      lastModified: fields[9] as DateTime?,
      operationType: fields[10] as String?,
      modifiedFields: (fields[11] as List?)?.cast<String>(),
      packagingLevel: fields[12] as PackagingLevel?,
      baseUnitsPerSellUnit: fields[13] as double?,
      baseUnit: fields[14] as String?,
      baseUnitType: fields[15] as StockUnitType?,
      deletedAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, BatchSellUnit obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.sellUnitCode)
      ..writeByte(1)
      ..write(obj.batchCode)
      ..writeByte(2)
      ..write(obj.unitName)
      ..writeByte(3)
      ..write(obj.quantityMultiplier)
      ..writeByte(4)
      ..write(obj.sellingPrice)
      ..writeByte(5)
      ..write(obj.active)
      ..writeByte(6)
      ..write(obj.deletedAt)
      ..writeByte(8)
      ..write(obj.syncStatus)
      ..writeByte(9)
      ..write(obj.lastModified)
      ..writeByte(10)
      ..write(obj.operationType)
      ..writeByte(11)
      ..write(obj.modifiedFields)
      ..writeByte(12)
      ..write(obj.packagingLevel)
      ..writeByte(13)
      ..write(obj.baseUnitsPerSellUnit)
      ..writeByte(14)
      ..write(obj.baseUnit)
      ..writeByte(15)
      ..write(obj.baseUnitType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatchSellUnitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
