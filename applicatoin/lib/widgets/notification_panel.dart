// ==========================================================================
// CRANTROL In-App Notification Panel
//
// A proper status/control card — not a plain message. Mirrors what the
// system notification shows (PC state, SP state, network, uptime, next
// scheduled action) plus a working action button, right inside the app.
// Purely a read/render of state DeviceProvider already holds in memory;
// its own 1-second ticker only repaints text locally, it writes nothing.
// ==========================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/device.dart';
import '../providers/device_provider.dart';
import '../services/power_sequence_service.dart';

const _kPanel = Color(0xFF0C1018);
const _kPanelBorder = Color(0xFF1A2332);
const _kCard = Color(0xFF111820);
const _kGreen = Color(0xFF00E676);
const _kRed = Color(0xFFFF1744);
const _kAmber = Color(0xFFD4A017);
const _kTextPrimary = Color(0xFFE0E0E0);
const _kTextMuted = Color(0xFF5A6A7A);

class NotificationPanelCard extends StatefulWidget {
  final String deviceId;
  const NotificationPanelCard({required this.deviceId, super.key});

  @override
  State<NotificationPanelCard> createState() => _NotificationPanelCardState();
}

class _NotificationPanelCardState extends State<NotificationPanelCard> {
  Timer? _ticker;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _runAuto(DeviceProvider dp) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await dp.runAutoPowerSequence(widget.deviceId);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DeviceProvider>();
    final device = dp.selectedDevice;
    final status = dp.deviceStatus;
    if (device == null) return const SizedBox.shrink();

    final rsMap = <int, RelayStatus>{
      for (final rs in status?.relayStates ?? const <RelayStatus>[])
        rs.id: rs,
    };
    final pcOn = (rsMap[PowerSequenceService.kRelayPcMain]?.isOn) ?? false;
    final spOn = (rsMap[10]?.isOn) ?? false;
    final transitioning = dp.isPcTransitioning;
    final isOnline = dp.isDeviceOnline;

    final timerData = dp.relayTimerData(PowerSequenceService.kRelayPcMain);
    Duration? uptime;
    if (timerData != null) {
      final startedAt = timerData['startedAt'] as int? ?? 0;
      final lastElapsedMs = timerData['lastElapsedMs'] as int? ?? 0;
      if (pcOn && startedAt > 0) {
        final elapsed = DateTime.now().millisecondsSinceEpoch - startedAt;
        uptime = Duration(milliseconds: elapsed > 0 ? elapsed : 0);
      } else if (!pcOn && lastElapsedMs > 0) {
        uptime = Duration(milliseconds: lastElapsedMs);
      }
    }

    final nextAction = dp.nextScheduledAction;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kPanelBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_active_rounded,
                color: isOnline ? _kGreen : _kTextMuted,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'LIVE STATUS',
                style: GoogleFonts.orbitron(
                  color: _kTextPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: (isOnline ? _kGreen : _kRed).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: (isOnline ? _kGreen : _kRed).withOpacity(0.4),
                  ),
                ),
                child: Text(
                  isOnline ? 'ONLINE' : 'OFFLINE',
                  style: GoogleFonts.orbitron(
                    color: isOnline ? _kGreen : _kRed,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _stateChip(
                  'PC',
                  transitioning ? 'WORKING' : (pcOn ? 'ON' : 'OFF'),
                  transitioning ? _kAmber : (pcOn ? _kGreen : _kRed),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _stateChip('SP', spOn ? 'ON' : 'OFF', spOn ? _kGreen : _kRed),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _stateChip(
                  'UPTIME',
                  uptime == null ? '--:--:--' : _fmtDuration(uptime),
                  pcOn ? _kGreen : _kTextMuted,
                ),
              ),
            ],
          ),
          if (nextAction != null) ...[
            const SizedBox(height: 10),
            _countdownRow(nextAction),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : () => _runAuto(dp),
              icon:
                  _busy
                      ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                      : const Icon(Icons.power_settings_new, size: 16),
              label: Text(
                pcOn ? 'TURN OFF PC' : 'TURN ON PC',
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: pcOn ? _kRed : _kGreen,
                foregroundColor: pcOn ? Colors.white : Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stateChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kPanelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.orbitron(
              color: _kTextMuted,
              fontSize: 7,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.orbitron(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _countdownRow(ScheduleEntry entry) {
    final remaining = entry.remaining;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _kRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer, color: _kRed, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Next: ${scheduleSlotLabel(entry.key)}'
              '${entry.action != null ? ' → ${entry.action}' : ''}',
              style: GoogleFonts.orbitron(
                color: _kTextPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            _fmtDuration(remaining),
            style: GoogleFonts.orbitron(
              color: _kRed,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
