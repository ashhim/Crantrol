import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/device.dart';
import '../services/firebase_service.dart';
import 'package:logger/logger.dart';

class DeviceProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final Logger _logger = Logger();

  Device? _selectedDevice;
  List<Device> _devices = [];
  DeviceStatus? _deviceStatus;
  List<DeviceLog> _deviceLogs = [];
  bool _isLoading = false;
  String? _error;
  Timer? _heartbeatTimer;
  StreamSubscription<DatabaseEvent>? _statusSubscription;
  StreamSubscription<DatabaseEvent>? _logsSubscription;
  StreamSubscription<DatabaseEvent>? _timerSubscription;
  String? _selectedDeviceId;
  Map<String, dynamic>? _selectedDeviceConfig;
  final Map<int, bool> _pendingRelayTargets = {};
  final Map<int, String> _pendingRelayActions = {};
  final Map<int, Timer> _pendingRelayTimers = {};

  // ── Timer sync state ───────────────────────────────────────────────────
  final Map<int, Map<String, dynamic>> _relayTimers = {};

  // ── Online detection state ─────────────────────────────────────────────
  int _lastStatusEventMs = 0;

  Device? get selectedDevice => _selectedDevice;
  Map<String, dynamic>? get selectedDeviceConfig => _selectedDeviceConfig;
  List<Device> get devices => _devices;
  DeviceStatus? get deviceStatus => _deviceStatus;
  List<DeviceLog> get deviceLogs => _deviceLogs;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Timer data for a relay, synced via Firebase.
  Map<String, dynamic>? relayTimerData(int relayId) => _relayTimers[relayId];

  /// Robust online check: true if we received a Firebase status event
  /// recently OR the heartbeat timestamp is fresh.
  bool get isDeviceOnline => _isDeviceOnline();

  bool _isDeviceOnline() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final status = _deviceStatus;
    if (status == null) {
      return false;
    }

    final hasFreshHeartbeat = Device.isHeartbeatFresh(
      status.heartbeatAt > 0 ? status.heartbeatAt : status.lastSeenAt,
    );
    final hasFreshStatusEvent =
        _lastStatusEventMs > 0 &&
        (now - _lastStatusEventMs).abs() < kHeartbeatFreshnessMs;
    final healthyConnectivity =
        status.ethernetPlugged &&
        status.internetAvailable &&
        status.firebaseReady;

    if (!healthyConnectivity) {
      return false;
    }

    if (hasFreshStatusEvent || hasFreshHeartbeat) {
      return true;
    }

    return false;
  }

  bool isRelayCommandPending(int relayId) =>
      _pendingRelayTargets.containsKey(relayId);

  bool? relayPendingTargetState(int relayId) => _pendingRelayTargets[relayId];

  String? relayPendingAction(int relayId) => _pendingRelayActions[relayId];

  void _clearPendingRelay(int relayId) {
    _pendingRelayTimers[relayId]?.cancel();
    _pendingRelayTimers.remove(relayId);
    _pendingRelayTargets.remove(relayId);
    _pendingRelayActions.remove(relayId);
  }

  void _setPendingRelay(
    int relayId, {
    required bool targetState,
    required String action,
    int timeoutMs = 2500,
  }) {
    _pendingRelayTargets[relayId] = targetState;
    _pendingRelayActions[relayId] = action;
    _pendingRelayTimers[relayId]?.cancel();
    _pendingRelayTimers[relayId] = Timer(Duration(milliseconds: timeoutMs), () {
      if (action == 'PULSE') {
        _applyOptimisticRelayState(relayId, false);
      }
      _clearPendingRelay(relayId);
      notifyListeners();
    });
    notifyListeners();
  }

  void _applyOptimisticRelayState(int relayId, bool targetState) {
    if (_selectedDevice == null) {
      return;
    }

    final updatedRelays =
        _selectedDevice!.relays.map((relay) {
          if (relay.id != relayId) {
            return relay;
          }
          return relay.copyWith(
            isOn: targetState,
            lastCommandTime: DateTime.now(),
          );
        }).toList();

    _selectedDevice = _selectedDevice!.copyWith(relays: updatedRelays);

    final index = _devices.indexWhere(
      (device) => device.deviceId == _selectedDeviceId,
    );
    if (index != -1) {
      _devices[index] = _selectedDevice!;
    }
    notifyListeners();
  }

  void _cancelDeviceSubscriptions() {
    _statusSubscription?.cancel();
    _statusSubscription = null;
    _logsSubscription?.cancel();
    _logsSubscription = null;
    _timerSubscription?.cancel();
    _timerSubscription = null;
  }

  Map<String, dynamic> _mapSnapshot(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  Device _buildDeviceFromSnapshot(
    String deviceId,
    Map<String, dynamic> config,
    Map<String, dynamic>? status,
  ) {
    final statusModel = status != null ? DeviceStatus.fromJson(status) : null;
    final heartbeatAt = statusModel?.heartbeatAt ?? 0;
    final lastSeenAt = statusModel?.lastSeenAt ?? heartbeatAt;
    final statusRelays = <Map<String, dynamic>>[
      for (final relayState
          in statusModel?.relayStates ?? const <RelayStatus>[])
        {
          'id': relayState.id,
          'state': relayState.isOn,
          'lastCommand': relayState.lastCommand,
        },
    ];
    final normalizedRelays = Device.relaysFromConfig(
      config['relays'],
      statusRelays: statusRelays,
    );

    return Device(
      deviceId: deviceId,
      deviceName: config['deviceName'] ?? 'CRANTROL Device',
      roomId: config['roomId'] ?? '',
      roomCode: config['roomCode'] ?? '',
      localIp: statusModel?.localIp ?? '',
      isOnline: statusModel?.isOnline ?? Device.isHeartbeatFresh(heartbeatAt),
      ethernetPlugged: statusModel?.ethernetPlugged ?? false,
      internetAvailable: statusModel?.internetAvailable ?? false,
      firebaseReady: statusModel?.firebaseReady ?? false,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(
        lastSeenAt > 0 ? lastSeenAt : DateTime.now().millisecondsSinceEpoch,
      ),
      relays: normalizedRelays,
    );
  }

  void _syncSelectedDeviceFromStatus(Map<String, dynamic> status) {
    // Record when we received this event for online detection
    _lastStatusEventMs = DateTime.now().millisecondsSinceEpoch;

    _deviceStatus = DeviceStatus.fromJson(status);
    if (_selectedDevice != null) {
      final relays = Device.applyStatusToRelays(
        _selectedDevice!.relays,
        _deviceStatus!.relayStates,
      );

      // Use robust online check (considers event recency + heartbeat)
      final isOnline = _isDeviceOnline();

      _selectedDevice = _selectedDevice!.copyWith(
        isOnline: isOnline,
        ethernetPlugged: _deviceStatus!.ethernetPlugged,
        internetAvailable: _deviceStatus!.internetAvailable,
        firebaseReady: _deviceStatus!.firebaseReady,
        localIp: _deviceStatus!.localIp,
        lastSeen: DateTime.fromMillisecondsSinceEpoch(
          _deviceStatus!.lastSeenAt > 0
              ? _deviceStatus!.lastSeenAt
              : (_deviceStatus!.heartbeatAt > 0
                  ? _deviceStatus!.heartbeatAt
                  : DateTime.now().millisecondsSinceEpoch),
        ),
        relays: relays,
      );

      for (final entry in _pendingRelayTargets.entries.toList()) {
        final relayId = entry.key;
        final desiredState = entry.value;
        final relay = relays.firstWhere(
          (item) => item.id == relayId,
          orElse: () => Relay.placeholder(relayId),
        );
        if (relay.isOn == desiredState) {
          _clearPendingRelay(relayId);
        }
      }
      if (_selectedDeviceId != null) {
        final index = _devices.indexWhere(
          (device) => device.deviceId == _selectedDeviceId,
        );
        if (index != -1) {
          _devices[index] = _selectedDevice!;
        }
      }
    }
  }

  Future<void> loadDevices() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final config = await _firebaseService.getDeviceConfig('device_001');
      final status = await _firebaseService.getDeviceStatus('device_001');
      final configData = _mapSnapshot(
        config ??
            {
              'deviceName': 'CRANTROL Device',
              'roomId': 'room_001',
              'roomCode': 'ROOM001',
              'relays': <String, dynamic>{},
            },
      );
      final statusData = status != null ? _mapSnapshot(status) : null;

      _devices = [
        _buildDeviceFromSnapshot('device_001', configData, statusData),
      ];
      _error = null;
    } catch (e) {
      _error = e.toString();
      _logger.e('Error loading devices: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectDevice(String deviceId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _cancelDeviceSubscriptions();
      _selectedDeviceId = deviceId;

      final config = await _firebaseService.getDeviceConfig(deviceId);
      final status = await _firebaseService.getDeviceStatus(deviceId);

      if (config != null) {
        _selectedDeviceConfig = _mapSnapshot(config);
        final statusData = status != null ? _mapSnapshot(status) : null;
        _deviceStatus =
            statusData != null ? DeviceStatus.fromJson(statusData) : null;
        _selectedDevice = _buildDeviceFromSnapshot(
          deviceId,
          _selectedDeviceConfig!,
          statusData,
        );
        if (statusData != null) {
          _syncSelectedDeviceFromStatus(statusData);
        }

        // Setup periodic heartbeat timer — uses robust online check
        _heartbeatTimer?.cancel();
        _heartbeatTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
          if (_selectedDevice != null) {
            final online = _isDeviceOnline();
            if (_selectedDevice!.isOnline != online) {
              _selectedDevice = _selectedDevice!.copyWith(isOnline: online);
              notifyListeners();
            }
          }
        });

        // Watch for status updates
        _subscribeToDeviceStatus(deviceId);
        _subscribeToDeviceLogs(deviceId);
        _subscribeToRelayTimers(deviceId);
      } else {
        _selectedDevice = null;
        _deviceStatus = null;
        _selectedDeviceConfig = null;
        _error = 'Device not found';
      }
    } catch (e) {
      _error = e.toString();
      _logger.e('Error selecting device: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _subscribeToDeviceStatus(String deviceId) {
    _statusSubscription?.cancel();
    _statusSubscription = _firebaseService
        .watchDeviceStatus(deviceId)
        .listen(
          (event) {
            if (event.snapshot.exists) {
              final json = _mapSnapshot(event.snapshot.value);
              _syncSelectedDeviceFromStatus(json);
              _logger.d('Device status updated: online=${_isDeviceOnline()}');
              notifyListeners();
            }
          },
          onError: (error) {
            _logger.e('Error watching device status: $error');
          },
        );
  }

  void _subscribeToDeviceLogs(String deviceId) {
    _logsSubscription?.cancel();
    _logsSubscription = _firebaseService
        .watchDeviceLogs(deviceId)
        .listen(
          (event) {
            if (event.snapshot.exists) {
              final logsValue = event.snapshot.value;
              if (logsValue is Map) {
                final logsMap = Map<dynamic, dynamic>.from(logsValue);
                _deviceLogs =
                    logsMap.entries
                        .map(
                          (e) => DeviceLog(
                            deviceId: deviceId,
                            message: e.value['message'] ?? '',
                            timestamp: DateTime.fromMillisecondsSinceEpoch(
                              e.value['timestamp'] ?? 0,
                            ),
                          ),
                        )
                        .toList()
                      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
                notifyListeners();
              }
            }
          },
          onError: (error) {
            _logger.e('Error watching device logs: $error');
          },
        );
  }

  // ── Timer subscription ─────────────────────────────────────────────────
  void _subscribeToRelayTimers(String deviceId) {
    _timerSubscription?.cancel();
    _timerSubscription = _firebaseService
        .watchRelayTimers(deviceId)
        .listen(
          (event) {
            if (event.snapshot.exists && event.snapshot.value is Map) {
              final timersMap = Map<String, dynamic>.from(
                event.snapshot.value as Map,
              );
              for (final entry in timersMap.entries) {
                // Keys are like "relay1", "relay2", ...
                final key = entry.key;
                if (key.startsWith('relay') && entry.value is Map) {
                  final relayId = int.tryParse(key.substring(5));
                  if (relayId != null &&
                      relayId >= 1 &&
                      relayId <= kMaxRelaySlots) {
                    _relayTimers[relayId] = Map<String, dynamic>.from(
                      entry.value as Map,
                    );
                  }
                }
              }
              notifyListeners();
            }
          },
          onError: (error) {
            _logger.e('Error watching relay timers: $error');
          },
        );
  }

  // ── Timer save helpers ─────────────────────────────────────────────────
  void _saveTimerStart(String deviceId, int relayId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Optimistic local update
    _relayTimers[relayId] = {
      'startedAt': now,
      'stoppedAt': null,
      'lastElapsedMs': null,
    };
    // Async Firebase write (only 1 write)
    _firebaseService.saveRelayTimerStart(deviceId, relayId);
  }

  void _saveTimerStop(String deviceId, int relayId) {
    final startedAt = _relayTimers[relayId]?['startedAt'] as int? ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = startedAt > 0 ? now - startedAt : 0;
    // Optimistic local update
    _relayTimers[relayId] = {
      'startedAt': startedAt,
      'stoppedAt': now,
      'lastElapsedMs': elapsed,
    };
    // Async Firebase write (only 1 write)
    _firebaseService.saveRelayTimerStop(deviceId, relayId, elapsed);
  }

  Future<void> setRelayState(String deviceId, int relayId, bool isOn) async {
    final relay = _selectedDevice?.relays.firstWhere(
      (item) => item.id == relayId,
      orElse: () => Relay.placeholder(relayId),
    );

    if (relay != null && relay.isPulse && isOn) {
      await pulseRelay(deviceId, relayId);
      return;
    }

    if (relay != null && relay.isPulse && !isOn) {
      return;
    }

    _setPendingRelay(relayId, targetState: isOn, action: isOn ? 'ON' : 'OFF');
    _applyOptimisticRelayState(relayId, isOn);

    // Save timer data (1 write per ON, 1 write per OFF)
    if (isOn) {
      _saveTimerStart(deviceId, relayId);
    } else {
      _saveTimerStop(deviceId, relayId);
    }

    try {
      await _firebaseService.setRelayState(deviceId, relayId, isOn);
      _logger.d('Relay $relayId set to $isOn');
    } catch (e) {
      _clearPendingRelay(relayId);
      _error = e.toString();
      _logger.e('Error setting relay state: $e');
      notifyListeners();
    }
  }

  Future<void> pulseRelay(String deviceId, int relayId) async {
    final relay = _selectedDevice?.relays.firstWhere(
      (item) => item.id == relayId,
      orElse: () => Relay.placeholder(relayId),
    );
    final pulseDuration = relay?.pulseDurationMs ?? 1000;
    final timeoutMs = pulseDuration > 0 ? pulseDuration + 250 : 1500;

    _setPendingRelay(
      relayId,
      targetState: true,
      action: 'PULSE',
      timeoutMs: timeoutMs,
    );
    _applyOptimisticRelayState(relayId, true);
    try {
      await _firebaseService.pulseRelay(deviceId, relayId);
      _logger.d('Relay $relayId pulsed');
    } catch (e) {
      _clearPendingRelay(relayId);
      _error = e.toString();
      _logger.e('Error pulsing relay: $e');
      notifyListeners();
    }
  }

  /// Direct relay state set — bypasses isPulse redirect.
  /// Used for manual hold controls (PC/SP buttons).
  Future<void> setRelayStateDirect(
    String deviceId,
    int relayId,
    bool isOn,
  ) async {
    _setPendingRelay(relayId, targetState: isOn, action: isOn ? 'ON' : 'OFF');
    _applyOptimisticRelayState(relayId, isOn);

    // Save timer data (1 write per ON, 1 write per OFF)
    if (isOn) {
      _saveTimerStart(deviceId, relayId);
    } else {
      _saveTimerStop(deviceId, relayId);
    }

    try {
      await _firebaseService.setRelayState(deviceId, relayId, isOn);
      _logger.d('Relay $relayId direct-set to $isOn');
    } catch (e) {
      _clearPendingRelay(relayId);
      _error = e.toString();
      _logger.e('Error direct-setting relay state: $e');
      notifyListeners();
    }
  }

  /// Send buzzer command for ALERT hold-beep.
  Future<void> setBuzzerState(String deviceId, bool isOn) async {
    try {
      await _firebaseService.setBuzzerState(deviceId, isOn);
    } catch (e) {
      _logger.e('Error setting buzzer state: $e');
    }
  }

  /// Send hardware system command (e.g. RESTART for RESET button).
  Future<void> sendSystemCommand(String deviceId, String command) async {
    try {
      await _firebaseService.sendSystemCommand(deviceId, command);
    } catch (e) {
      _logger.e('Error sending system command: $e');
    }
  }

  Future<void> runAutoPowerSequence(String deviceId) async {
    final device = _selectedDevice;
    if (device == null) {
      return;
    }

    final plugRelays = device.relays.where(
      (relay) => isPlugRelay(relay.id) && relay.enabled,
    );

    for (final relay in plugRelays) {
      await setRelayState(deviceId, relay.id, false);
    }

    await Future<void>.delayed(const Duration(seconds: 2));
    await setRelayState(deviceId, 9, true);
  }

  Future<void> toggleSOS(String deviceId) async {
    final device = _selectedDevice;
    if (device == null) {
      return;
    }

    final plugs =
        device.relays
            .where((relay) => isPlugRelay(relay.id) && relay.enabled)
            .toList();
    if (plugs.isEmpty) {
      return;
    }

    for (final relay in plugs) {
      await setRelayState(deviceId, relay.id, false);
    }
  }

  Future<void> updateDeviceConfig(
    String deviceId,
    Map<String, dynamic> config,
  ) async {
    try {
      await _firebaseService.updateDeviceConfig(deviceId, config);
      _selectedDeviceConfig = _mapSnapshot(config);
      if (_selectedDeviceId == deviceId && _selectedDeviceConfig != null) {
        final status = await _firebaseService.getDeviceStatus(deviceId);
        final statusData = status != null ? _mapSnapshot(status) : null;
        _selectedDevice = _buildDeviceFromSnapshot(
          deviceId,
          _selectedDeviceConfig!,
          statusData,
        );
        if (statusData != null) {
          _syncSelectedDeviceFromStatus(statusData);
        }
        final index = _devices.indexWhere(
          (device) => device.deviceId == deviceId,
        );
        if (index != -1) {
          _devices[index] = _selectedDevice!;
        }
      }
      _logger.d('Device config updated');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _logger.e('Error updating device config: $e');
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    for (final timer in _pendingRelayTimers.values) {
      timer.cancel();
    }
    _pendingRelayTimers.clear();
    _cancelDeviceSubscriptions();
    super.dispose();
  }
}
