import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/device_provider.dart';
import '../widgets/common_widgets.dart';

class SequencesScreen extends StatefulWidget {
  final String deviceId;

  const SequencesScreen({required this.deviceId, super.key});

  @override
  State<SequencesScreen> createState() => _SequencesScreenState();
}

class _SequencesScreenState extends State<SequencesScreen> {
  bool _sequenceInProgress = false;
  String _sequenceStatus = 'Idle';

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
                        'SEQUENCE CONTROLS',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF5EEAD4),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _sequenceStatus,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
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
                  title: 'Shutdown Sequence',
                  description:
                      'Safely shut down plugs then pulse the power relay.',
                  buttonLabel: 'Run Sequence',
                  isPrimary: true,
                  onPressed: () async {
                    await _executeSequence(
                      () =>
                          deviceProvider.runAutoPowerSequence(widget.deviceId),
                      'Shutdown Sequence',
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
    bool isPrimary = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1F2937), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isPrimary
                        ? const Color(0xFF22C55E)
                        : const Color(0xFF1E293B),
                foregroundColor: isPrimary ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                buttonLabel,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
