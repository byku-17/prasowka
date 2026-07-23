// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'news_source.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NewsSourceAdapter extends TypeAdapter<NewsSource> {
  @override
  final int typeId = 1;

  @override
  NewsSource read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NewsSource(
      id: fields[0] as String,
      name: fields[1] as String,
      rssUrl: fields[2] as String,
      categoryId: fields[4] as String,
      logoUrl: fields[3] as String?,
    ).._isDefault = fields[5] as bool?;
  }

  @override
  void write(BinaryWriter writer, NewsSource obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.rssUrl)
      ..writeByte(3)
      ..write(obj.logoUrl)
      ..writeByte(4)
      ..write(obj.categoryId)
      ..writeByte(5)
      ..write(obj._isDefault);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NewsSourceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
