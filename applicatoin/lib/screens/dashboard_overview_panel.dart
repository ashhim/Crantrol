// ==========================================================================
// CRANTROL Dashboard Overview Panel
//
// Dedicated "at a glance" system summary: PC state, PC uptime, network /
// controller status, relay summary and last event. Uptime and freshness are
// computed locally from Firebase-provided timestamps on a 1-second local
// tick — this widget never writes to Firebase and never polls it; it only
// reads whatever DeviceProvider already has in memory from its existing
// realtime status/timer subscriptions.
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

class DashboardOverviewPanel extends StatefulWidget {
  final Device device;
  final DeviceStatus? status;
  final bool isOnline;
  final bool pcOn;
  final bool pcTransitioning;
  final bool pcTransitionFailed;

  const DashboardOverviewPanel({
    required this.device,
    required this.status,
    required this.isOnline,
    required this.pcOn,
    required this.pcTransitioning,
    this.pcTransitionFailed = false,
    super.key,
  });

  @override
  State<DashboardOverviewPanel> createState() =>
      _DashboardOverviewPanelState();
}

class _DashboardOverviewPanelState extends State<DashboardOverviewPanel> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Purely local — recomputes elapsed durations from timestamps already
    // held in memory. No network activity.
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

  String _fmtAgo(DateTime? t) {
    if (t == null || t.millisecondsSinceEpoch <= 0) return 'Never';
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 5) return 'Just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DeviceProvider>();
    final pcUptime = _pcUptime(dp);
    final lastEvent = _lastEvent(widget.device);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kPanelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dashboard_customize, color: _kGreen, size: 14),
              const SizedBox(width: 6),
              Text(
                'SYSTEM OVERVIEW',
                style: GoogleFonts.orbitron(
                  color: _kTextPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _statTile(
                  label: 'PC STATE',
                  value:
                      widget.pcTransitionFailed
                          ? 'FAILED'
                          : (widget.pcTransitioning
                              ? 'WORKING'
                              : (widget.pcOn ? 'ON' : 'OFF')),
                  color:
                      widget.pcTransitionFailed
                          ? _kRed
                          : (widget.pcTransitioning
                              ? _kAmber
                              : (widget.pcOn ? _kGreen : _kRed)),
                  icon:
                      widget.pcTransitionFailed
                          ? Icons.error_outline
                          : Icons.power_settings_new,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statTile(
                  label: 'PC UPTIME',
                  value: pcUptime == null ? '--:--:--' : _fmtDuration(pcUptime),
                  color: widget.pcOn ? _kGreen : _kTextMuted,
                  icon: Icons.timelapse,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _networkStatusRow(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _statTile(
                  label: 'LAST SEEN',
                  value: _fmtAgo(widget.device.lastSeen),
                  color: widget.isOnline ? _kGreen : _kTextMuted,
                  icon: Icons.schedule,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statTile(
                  label: 'LAST EVENT',
                  value: lastEvent,
                  color: _kTextPrimary,
                  icon: Icons.history,
                  small: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Live uptime computed locally from the Relay 1 (PC Power) start
  /// timestamp already synced via DeviceProvider's timer subscription — no
  /// per-second Firebase writes or reads.
  Duration? _pcUptime(DeviceProvider dp) {
    final timerData = dp.relayTimerData(PowerSequenceService.kRelayPcMain);
    if (timerData == null) return null;
    final startedAt = timerData['startedAt'] as int? ?? 0;
    final lastElapsedMs = timerData['lastElapsedMs'] as int? ?? 0;

    if (widget.pcOn && startedAt > 0) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - startedAt;
      return Duration(milliseconds: elapsed > 0 ? elapsed : 0);
    }
    if (!widget.pcOn && lastElapsedMs > 0) {
      return Duration(milliseconds: lastElapsedMs);
    }
    return null;
  }

  /// Most recent relay state change across all 10 relays — derived entirely
  /// from timestamps DeviceProvider already tracks locally, not a new
  /// Firebase read.
  String _lastEvent(Device device) {
    Relay? latest;
    for (final relay in device.relays) {
      if (relay.lastCommandTime.millisecondsSinceEpoch <= 0) continue;
      if (latest == null ||
          relay.lastCommandTime.isAfter(latest.lastCommandTime)) {
        latest = relay;
      }
    }
    if (latest == null) return 'No events yet';
    final name = relayDisplayName(latest.id, configuredName: latest.name);
    final action = latest.isOn ? 'ON' : 'OFF';
    return '$name → $action · ${_fmtAgo(latest.lastCommandTime)}';
  }

  Widget _networkStatusRow() {
    final status = widget.status;
    // If the device isn't confirmed online (fresh heartbeat), the last
    // cached booleans could be stale-positive — never present them as live.
    final trustFields = widget.isOnline && status != null;

    Color dot(bool value) =>
        !trustFields ? _kTextMuted : (value ? _kGreen : _kRed);
    String label(bool value) =>
        !trustFields ? 'UNKNOWN' : (value ? 'OK' : 'DOWN');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kPanelBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _miniStatus(
              'ETHERNET',
              dot(status?.ethernetPlugged ?? false),
              label(status?.ethernetPlugged ?? false),
            ),
          ),
          Container(width: 1, height: 22, color: _kPanelBorder),
          Expanded(
            child: _miniStatus(
              'INTERNET',
              dot(status?.internetAvailable ?? false),
              label(status?.internetAvailable ?? false),
            ),
          ),
          Container(width: 1, height: 22, color: _kPanelBorder),
          Expanded(
            child: _miniStatus(
              'FIREBASE',
              dot(status?.firebaseReady ?? false),
              label(status?.firebaseReady ?? false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStatus(String label, Color color, String value) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.orbitron(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.orbitron(
            color: _kTextMuted,
            fontSize: 7,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _statTile({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    bool small = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kPanelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 11),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.orbitron(
                  color: _kTextMuted,
                  fontSize: 7,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.orbitron(
              color: color,
              fontSize: small ? 9 : 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
