// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'follow_up.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FollowUpTypeAdapter extends TypeAdapter<FollowUpType> {
  @override
  final int typeId = 4;

  @override
  FollowUpType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return FollowUpType.toReceive;
      case 1:
        return FollowUpType.toPay;
      default:
        return FollowUpType.toReceive;
    }
  }

  @override
  void write(BinaryWriter writer, FollowUpType obj) {
    switch (obj) {
      case FollowUpType.toReceive:
        writer.writeByte(0);
        break;
      case FollowUpType.toPay:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FollowUpTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FollowUpAdapter extends TypeAdapter<FollowUp> {
  @override
  final int typeId = 5;

  @override
  FollowUp read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FollowUp(
      id: fields[0] as String,
      title: fields[1] as String,
      contactName: fields[2] as String,
      phoneNumber: fields[3] as String?,
      amount: fields[4] as double,
      dueDate: fields[5] as DateTime,
      type: fields[6] as FollowUpType,
      isCompleted: fields[7] as bool? ?? false,
      note: fields[8] as String?,
      bookId: fields[9] as String? ?? 'default-book',
      createdAt: fields[10] as DateTime? ?? DateTime.now(),
      completedAt: fields[11] as DateTime?,
      linkedTransactionId: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FollowUp obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.contactName)
      ..writeByte(3)
      ..write(obj.phoneNumber)
      ..writeByte(4)
      ..write(obj.amount)
      ..writeByte(5)
      ..write(obj.dueDate)
      ..writeByte(6)
      ..write(obj.type)
      ..writeByte(7)
      ..write(obj.isCompleted)
      ..writeByte(8)
      ..write(obj.note)
      ..writeByte(9)
      ..write(obj.bookId)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.completedAt)
      ..writeByte(12)
      ..write(obj.linkedTransactionId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FollowUpAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
