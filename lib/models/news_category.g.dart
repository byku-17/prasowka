// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'news_category.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NewsCategoryAdapter extends TypeAdapter<NewsCategory> {
  @override
  final int typeId = 2;

  @override
  NewsCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NewsCategory(
      id: fields[0] as String,
      name: fields[1] as String,
      iconCode: fields[2] as int,
      isCustom: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, NewsCategory obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.iconCode)
      ..writeByte(3)
      ..write(obj.isCustom);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NewsCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
