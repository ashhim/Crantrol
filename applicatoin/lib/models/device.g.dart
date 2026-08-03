// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DeviceAdapter extends TypeAdapter<Device> {
  @override
  final int typeId = 0;

  @override
  Device read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Device(
      deviceId: fields[0] as String,
      deviceName: fields[1] as String,
      roomId: fields[2] as String,
      roomCode: fields[3] as String,
      localIp: fields[4] as String,
      isOnline: fields[5] as bool,
      ethernetPlugged: fields[6] as bool,
      internetAvailable: fields[7] as bool,
      firebaseReady: fields[8] as bool,
      lastSeen: fields[9] as DateTime,
      relays: (fields[10] as List).cast<Relay>(),
    );
  }

  @override
  void write(BinaryWriter writer, Device obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.deviceId)
      ..writeByte(1)
      ..write(obj.deviceName)
      ..writeByte(2)
      ..write(obj.roomId)
      ..writeByte(3)
      ..write(obj.roomCode)
      ..writeByte(4)
      ..write(obj.localIp)
      ..writeByte(5)
      ..write(obj.isOnline)
      ..writeByte(6)
      ..write(obj.ethernetPlugged)
      ..writeByte(7)
      ..write(obj.internetAvailable)
      ..writeByte(8)
      ..write(obj.firebaseReady)
      ..writeByte(9)
      ..write(obj.lastSeen)
      ..writeByte(10)
      ..write(obj.relays);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RelayAdapter extends TypeAdapter<Relay> {
  @override
  final int typeId = 1;

  @override
  Relay read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Relay(
      id: fields[0] as int,
      name: fields[1] as String,
      pin: fields[2] as int,
      activeLow: fields[3] as bool,
      isOn: fields[4] as bool,
      isPulse: fields[5] as bool,
      pulseDurationMs: fields[6] as int,
      enabled: fields[7] as bool,
      lastCommandTime: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Relay obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.pin)
      ..writeByte(3)
      ..write(obj.activeLow)
      ..writeByte(4)
      ..write(obj.isOn)
      ..writeByte(5)
      ..write(obj.isPulse)
      ..writeByte(6)
      ..write(obj.pulseDurationMs)
      ..writeByte(7)
      ..write(obj.enabled)
      ..writeByte(8)
      ..write(obj.lastCommandTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelayAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
