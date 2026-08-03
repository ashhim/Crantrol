import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/device.dart';
import '../providers/device_provider.dart';
import '../widgets/common_widgets.dart';

class RelaysScreen extends StatelessWidget {
  final String deviceId;

  const RelaysScreen({required this.deviceId, super.key});

  String _formatElapsed(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _relayTimerLabel(Relay relay) {
    if (relay.lastCommandTime.millisecondsSinceEpoch <= 0) {
      return 'Idle';
    }
    final elapsed = DateTime.now().difference(relay.lastCommandTime);
    return _formatElapsed(elapsed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relays')),
      body: Consumer<DeviceProvider>(
        builder: (context, deviceProvider, _) {
          if (deviceProvider.isLoading) {
            return const LoadingOverlay(message: 'Loading relays...');
          }

          if (deviceProvider.error != null) {
            return CustomErrorWidget(
              message: deviceProvider.error ?? 'Unable to load relays',
              onRetry: () => deviceProvider.selectDevice(deviceId),
            );
          }

          final device = deviceProvider.selectedDevice;
          if (device == null) {
            return const Center(child: Text('Device not found'));
          }

          final relays = [...device.relays]
            ..sort((a, b) => a.id.compareTo(b.id));

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1220),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: const Color(0xFF1F2937),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RELAY GRID',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF5EEAD4),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Control each relay individually with current status and pulse support.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: relays.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final relay = relays[index];
                    final isPending = deviceProvider.isRelayCommandPending(
                      relay.id,
                    );
                    final pendingAction = deviceProvider.relayPendingAction(
                      relay.id,
                    );

                    return RelayCard(
                      relayId: relay.id,
                      name: relay.name,
                      isOn: relay.isOn,
                      enabled: relay.enabled,
                      isPulse: relay.isPulse,
                      isPending: isPending,
                      pendingAction: pendingAction,
                      timerLabel: _relayTimerLabel(relay),
                      onToggle:
                          relay.enabled
                              ? () {
                                if (relay.isPulse) {
                                  deviceProvider.pulseRelay(deviceId, relay.id);
                                } else {
                                  deviceProvider.setRelayState(
                                    deviceId,
                                    relay.id,
                                    !relay.isOn,
                                  );
                                }
                              }
                              : null,
                      onPulse:
                          relay.isPulse
                              ? () =>
                                  deviceProvider.pulseRelay(deviceId, relay.id)
                              : null,
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
