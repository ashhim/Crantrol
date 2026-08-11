// ==========================================================================
// CRANTROL Background Service Controller
//
// Keeps a lightweight Android foreground service alive so the persistent
// status notification (NotificationService) stays accurate even when the
// app UI is backgrounded or fully closed. The service isolate holds live
// Firebase RTDB stream subscriptions (event-driven, not polling) plus a
// 1-second local ticker that only recomputes text from timestamps already
// in memory — it never itself writes to Firebase or polls it on a timer.
// ==========================================================================

import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'firebase_options.dart';
import 'firebase_service.dart';
import 'notification_service.dart';
import 'power_sequence_service.dart';

const int _kHeartbeatFreshnessMs = 15000;

class BackgroundServiceController {
  static Future<void> initializeService() async {
    await NotificationService.initialize();

    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onServiceStart,
        autoStart: false,
        // No signed-in session is guaranteed to exist at device boot, so
        // don't auto-launch then — start explicitly once the user is
        // authenticated (see ensureStarted()).
        autoStartOnBoot: false,
        isForegroundMode: true,
        notificationChannelId: kNotificationChannelId,
        initialNotificationTitle: 'CRANTROL',
        initialNotificationContent: 'Starting status monitor…',
        foregroundServiceNotificationId: kStatusNotificationId,
        foregroundServiceTypes: const [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(autoStart: false),
    );
  }

  /// Starts the service if it isn't already running. Safe to call
  /// repeatedly (e.g. every time the user signs in).
  static Future<void> ensureStarted() async {
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
    }
  }

  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('stopService');
    }
  }
}

bool _readBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return false;
}

int _readInt(dynamic value) {
  if (value is num) return value.toInt();
  return 0;
}

@pragma('vm:entry-point')
Future<void> _onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  await NotificationService.initialize();

  if (service is AndroidServiceInstance) {
    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }

  const deviceId = kDefaultDeviceId;
  final statusRef = FirebaseDatabase.instance.ref('devices/$deviceId/status');
  final pcTimerRef = FirebaseDatabase.instance.ref(
    'devices/$deviceId/timers/relay${PowerSequenceService.kRelayPcMain}',
  );
  final schedulesRef = FirebaseDatabase.instance.ref(
    'devices/$deviceId/schedules',
  );

  Map<dynamic, dynamic>? lastStatus;
  Map<dynamic, dynamic>? lastTimer;
  Map<dynamic, dynamic>? lastSchedules;
  final firingSchedules = <String>{};

  Future<void> refresh() async {
    // Authoritative PC state — the firmware's debounced GPIO45/PLED reading,
    // never Relay 1.
    final pcOn = _readBool(lastStatus?['pcActualOn']);

    final pcTransition =
        lastStatus?['pcTransition'] is Map
            ? lastStatus!['pcTransition'] as Map
            : const {};
    final transitioning = _readBool(pcTransition['active']);
    final transitionFailed = _readBool(pcTransition['failed']);

    final heartbeatAt = _readInt(
      lastStatus?['heartbeatAt'] ?? lastStatus?['lastSeenAt'],
    );
    final online =
        heartbeatAt > 0 &&
        (DateTime.now().millisecondsSinceEpoch - heartbeatAt).abs() <
            _kHeartbeatFreshnessMs;

    final ethOk = _readBool(lastStatus?['ethernetLinked']);
    final netOk = _readBool(lastStatus?['internetOk']);
    final fbOk = _readBool(lastStatus?['firebaseAuthenticated']);
    final networkSummary =
        'Eth ${ethOk ? "OK" : "--"} · Net ${netOk ? "OK" : "--"} · '
        'FB ${fbOk ? "OK" : "--"}';

    final startedAt = _readInt(lastTimer?['startedAt']);
    final lastElapsedMs = _readInt(lastTimer?['lastElapsedMs']);
    String uptimeText = '--:--:--';
    if (pcOn && startedAt > 0) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - startedAt;
      uptimeText = _fmtDuration(elapsed > 0 ? elapsed : 0);
    } else if (!pcOn && lastElapsedMs > 0) {
      uptimeText = _fmtDuration(lastElapsedMs);
    }

    await NotificationService.showStatusNotification(
      pcOn: pcOn,
      transitioning: transitioning,
      transitionFailed: transitionFailed,
      uptimeText: uptimeText,
      online: online,
      networkSummary: networkSummary,
    );
  }

  statusRef.onValue.listen((event) {
    final value = event.snapshot.value;
    lastStatus = value is Map ? value : null;
    refresh();
  });
  pcTimerRef.onValue.listen((event) {
    final value = event.snapshot.value;
    lastTimer = value is Map ? value : null;
    refresh();
  });
  schedulesRef.onValue.listen((event) {
    final value = event.snapshot.value;
    lastSchedules = value is Map ? value : null;
  });

  // Purely local — recomputes the uptime string from timestamps already
  // held in memory, and compares in-memory schedule timestamps against the
  // clock. No Firebase read happens on this tick; only a (rare) write when a
  // schedule is actually due, so scheduled actions still fire even if the
  // app UI is closed, as long as this foreground service is running.
  Timer.periodic(const Duration(seconds: 1), (_) {
    refresh();
    final schedules = lastSchedules;
    if (schedules == null || schedules.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final entry in schedules.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is! Map || firingSchedules.contains(key)) continue;
      final targetAt = value['targetAt'];
      if (targetAt is num && targetAt.toInt() <= now) {
        firingSchedules.add(key);
        _fireSchedule(deviceId, key, value).whenComplete(
          () => firingSchedules.remove(key),
        );
      }
    }
  });

  service.on('togglePc').listen((event) async {
    await NotificationService.runAutoFromNotification(deviceId);
  });
}

/// Executes a due schedule and clears it. Reuses the same primitives the
/// foreground app and the notification tap handler already use — no
/// separate command-writing logic to keep in sync.
Future<void> _fireSchedule(
  String deviceId,
  String key,
  Map<dynamic, dynamic> entry,
) async {
  final firebaseService = FirebaseService();
  // Clear first so a near-simultaneous foreground executor doesn't also
  // fire it — worst case on a tight race is one harmless duplicate command.
  await firebaseService.clearSchedule(deviceId, key);

  if (key == 'auto') {
    await NotificationService.runAutoFromNotification(deviceId);
    return;
  }
  if (!key.startsWith('relay')) return;
  final relayId = int.tryParse(key.substring(5));
  if (relayId == null) return;
  final turnOn = entry['action'] == 'ON';
  await firebaseService.setRelayState(deviceId, relayId, turnOn);
}

String _fmtDuration(int ms) {
  final d = Duration(milliseconds: ms);
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}
