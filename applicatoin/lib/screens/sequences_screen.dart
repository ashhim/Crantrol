// ==========================================================================
// CRANTROL Sequences Screen
//
// Focused only on the system's built-in sequences/macros — not a relay
// page. AUTO supports the same tap = run now / long-press = schedule
// behavior as the Control screen, with live status and countdown.
// ==========================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/device.dart';
import '../providers/device_provider.dart';
import '../widgets/common_widgets.dart';
import '../widgets/schedule_badge.dart';
import '../widgets/schedule_dialog.dart';

const _kPanel = Color(0xFF0B1220);
const _kPanelBorder = Color(0xFF1F2937);
const _kGreen = Color(0xFF22C55E);
const _kRed = Color(0xFFEF4444);
const _kAmber = Color(0xFFF97316);
const _kTextMuted = Color(0xFF94A3B8);

class SequencesScreen extends StatefulWidget {
  final String deviceId;

  const SequencesScreen({required this.deviceId, super.key});

  @override
  State<SequencesScreen> createState() => _SequencesScreenState();
}

class _SequencesScreenState extends State<SequencesScreen> {
  bool _sequenceInProgress = false;
  String _sequenceStatus = 'Idle';
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Purely local — redraws the AUTO countdown text. No network activity.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _executeSequence(
    Future<void> Function() sequence,
    String label,
  ) async {
    if (_sequenceInProgress) return;
    setState(() {
      _sequenceInProgress = true;
      _sequenceStatus = '$label...';
    });

    try {
      await sequence();
      setState(() {
        _sequenceStatus = '$label complete';
      });
    } catch (_) {
      setState(() {
        _sequenceStatus = '$label failed';
      });
    } finally {
      if (mounted) {
        setState(() {
          _sequenceInProgress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sequences')),
      body: Consumer<DeviceProvider>(
        builder: (context, deviceProvider, _) {
          if (deviceProvider.isLoading) {
            return const LoadingOverlay(message: 'Loading sequences...');
          }

          if (deviceProvider.error != null) {
            return CustomErrorWidget(
              message: deviceProvider.error ?? 'Unable to load sequences',
              onRetry: () => deviceProvider.selectDevice(widget.deviceId),
            );
          }

          final device = deviceProvider.selectedDevice;
          if (device == null) {
            return const Center(child: Text('Device not found'));
          }

          final autoSchedule = deviceProvider.scheduleFor('auto');
          final autoRunning = deviceProvider.isPcTransitioning;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _kPanel,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: _kPanelBorder, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SEQUENCE STATUS',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF5EEAD4),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            autoRunning
                                ? Icons.autorenew_rounded
                                : Icons.check_circle_outline,
                            size: 16,
                            color: autoRunning ? _kAmber : _kGreen,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            autoRunning ? 'AUTO sequence running…' : _sequenceStatus,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(color: _kTextMuted),
                          ),
                        ],
                      ),
                      if (autoSchedule != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.schedule, size: 14, color: _kRed),
                            const SizedBox(width: 6),
                            Text(
                              'AUTO scheduled → ',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: _kTextMuted),
                            ),
                            ScheduleCountdownBadge(entry: autoSchedule),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _buildSequenceCard(
                  context,
                  title: 'Emergency Shutdown',
                  description: 'Turn off all plug relays immediately.',
                  buttonLabel: 'Trigger SOS',
                  onPressed: () async {
                    await _executeSequence(
                      () => deviceProvider.toggleSOS(widget.deviceId),
                      'Emergency Shutdown',
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildSequenceCard(
                  context,
                  title: 'PC Reset',
                  description: 'Pulse the reset relay to reboot the PC.',
                  buttonLabel: 'Reset PC',
                  onPressed: () async {
                    await _executeSequence(
                      () => deviceProvider.setRelayState(
                        widget.deviceId,
                        10,
                        true,
                      ),
                      'PC Reset',
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildSequenceCard(
                  context,
                  title: 'Power Button Pulse',
                  description: 'Send a single power pulse to the PC relay.',
                  buttonLabel: 'Pulse Power',
                  onPressed: () async {
                    await _executeSequence(
                      () => deviceProvider.setRelayState(
                        widget.deviceId,
                        9,
                        true,
                      ),
                      'Power Pulse',
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildSequenceCard(
                  context,
                  title: 'AUTO Power Sequence',
                  description:
                      'Inspects the current PC state and runs the matching '
                      'ON or OFF sequence automatically — same as the '
                      'Control screen AUTO button. Tap to run now, hold to '
                      'schedule for later.',
                  buttonLabel: 'Run AUTO',
                  isPrimary: true,
                  schedule: autoSchedule,
                  onPressed: () async {
                    await _executeSequence(
                      () =>
                          deviceProvider.runAutoPowerSequence(widget.deviceId),
                      'AUTO Sequence',
                    );
                  },
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    showSchedulerDialog(
                      context,
                      deviceId: widget.deviceId,
                      scheduleKey: 'auto',
                      label: 'AUTO',
                      showOnOffToggle: false,
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

  Widget _buildSequenceCard(
    BuildContext context, {
    required String title,
    required String description,
    required String buttonLabel,
    required VoidCallback onPressed,
    VoidCallback? onLongPress,
    ScheduleEntry? schedule,
    bool isPrimary = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kPanelBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (schedule != null) ScheduleCountdownBadge(entry: schedule),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: _kTextMuted),
          ),
          if (onLongPress != null) ...[
            const SizedBox(height: 6),
            Text(
              'Tap = run now · Hold = schedule',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: _kTextMuted),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onLongPress: onLongPress,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isPrimary ? _kGreen : const Color(0xFF1E293B),
                  foregroundColor: isPrimary ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  buttonLabel,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
