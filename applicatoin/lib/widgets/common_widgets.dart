import 'package:flutter/material.dart';

class StatusIndicator extends StatelessWidget {
  final String label;
  final bool isActive;
  final IconData? icon;

  const StatusIndicator({
    required this.label,
    required this.isActive,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: Icon(
                icon,
                size: 18,
                color:
                    isActive
                        ? const Color(0xFF22C55E)
                        : const Color(0xFF64748B),
              ),
            ),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: Colors.white),
            ),
          ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  isActive ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
              boxShadow: [
                BoxShadow(
                  color: (isActive
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFEF4444))
                      .withOpacity(0.55),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MetricChip extends StatelessWidget {
  final String label;
  final bool value;
  final IconData icon;

  const MetricChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: value ? const Color(0xFF102A22) : const Color(0xFF111827),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: value ? const Color(0xFF22C55E) : const Color(0xFF334155),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: value ? const Color(0xFF5EEAD4) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class RelayCard extends StatelessWidget {
  final int relayId;
  final String name;
  final bool isOn;
  final bool enabled;
  final bool isPulse;
  final bool isPending;
  final String? pendingAction;
  final String timerLabel;
  final VoidCallback? onToggle;
  final VoidCallback? onPulse;

  const RelayCard({
    required this.relayId,
    required this.name,
    required this.isOn,
    required this.enabled,
    required this.isPulse,
    this.isPending = false,
    this.pendingAction,
    required this.timerLabel,
    required this.onToggle,
    this.onPulse,
  });

  @override
  Widget build(BuildContext context) {
    final isPlug = relayId >= 1 && relayId <= 8;
    final actionText =
        isPending
            ? (pendingAction == 'PULSE' ? 'Pulsing…' : 'Waiting…')
            : (isOn ? 'OFF' : 'ON');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1F2937), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPlug ? 'PLUG$relayId' : 'Relay $relayId',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF5EEAD4),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      isPending
                          ? const Color(0xFFF97316)
                          : (isOn
                              ? const Color(0xFF22C55E)
                              : const Color(0xFF475569)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isPending ? 'WAIT' : (isOn ? 'ON' : 'OFF'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Timer: $timerLabel',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: const Color(0xFFCBD5E1)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: enabled && !isPending ? onToggle : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isOn ? const Color(0xFF7F1D1D) : const Color(0xFF14532D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                actionText,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          if (isPulse) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: enabled && !isPending ? onPulse : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F4C81),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Pulse'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class DeviceStatusCard extends StatelessWidget {
  final bool ethernetPlugged;
  final bool internetAvailable;
  final bool firebaseReady;
  final String localIp;
  final bool isOnline;

  const DeviceStatusCard({
    required this.ethernetPlugged,
    required this.internetAvailable,
    required this.firebaseReady,
    required this.localIp,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF1F2937), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'SYSTEM STATUS',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF5EEAD4),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      isOnline
                          ? const Color(0xFF14532D)
                          : const Color(0xFF7F1D1D),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isOnline ? 'ONLINE' : 'OFFLINE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StatusIndicator(
            label: 'Ethernet link',
            isActive: ethernetPlugged,
            icon: Icons.cable,
          ),
          const SizedBox(height: 10),
          StatusIndicator(
            label: 'Internet link',
            isActive: internetAvailable,
            icon: Icons.language,
          ),
          const SizedBox(height: 10),
          StatusIndicator(
            label: 'Firebase sync',
            isActive: firebaseReady,
            icon: Icons.cloud,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1F2937)),
            ),
            child: Row(
              children: [
                const Icon(Icons.router, color: Color(0xFF5EEAD4)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    localIp.isEmpty ? 'Local IP: N/A' : 'Local IP: $localIp',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  final String message;

  const LoadingOverlay({this.message = 'Loading...'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF5EEAD4)),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class CustomErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const CustomErrorWidget({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text('Error', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}
