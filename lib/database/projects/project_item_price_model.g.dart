// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_item_price_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProjectItemPriceAdapter extends TypeAdapter<ProjectItemPrice> {
  @override
  final int typeId = 60;

  @override
  ProjectItemPrice read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProjectItemPrice(
      priceCode: fields[0] as String,
      projectItemCode: fields[1] as String,
      amount: fields[2] as double,
      pricingType: fields[3] as String,
      appliesTo: fields[4] as String?,
      effectiveFrom: fields[5] as DateTime,
      effectiveTo: fields[6] as DateTime?,
      syncStatus: fields[7] as bool?,
      lastModified: fields[8] as DateTime?,
      operationType: fields[9] as String?,
      modifiedFields: (fields[10] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, ProjectItemPrice obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.priceCode)
      ..writeByte(1)
      ..write(obj.projectItemCode)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.pricingType)
      ..writeByte(4)
      ..write(obj.appliesTo)
      ..writeByte(5)
      ..write(obj.effectiveFrom)
      ..writeByte(6)
      ..write(obj.effectiveTo)
      ..writeByte(7)
      ..write(obj.syncStatus)
      ..writeByte(8)
      ..write(obj.lastModified)
      ..writeByte(9)
      ..write(obj.operationType)
      ..writeByte(10)
      ..write(obj.modifiedFields);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectItemPriceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
