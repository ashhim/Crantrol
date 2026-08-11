// ==========================================================================
// CRANTROL Notification Service
//
// Persistent status notification: shows PC state, PC uptime and network
// state, with an action button that runs the same AUTO ON/OFF sequence as
// the dashboard. Content is refreshed only in response to Firebase status
// events (via BackgroundServiceController) or local ticks — never by
// writing to Firebase, and never by polling on a timer for correctness.
//
// The notification tap handler works whether the app is foregrounded,
// backgrounded, or fully closed: flutter_local_notifications spins up a
// background isolate for `onDidReceiveBackgroundNotificationResponse` when
// needed, so the action handler below re-initializes Firebase itself rather
// than depending on any already-running app state.
// ==========================================================================

import 'dart:async';

import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../services/firebase_options.dart';
import '../services/firebase_service.dart';
import '../services/power_sequence_service.dart';

const String kNotificationChannelId = 'crantrol_status';
const String kNotificationChannelName = 'CRANTROL Status';
const int kStatusNotificationId = 8801;
const String kTogglePcActionId = 'TOGGLE_PC';
const String kDefaultDeviceId = 'device_001';

final FlutterLocalNotificationsPlugin _plugin =
    FlutterLocalNotificationsPlugin();

/// Runs in whatever isolate delivered the tap — could be the main isolate
/// (app foreground/background) or a fresh background isolate (app closed).
/// Must be a top-level function so it can be used as a background entry
/// point.
@pragma('vm:entry-point')
void notificationTapEntryPoint(NotificationResponse response) {
  _handleNotificationTap(response);
}

Future<void> _handleNotificationTap(NotificationResponse response) async {
  if (response.actionId != kTogglePcActionId) {
    return;
  }
  try {
    if (Firebase.apps.isEmpty) {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await NotificationService.runAutoFromNotification(kDefaultDeviceId);
  } catch (_) {
    // Best-effort — if this fails (e.g. signed out, offline), the user can
    // still open the app and use the AUTO button directly.
  }
}

class NotificationService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
      onDidReceiveBackgroundNotificationResponse: notificationTapEntryPoint,
    );

    const channel = AndroidNotificationChannel(
      kNotificationChannelId,
      kNotificationChannelName,
      description: 'Live PC power, uptime and network status',
      importance: Importance.low, // ongoing status — not an alert
      showBadge: false,
    );

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(channel);
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  /// Rebuilds the persistent notification content. Called by
  /// BackgroundServiceController whenever a new Firebase status event
  /// arrives, or once per second locally to keep the uptime text ticking —
  /// that per-second refresh never touches the network.
  static Future<void> showStatusNotification({
    required bool pcOn,
    required bool transitioning,
    required String uptimeText,
    required bool online,
    required String networkSummary,
  }) async {
    final pcLabel = transitioning ? 'WORKING' : (pcOn ? 'ON' : 'OFF');
    final title = 'CRANTROL — PC $pcLabel';
    final body =
        online
            ? 'Uptime $uptimeText · $networkSummary'
            : 'Device offline · last known: PC $pcLabel';

    final actionTitle = pcOn ? 'TURN OFF PC' : 'TURN ON PC';

    final androidDetails = AndroidNotificationDetails(
      kNotificationChannelId,
      kNotificationChannelName,
      channelDescription: 'Live PC power, uptime and network status',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: false,
      icon: '@mipmap/launcher_icon',
      actions: [
        AndroidNotificationAction(
          kTogglePcActionId,
          actionTitle,
          showsUserInterface: false,
          cancelNotification: false,
        ),
      ],
    );

    await _plugin.show(
      kStatusNotificationId,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> cancel() => _plugin.cancel(kStatusNotificationId);

  /// Executes the same AUTO ON/OFF logic as the dashboard button, driven
  /// directly against Firebase (no DeviceProvider/BuildContext available
  /// from a notification tap).
  static Future<void> runAutoFromNotification(String deviceId) async {
    final firebaseService = FirebaseService();
    final snapshot =
        await FirebaseDatabase.instance
            .ref('devices/$deviceId/status/relays/relay${PowerSequenceService.kRelayPcMain}/state')
            .get();
    final pcCurrentlyOn = snapshot.exists && snapshot.value == true;
    final kind = PowerSequenceService.kindFor(pcCurrentlyOn: pcCurrentlyOn);

    await firebaseService.setPcTransition(deviceId, active: true, kind: kind);
    try {
      for (final step in PowerSequenceService.stepsFor(
        pcCurrentlyOn: pcCurrentlyOn,
      )) {
        if (step.delayBefore > Duration.zero) {
          await Future<void>.delayed(step.delayBefore);
        }
        await firebaseService.setRelayState(
          deviceId,
          step.relayId,
          step.turnOn,
        );
      }
    } finally {
      await firebaseService.setPcTransition(deviceId, active: false);
    }
  }
}
