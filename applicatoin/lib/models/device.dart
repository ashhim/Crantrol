import 'package:hive/hive.dart';

part 'device.g.dart';

const int kMaxRelaySlots = 10;
const int kHeartbeatFreshnessMs = 15000;

int _readIntValue(dynamic value, int fallback) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

bool _readBoolValue(dynamic value, bool fallback) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.toLowerCase().trim();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return fallback;
}

String _readStringValue(dynamic value, String fallback) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

int _parseRelayId(dynamic value, int fallback) {
  if (value is num) return value.toInt();
  if (value is String) {
    final lowered = value.toLowerCase().trim();
    final cleaned =
        lowered.startsWith('relay') ? lowered.substring(5) : lowered;
    return int.tryParse(cleaned) ?? fallback;
  }
  return fallback;
}

int resolveRelayPin(int? pin, int fallback) {
  if (pin == null) return fallback;
  return pin;
}

String _relayDefaultName(int id) {
  switch (id) {
    case 1:
      return 'PLUG1';
    case 2:
      return 'PLUG2';
    case 3:
      return 'PLUG3';
    case 4:
      return 'PLUG4';
    case 5:
      return 'PLUG5';
    case 6:
      return 'PLUG6';
    case 7:
      return 'PLUG7';
    case 8:
      return 'PLUG8';
    case 9:
      return 'Power';
    case 10:
      return 'Reset';
    default:
      return 'Relay $id';
  }
}

int _relayDefaultPin(int id) {
  switch (id) {
    case 1:
      return 21;
    case 2:
      return 17;
    case 3:
      return 16;
    case 4:
      return 18;
    case 5:
      return 15;
    case 6:
      return 3;
    case 7:
      return 2;
    case 8:
      return 1;
    case 9:
      return 0;
    case 10:
      return 44;
    default:
      return 0;
  }
}

int _relayDefaultPulseMs(int id) {
  switch (id) {
    case 1:
      return 350;
    case 4:
      return 250;
    case 9:
      return 4000;
    case 10:
      return 1000;
    default:
      return 0;
  }
}

bool _relayDefaultEnabled(int id) => id >= 1 && id <= 10;

String relayDisplayName(int relayId, {String? configuredName}) {
  final trimmed = configuredName?.trim();
  if (relayId >= 1 && relayId <= 8) {
    return 'PLUG$relayId';
  }
  if (trimmed != null && trimmed.isNotEmpty) {
    return trimmed;
  }
  return _relayDefaultName(relayId);
}

bool isPlugRelay(int relayId) => relayId >= 1 && relayId <= 8;
bool isPulseRelay(int relayId) => relayId == 9 || relayId == 10;

List<Map<dynamic, dynamic>> _relayEntries(dynamic relaysValue) {
  final entries = <Map<dynamic, dynamic>>[];

  if (relaysValue is List) {
    for (var i = 0; i < relaysValue.length; i++) {
      final item = relaysValue[i];
      if (item is Map) {
        entries.add(Map<dynamic, dynamic>.from(item)..['__key'] = i + 1);
      }
    }
  } else if (relaysValue is Map) {
    for (final entry in relaysValue.entries) {
      final value = entry.value;
      if (value is Map) {
        entries.add(Map<dynamic, dynamic>.from(value)..['__key'] = entry.key);
      }
    }
  }

  return entries;
}

List<RelayStatus> _normalizeRelayStatuses(dynamic relaysValue) {
  final byId = <int, RelayStatus>{};
  final entries = _relayEntries(relaysValue);

  for (final entry in entries) {
    final id = _parseRelayId(
      entry['id'] ?? entry['relayId'] ?? entry['__key'],
      0,
    );
    if (id < 1 || id > kMaxRelaySlots) {
      continue;
    }

    byId[id] = RelayStatus(
      id: id,
      isOn: _readBoolValue(entry['state'] ?? entry['isOn'], false),
      lastCommand: _readStringValue(entry['lastCommand'], 'OFF'),
    );
  }

  return List<RelayStatus>.generate(
    kMaxRelaySlots,
    (index) => byId[index + 1] ?? RelayStatus.placeholder(index + 1),
  );
}

List<Relay> _normalizeRelays(dynamic relaysValue, {dynamic statusRelays}) {
  final slots = List<Relay>.generate(
    kMaxRelaySlots,
    (index) => Relay.placeholder(index + 1),
  );
  final entries = _relayEntries(relaysValue);
  final used = <int>{};
  var fallbackId = 1;
  final statusMap = {
    for (final status in _normalizeRelayStatuses(statusRelays))
      status.id: status,
  };

  for (final entry in entries) {
    var id = _parseRelayId(
      entry['id'] ?? entry['relayId'] ?? entry['__key'],
      fallbackId,
    );
    if (id < 1 || id > kMaxRelaySlots || used.contains(id)) {
      while (fallbackId <= kMaxRelaySlots && used.contains(fallbackId)) {
        fallbackId++;
      }
      id = fallbackId;
    }

    if (id < 1 || id > kMaxRelaySlots) {
      continue;
    }

    used.add(id);
    if (id >= fallbackId) {
      fallbackId = id + 1;
    }

    final fallback = Relay.placeholder(id);
    final rawPinValue = entry['pin'];
    final pin = resolveRelayPin(
      rawPinValue == null ? null : _readIntValue(rawPinValue, fallback.pin),
      fallback.pin,
    );
    final pulseMs = _readIntValue(entry['pulseMs'], fallback.pulseDurationMs);
    final pulseDurationMs = _readIntValue(entry['pulseDurationMs'], pulseMs);
    final relay = fallback.copyWith(
      id: id,
      name: _readStringValue(entry['name'], fallback.name),
      pin: pin,
      activeLow: _readBoolValue(entry['activeLow'], fallback.activeLow),
      isOn: _readBoolValue(entry['state'] ?? entry['isOn'], fallback.isOn),
      isPulse: _readBoolValue(entry['isPulse'], fallback.isPulse),
      pulseDurationMs: pulseDurationMs,
      enabled: _readBoolValue(entry['enabled'], fallback.enabled),
      lastCommandTime: DateTime.now(),
    );

    final statusIsOn = statusMap[id]?.isOn ?? relay.isOn;
    final stateChanged = statusIsOn != relay.isOn;
    slots[id - 1] = relay.copyWith(
      isOn: statusIsOn,
      lastCommandTime: stateChanged ? DateTime.now() : relay.lastCommandTime,
    );

    if (slots[id - 1].pulseDurationMs == 0 && pulseMs > 0) {
      slots[id - 1] = slots[id - 1].copyWith(pulseDurationMs: pulseMs);
    }
  }

  return slots;
}

@HiveType(typeId: 0)
class Device {
  @HiveField(0)
  String deviceId;

  @HiveField(1)
  String deviceName;

  @HiveField(2)
  String roomId;

  @HiveField(3)
  String roomCode;

  @HiveField(4)
  String localIp;

  @HiveField(5)
  bool isOnline;

  @HiveField(6)
  bool ethernetPlugged;

  @HiveField(7)
  bool internetAvailable;

  @HiveField(8)
  bool firebaseReady;

  @HiveField(9)
  DateTime lastSeen;

  @HiveField(10)
  List<Relay> relays;

  Device({
    required this.deviceId,
    required this.deviceName,
    required this.roomId,
    required this.roomCode,
    this.localIp = '',
    this.isOnline = false,
    this.ethernetPlugged = false,
    this.internetAvailable = false,
    this.firebaseReady = false,
    required this.lastSeen,
    this.relays = const [],
  });

  Device copyWith({
    String? deviceId,
    String? deviceName,
    String? roomId,
    String? roomCode,
    String? localIp,
    bool? isOnline,
    bool? ethernetPlugged,
    bool? internetAvailable,
    bool? firebaseReady,
    DateTime? lastSeen,
    List<Relay>? relays,
  }) {
    return Device(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      roomId: roomId ?? this.roomId,
      roomCode: roomCode ?? this.roomCode,
      localIp: localIp ?? this.localIp,
      isOnline: isOnline ?? this.isOnline,
      ethernetPlugged: ethernetPlugged ?? this.ethernetPlugged,
      internetAvailable: internetAvailable ?? this.internetAvailable,
      firebaseReady: firebaseReady ?? this.firebaseReady,
      lastSeen: lastSeen ?? this.lastSeen,
      relays: relays ?? this.relays,
    );
  }

  static bool isHeartbeatFresh(
    int heartbeatAt, {
    int staleAfterMs = kHeartbeatFreshnessMs,
  }) {
    if (heartbeatAt <= 0) return false;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return (nowMs - heartbeatAt).abs() < staleAfterMs;
  }

  static List<Relay> relaysFromConfig(
    dynamic configRelays, {
    dynamic statusRelays,
  }) {
    return _normalizeRelays(configRelays, statusRelays: statusRelays);
  }

  static List<Relay> applyStatusToRelays(
    List<Relay> relays,
    List<RelayStatus> relayStates,
  ) {
    final statusById = {for (final status in relayStates) status.id: status};
    return relays.map((relay) {
      final status = statusById[relay.id];
      final newIsOn = status?.isOn ?? relay.isOn;
      final stateChanged = newIsOn != relay.isOn;
      return relay.copyWith(
        isOn: newIsOn,
        lastCommandTime: stateChanged ? DateTime.now() : relay.lastCommandTime,
      );
    }).toList();
  }
}

@HiveType(typeId: 1)
class Relay {
  @HiveField(0)
  int id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int pin;

  @HiveField(3)
  bool activeLow;

  @HiveField(4)
  bool isOn;

  @HiveField(5)
  bool isPulse;

  @HiveField(6)
  int pulseDurationMs;

  @HiveField(7)
  bool enabled;

  @HiveField(8)
  DateTime lastCommandTime;

  Relay({
    required this.id,
    required this.name,
    required this.pin,
    required this.activeLow,
    this.isOn = false,
    this.isPulse = false,
    this.pulseDurationMs = 0,
    this.enabled = true,
    required this.lastCommandTime,
  });

  factory Relay.placeholder(int id) => Relay(
    id: id,
    name: _relayDefaultName(id),
    pin: _relayDefaultPin(id),
    activeLow: true,
    isOn: false,
    isPulse: id == 9 || id == 10,
    pulseDurationMs: _relayDefaultPulseMs(id),
    enabled: _relayDefaultEnabled(id),
    lastCommandTime: DateTime.fromMillisecondsSinceEpoch(0),
  );

  Relay copyWith({
    int? id,
    String? name,
    int? pin,
    bool? activeLow,
    bool? isOn,
    bool? isPulse,
    int? pulseDurationMs,
    bool? enabled,
    DateTime? lastCommandTime,
  }) {
    return Relay(
      id: id ?? this.id,
      name: name ?? this.name,
      pin: pin ?? this.pin,
      activeLow: activeLow ?? this.activeLow,
      isOn: isOn ?? this.isOn,
      isPulse: isPulse ?? this.isPulse,
      pulseDurationMs: pulseDurationMs ?? this.pulseDurationMs,
      enabled: enabled ?? this.enabled,
      lastCommandTime: lastCommandTime ?? this.lastCommandTime,
    );
  }
}

class DeviceStatus {
  final String deviceId;
  final bool isOnline;
  final bool ethernetPlugged;
  final bool internetAvailable;
  final bool firebaseReady;
  final String localIp;
  final List<RelayStatus> relayStates;
  final DateTime timestamp;

  // Diagnostic fields from the firmware heartbeat
  final bool ethernetLinked;
  final bool ethernetGotIp;
  final bool internetOk;
  final bool firebaseAuthenticated;
  final int heartbeatAt;
  final int lastSeenAt;
  final int uptimeMs;
  final String deviceName;

  DeviceStatus({
    required this.deviceId,
    this.isOnline = false,
    this.ethernetPlugged = false,
    this.internetAvailable = false,
    this.firebaseReady = false,
    this.localIp = '',
    this.relayStates = const [],
    required this.timestamp,
    this.ethernetLinked = false,
    this.ethernetGotIp = false,
    this.internetOk = false,
    this.firebaseAuthenticated = false,
    this.heartbeatAt = 0,
    this.lastSeenAt = 0,
    this.uptimeMs = 0,
    this.deviceName = '',
  });

  factory DeviceStatus.fromJson(Map<dynamic, dynamic> json) {
    final relayList = _normalizeRelayStatuses(json['relays']);
    final heartbeatValue = json['heartbeatAt'] ?? json['lastSeenAt'] ?? 0;
    final heartbeatMs = heartbeatValue is num ? heartbeatValue.toInt() : 0;
    final hasFreshHeartbeat = Device.isHeartbeatFresh(heartbeatMs);
    final ethernetConnected = _readBoolValue(
      json['ethernetLinked'] ?? json['ethernetPlugged'],
      false,
    );
    final internetReachable = _readBoolValue(
      json['internetOk'] ?? json['internetAvailable'],
      false,
    );
    final firebaseConnected = _readBoolValue(
      json['firebaseAuthenticated'] ?? json['firebaseReady'],
      false,
    );
    final isOnlineComputed =
        hasFreshHeartbeat &&
        ethernetConnected &&
        internetReachable &&
        firebaseConnected;

    return DeviceStatus(
      deviceId: json['deviceId'] ?? '',
      isOnline: isOnlineComputed,
      ethernetPlugged:
          json['ethernetLinked'] ?? json['ethernetPlugged'] ?? false,
      internetAvailable:
          json['internetOk'] ?? json['internetAvailable'] ?? false,
      firebaseReady:
          json['firebaseAuthenticated'] ?? json['firebaseReady'] ?? false,
      localIp:
          json['localIp'] ??
          (json['ethernetGotIp'] == true ? 'DHCP Acquired' : ''),
      relayStates: relayList,
      timestamp: DateTime.now(),
      ethernetLinked: json['ethernetLinked'] ?? false,
      ethernetGotIp: json['ethernetGotIp'] ?? false,
      internetOk: json['internetOk'] ?? false,
      firebaseAuthenticated: json['firebaseAuthenticated'] ?? false,
      heartbeatAt: heartbeatMs,
      lastSeenAt:
          json['lastSeenAt'] is num
              ? (json['lastSeenAt'] as num).toInt()
              : heartbeatMs,
      uptimeMs: json['uptimeMs'] is num ? (json['uptimeMs'] as num).toInt() : 0,
      deviceName: json['deviceName'] ?? '',
    );
  }
}

class RelayStatus {
  final int id;
  final bool isOn;
  final String lastCommand;

  RelayStatus({required this.id, required this.isOn, this.lastCommand = 'OFF'});

  factory RelayStatus.placeholder(int id) => RelayStatus(id: id, isOn: false);

  factory RelayStatus.fromJson(Map<dynamic, dynamic> json) {
    return RelayStatus(
      id: json['id'] ?? 0,
      isOn: json['state'] ?? json['isOn'] ?? false,
      lastCommand: json['lastCommand'] ?? 'OFF',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'isOn': isOn,
    'lastCommand': lastCommand,
  };
}

class DeviceLog {
  final String deviceId;
  final String message;
  final DateTime timestamp;
  final String level;

  DeviceLog({
    required this.deviceId,
    required this.message,
    required this.timestamp,
    this.level = 'INFO',
  });

  factory DeviceLog.fromJson(Map<dynamic, dynamic> json) {
    return DeviceLog(
      deviceId: json['deviceId'] ?? '',
      message: json['message'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] ?? 0),
      level: json['level'] ?? 'INFO',
    );
  }
}
