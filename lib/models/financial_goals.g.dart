// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'financial_goals.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FinancialGoalsAdapter extends TypeAdapter<FinancialGoals> {
  @override
  final int typeId = 3;

  @override
  FinancialGoals read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FinancialGoals(
      monthlyIncomeTarget: fields[0] as double,
      monthlyExpenseLimit: fields[1] as double,
      savingsTarget: fields[2] as double,
      lastUpdated: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, FinancialGoals obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.monthlyIncomeTarget)
      ..writeByte(1)
      ..write(obj.monthlyExpenseLimit)
      ..writeByte(2)
      ..write(obj.savingsTarget)
      ..writeByte(3)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinancialGoalsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
