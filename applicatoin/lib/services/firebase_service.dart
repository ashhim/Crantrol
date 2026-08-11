import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app_environment.dart';
import 'firebase_options.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();

  FirebaseService._internal();

  factory FirebaseService() {
    return _instance;
  }

  Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      throw Exception('Firebase initialization failed: $e');
    }
  }

  // Dynamic getters to resolve singletons without late initializers
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseDatabase get _database {
    final dbUrl = Firebase.app().options.databaseURL;
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: (dbUrl != null && dbUrl.isNotEmpty)
          ? dbUrl
          : AppEnvironment.firebaseDatabaseUrl,
    );
  }

  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (e) {
      return null;
    }
  }
  bool get isAuthenticated {
    try {
      return currentUser != null;
    } catch (e) {
      return false;
    }
  }
  String? get uid {
    try {
      return currentUser?.uid;
    } catch (e) {
      return null;
    }
  }

  Stream<User?> get authStateChanges {
    try {
      return _auth.authStateChanges();
    } catch (e) {
      return const Stream.empty();
    }
  }

  // Device operations
  Future<void> createDevice(
    String deviceId,
    Map<String, dynamic> deviceData,
  ) async {
    try {
      await _database.ref('devices/$deviceId/config').set(deviceData);
    } catch (e) {
      throw Exception('Failed to create device: $e');
    }
  }

  Future<Map<String, dynamic>?> getDeviceConfig(String deviceId) async {
    try {
      final path = 'devices/$deviceId/config';
      print('DEBUG [RTDB Read]: User UID: ${currentUser?.uid}, Email: ${currentUser?.email}');
      print('DEBUG [RTDB Read]: Database URL: ${Firebase.app().options.databaseURL ?? "Default URL"}');
      print('DEBUG [RTDB Read]: Requesting path: $path');
      final snapshot = await _database.ref(path).get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      print('DEBUG [RTDB Error]: Failed to get device config: $e');
      throw Exception('Failed to get device config: $e');
    }
  }

  Future<Map<String, dynamic>?> getDeviceStatus(String deviceId) async {
    try {
      final path = 'devices/$deviceId/status';
      print('DEBUG [RTDB Read]: User UID: ${currentUser?.uid}, Email: ${currentUser?.email}');
      print('DEBUG [RTDB Read]: Requesting path: $path');
      final snapshot = await _database.ref(path).get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      print('DEBUG [RTDB Error]: Failed to get device status: $e');
      throw Exception('Failed to get device status: $e');
    }
  }

  Stream<DatabaseEvent> watchDeviceStatus(String deviceId) {
    return _database.ref('devices/$deviceId/status').onValue;
  }

  Stream<DatabaseEvent> watchRelayStates(String deviceId) {
    return _database.ref('devices/$deviceId/status/relays').onValue;
  }

  // Relay commands
  Future<void> setRelayState(String deviceId, int relayId, bool isOn) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final command = isOn ? 'ON' : 'OFF';
      final revision = '${deviceId}_${timestamp}_$relayId';

      await _database.ref('devices/$deviceId/desired/relay$relayId').set({
        'command': command,
        'timestamp': timestamp,
        'revision': revision,
      });
    } catch (e) {
      throw Exception('Failed to set relay state: $e');
    }
  }

  Future<void> pulseRelay(String deviceId, int relayId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final revision = '${deviceId}_${timestamp}_${relayId}_pulse';

      await _database.ref('devices/$deviceId/desired/relay$relayId').set({
        'command': 'PULSE',
        'timestamp': timestamp,
        'revision': revision,
      });
    } catch (e) {
      throw Exception('Failed to pulse relay: $e');
    }
  }

  // Config operations
  Future<void> updateDeviceConfig(
    String deviceId,
    Map<String, dynamic> config,
  ) async {
    try {
      await _database.ref('devices/$deviceId/config').set(config);
    } catch (e) {
      throw Exception('Failed to update device config: $e');
    }
  }

  Future<void> updateRelayConfig(
    String deviceId,
    int relayId,
    Map<String, dynamic> relayConfig,
  ) async {
    try {
      await _database
          .ref('devices/$deviceId/config/relays/relay$relayId')
          .set(relayConfig);
    } catch (e) {
      throw Exception('Failed to update relay config: $e');
    }
  }

  // Logs
  Future<void> writeLogs(String deviceId, String message) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _database.ref('devices/$deviceId/logs').push().set({
        'message': message,
        'timestamp': timestamp,
      });
    } catch (e) {
      throw Exception('Failed to write logs: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getDeviceLogs(String deviceId) async {
    try {
      final snapshot = await _database.ref('devices/$deviceId/logs').get();
      if (snapshot.exists) {
        final logsData = snapshot.value as Map;
        return logsData.entries
            .map(
              (e) => {
                'id': e.key,
                ...Map<String, dynamic>.from(e.value as Map),
              },
            )
            .toList()
            .reversed
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to get device logs: $e');
    }
  }

  Stream<DatabaseEvent> watchDeviceLogs(String deviceId) {
    return _database.ref('devices/$deviceId/logs').onValue;
  }

  // Room operations
  Future<Map<String, dynamic>?> getRoomConfig(String roomId) async {
    try {
      final snapshot = await _database.ref('rooms/$roomId').get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get room config: $e');
    }
  }

  Future<void> updateRoomConfig(
    String roomId,
    Map<String, dynamic> config,
  ) async {
    try {
      await _database.ref('rooms/$roomId').update(config);
    } catch (e) {
      throw Exception('Failed to update room config: $e');
    }
  }

  // Utility
  Future<void> deleteDevice(String deviceId) async {
    try {
      await _database.ref('devices/$deviceId').remove();
    } catch (e) {
      throw Exception('Failed to delete device: $e');
    }
  }

  Future<User?> signIn(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  // ── Buzzer control (ALERT hold) ──────────────────────────────────────────
  Future<void> setBuzzerState(String deviceId, bool isOn) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final command = isOn ? 'ON' : 'OFF';
      final revision = '${deviceId}_${timestamp}_buzzer';

      await _database.ref('devices/$deviceId/desired/buzzer').set({
        'command': command,
        'timestamp': timestamp,
        'revision': revision,
      });
    } catch (e) {
      throw Exception('Failed to set buzzer state: $e');
    }
  }

  // ── System command (RESET = hardware restart) ───────────────────────────
  Future<void> sendSystemCommand(String deviceId, String command) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final revision = '${deviceId}_${timestamp}_system';

      await _database.ref('devices/$deviceId/desired/system').set({
        'command': command,
        'timestamp': timestamp,
        'revision': revision,
      });
    } catch (e) {
      throw Exception('Failed to send system command: $e');
    }
  }

  // ── Timer sync (relay ON/OFF timestamps for cross-device consistency) ──
  Future<void> saveRelayTimerStart(String deviceId, int relayId) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _database.ref('devices/$deviceId/timers/relay$relayId').set({
        'startedAt': now,
        'stoppedAt': null,
        'lastElapsedMs': null,
      });
    } catch (e) {
      // Non-critical — silent fail
    }
  }

  Future<void> saveRelayTimerStop(
      String deviceId, int relayId, int elapsedMs) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _database.ref('devices/$deviceId/timers/relay$relayId').update({
        'stoppedAt': now,
        'lastElapsedMs': elapsedMs,
      });
    } catch (e) {
      // Non-critical — silent fail
    }
  }

  Stream<DatabaseEvent> watchRelayTimers(String deviceId) {
    return _database.ref('devices/$deviceId/timers').onValue;
  }

  // ── PC transition state (AUTO sequence in progress) ─────────────────────
  // Written once at sequence start and once at sequence end (not polled),
  // so every logged-in device can render the orange "working" state while
  // any one device is running the AUTO ON/OFF sequence.
  Future<void> setPcTransition(
    String deviceId, {
    required bool active,
    String kind = '',
  }) async {
    try {
      await _database.ref('devices/$deviceId/status/pcTransition').set({
        'active': active,
        'kind': kind,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      // Non-critical — silent fail, UI falls back to relay-state-only colors
    }
  }

  // ── Scheduled actions (long-press scheduler) ─────────────────────────────
  // One write to set a schedule, one write to clear it when it fires or is
  // cancelled. No per-second writes — the countdown is computed locally by
  // every client from `targetAt`.
  Stream<DatabaseEvent> watchSchedules(String deviceId) {
    return _database.ref('devices/$deviceId/schedules').onValue;
  }

  Future<void> setSchedule(
    String deviceId,
    String key, {
    required DateTime targetAt,
    String? action,
  }) async {
    await _database.ref('devices/$deviceId/schedules/$key').set({
      'targetAt': targetAt.millisecondsSinceEpoch,
      if (action != null) 'action': action,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> clearSchedule(String deviceId, String key) async {
    try {
      await _database.ref('devices/$deviceId/schedules/$key').remove();
    } catch (e) {
      // Non-critical — a stale schedule node just gets overwritten next time
    }
  }

  // ── PC daily usage totals (Today / Week / Month) ─────────────────────────
  // One atomic increment per PC power-off event — never per second. Keyed
  // by local calendar day so Today/Week/Month can be summed client-side
  // from a small, bounded range read.
  Future<void> addPcUsage(String deviceId, String dayKey, int elapsedMs) async {
    try {
      await _database.ref('devices/$deviceId/usage/$dayKey').update({
        'totalMs': ServerValue.increment(elapsedMs),
        'sessions': ServerValue.increment(1),
      });
    } catch (e) {
      // Non-critical — historical totals are best-effort
    }
  }

  Stream<DatabaseEvent> watchUsage(String deviceId, {int lastDays = 31}) {
    return _database
        .ref('devices/$deviceId/usage')
        .orderByKey()
        .limitToLast(lastDays)
        .onValue;
  }
}
