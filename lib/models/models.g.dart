// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AnalysisResultAdapter extends TypeAdapter<AnalysisResult> {
  @override
  final int typeId = 0;

  @override
  AnalysisResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AnalysisResult(
      id: fields[0] as String,
      timestamp: fields[1] as DateTime,
      imagePath: fields[2] as String,
      greenG: fields[3] as double,
      cloverG: fields[4] as double,
      deadG: fields[5] as double,
      surfaceHa: fields[6] as double,
      troupeauSize: fields[7] as int,
      espece: fields[8] as String,
      latitude: fields[9] as double?,
      longitude: fields[10] as double?,
      zoneName: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AnalysisResult obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.imagePath)
      ..writeByte(3)
      ..write(obj.greenG)
      ..writeByte(4)
      ..write(obj.cloverG)
      ..writeByte(5)
      ..write(obj.deadG)
      ..writeByte(6)
      ..write(obj.surfaceHa)
      ..writeByte(7)
      ..write(obj.troupeauSize)
      ..writeByte(8)
      ..write(obj.espece)
      ..writeByte(9)
      ..write(obj.latitude)
      ..writeByte(10)
      ..write(obj.longitude)
      ..writeByte(11)
      ..write(obj.zoneName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalysisResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class EleveurProfileAdapter extends TypeAdapter<EleveurProfile> {
  @override
  final int typeId = 1;

  @override
  EleveurProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EleveurProfile(
      nom: fields[0] as String,
      espece: fields[1] as String,
      troupeauSize: fields[2] as int,
      region: fields[3] as String,
      isNomade: fields[4] as bool,
      createdAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, EleveurProfile obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.nom)
      ..writeByte(1)
      ..write(obj.espece)
      ..writeByte(2)
      ..write(obj.troupeauSize)
      ..writeByte(3)
      ..write(obj.region)
      ..writeByte(4)
      ..write(obj.isNomade)
      ..writeByte(5)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EleveurProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SavedZoneAdapter extends TypeAdapter<SavedZone> {
  @override
  final int typeId = 2;

  @override
  SavedZone read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavedZone(
      id: fields[0] as String,
      name: fields[1] as String,
      latitude: fields[2] as double,
      longitude: fields[3] as double,
      surfaceHa: fields[4] as double,
      polygonLats: (fields[5] as List).cast<double>(),
      polygonLngs: (fields[6] as List).cast<double>(),
      lastAnalyzed: fields[7] as DateTime,
      lastScore: fields[8] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, SavedZone obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.latitude)
      ..writeByte(3)
      ..write(obj.longitude)
      ..writeByte(4)
      ..write(obj.surfaceHa)
      ..writeByte(5)
      ..write(obj.polygonLats)
      ..writeByte(6)
      ..write(obj.polygonLngs)
      ..writeByte(7)
      ..write(obj.lastAnalyzed)
      ..writeByte(8)
      ..write(obj.lastScore);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedZoneAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
