// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'article.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ArticleAdapter extends TypeAdapter<Article> {
  @override
  final int typeId = 0;

  @override
  Article read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Article(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      content: fields[3] as String,
      url: fields[4] as String,
      publishedAt: fields[6] as DateTime,
      sourceName: fields[7] as String,
      imageUrl: fields[5] as String?,
      isSaved: (fields[8] as bool) || (fields[9] as bool? ?? false),
      fullContent: fields[10] as String?,
      isLiked: fields[11] as bool,
      isDisliked: fields[12] as bool,
      translatedTitle: fields[13] as String?,
      translatedDescription: fields[14] as String?,
      translatedFullContent: fields[15] as String?,
      readTimeSeconds: fields[16] as int,
      isRead: fields[17] as bool,
      tagIds: fields[18] == null ? const [] : (fields[18] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Article obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.content)
      ..writeByte(4)
      ..write(obj.url)
      ..writeByte(5)
      ..write(obj.imageUrl)
      ..writeByte(6)
      ..write(obj.publishedAt)
      ..writeByte(7)
      ..write(obj.sourceName)
      ..writeByte(8)
      ..write(obj.isSaved)
      ..writeByte(9)
      ..write(false)
      ..writeByte(10)
      ..write(obj.fullContent)
      ..writeByte(11)
      ..write(obj.isLiked)
      ..writeByte(12)
      ..write(obj.isDisliked)
      ..writeByte(13)
      ..write(obj.translatedTitle)
      ..writeByte(14)
      ..write(obj.translatedDescription)
      ..writeByte(15)
      ..write(obj.translatedFullContent)
      ..writeByte(16)
      ..write(obj.readTimeSeconds)
      ..writeByte(17)
      ..write(obj.isRead)
      ..writeByte(18)
      ..write(obj.tagIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArticleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
