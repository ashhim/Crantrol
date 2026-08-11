// ==========================================================================
// CRANTROL Dashboard Screen
//
// The place to MONITOR the system — no direct control here. PC/SP state,
// uptime, network/controller status, runtime totals (Today/Week/Month),
// relay activity summary and active schedules. Everything here is either
// read straight from DeviceProvider's already-synced state or computed
// locally on a 1-second ticker — this screen never writes to Firebase.
// ==========================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/device.dart';
import '../providers/device_provider.dart';
import '../services/power_sequence_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/schedule_badge.dart';
import 'dashboard_overview_panel.dart';

const _kPanel = Color(0xFF0C1018);
const _kPanelBorder = Color(0xFF1A2332);
const _kCard = Color(0xFF111820);
const _kGreen = Color(0xFF00E676);
const _kRed = Color(0xFFFF1744);
const _kAmber = Color(0xFFD4A017);
const _kTextPrimary = Color(0xFFE0E0E0);
const _kTextMuted = Color(0xFF5A6A7A);

class DashboardScreen extends StatefulWidget {
  final String deviceId;
  const DashboardScreen({required this.deviceId, super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();
    // Purely local repaint (uptime/countdown text) — no network activity.
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    super.dispose();
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _fmtClock(DateTime? t) {
    if (t == null || t.millisecondsSinceEpoch <= 0) return '--:--';
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, dp, _) {
        if (dp.isLoading) {
          return const Center(child: CircularProgressIndicator(color: _kGreen));
        }
        if (dp.error != null) {
          return CustomErrorWidget(
            message: dp.error ?? 'Unknown error',
            onRetry: () => dp.selectDevice(widget.deviceId),
          );
        }
        final device = dp.selectedDevice;
        final status = dp.deviceStatus;
        if (device == null) {
          return const CustomErrorWidget(message: 'Device not found');
        }

        final rsMap = <int, RelayStatus>{
          for (final rs in status?.relayStates ?? const <RelayStatus>[])
            rs.id: rs,
        };
        // Authoritative PC state — GPIO45/PLED via DeviceProvider, never
        // assumed from Relay 1.
        final pcOn = dp.pcActualOn;
        final isOnline = dp.isDeviceOnline;
        final pcTimer = dp.relayTimerData(PowerSequenceService.kRelayPcMain);

        return SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title(),
                const SizedBox(height: 10),
                DashboardOverviewPanel(
                  device: device,
                  status: status,
                  isOnline: isOnline,
                  pcOn: pcOn,
                  pcTransitioning: dp.isPcTransitioning,
                  pcTransitionFailed: dp.isPcTransitionFailed,
                ),
                const SizedBox(height: 10),
                _runtimeTotals(dp, pcTimer, pcOn),
                const SizedBox(height: 10),
                _scheduledActions(dp),
                const SizedBox(height: 10),
                _relayActivity(device, rsMap, dp),
                const SizedBox(height: 10),
                _devices(dp),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _title() {
    return Row(
      children: [
        const Icon(Icons.insights_rounded, color: _kGreen, size: 18),
        const SizedBox(width: 8),
        Text(
          'DASHBOARD',
          style: GoogleFonts.orbitron(
            color: _kTextPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({required String title, required IconData icon, required Widget child}) {
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
              Icon(icon, color: _kGreen, size: 14),
              const SizedBox(width: 6),
              Text(
                title,
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
          child,
        ],
      ),
    );
  }

  // ── Runtime totals: Today / This Week / This Month / Session / Start-Stop
  Widget _runtimeTotals(
    DeviceProvider dp,
    Map<String, dynamic>? pcTimer,
    bool pcOn,
  ) {
    final startedAt =
        pcTimer != null && pcTimer['startedAt'] is int
            ? DateTime.fromMillisecondsSinceEpoch(pcTimer['startedAt'] as int)
            : null;
    final stoppedAt =
        pcTimer != null && pcTimer['stoppedAt'] is int
            ? DateTime.fromMillisecondsSinceEpoch(pcTimer['stoppedAt'] as int)
            : null;

    return _sectionCard(
      title: 'PC RUNTIME TOTALS',
      icon: Icons.bar_chart_rounded,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _statTile(
                  'TODAY',
                  _fmtDuration(Duration(milliseconds: dp.todayPcUsageMs)),
                  _kGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statTile(
                  'THIS WEEK',
                  _fmtDuration(Duration(milliseconds: dp.weekPcUsageMs)),
                  _kGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statTile(
                  'THIS MONTH',
                  _fmtDuration(Duration(milliseconds: dp.monthPcUsageMs)),
                  _kGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _statTile(
                  'PC STARTED',
                  _fmtClock(startedAt),
                  pcOn ? _kGreen : _kTextMuted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statTile(
                  'PC LAST STOPPED',
                  pcOn ? '—' : _fmtClock(stoppedAt),
                  _kTextMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, Color color) {
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
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.orbitron(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ── Active schedules with live countdown ────────────────────────────────
  Widget _scheduledActions(DeviceProvider dp) {
    final schedules = dp.activeSchedules;
    return _sectionCard(
      title: 'SCHEDULED ACTIONS',
      icon: Icons.event_note_rounded,
      child:
          schedules.isEmpty
              ? Text(
                'No scheduled actions. Long-press a relay, AUTO, or PC/SP to set one.',
                style: GoogleFonts.orbitron(
                  color: _kTextMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              )
              : Column(
                children: [
                  for (final entry in schedules) ...[
                    _scheduleRow(entry),
                    if (entry != schedules.last) const SizedBox(height: 6),
                  ],
                ],
              ),
    );
  }

  Widget _scheduleRow(ScheduleEntry entry) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kPanelBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: _kAmber, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${scheduleSlotLabel(entry.key)}'
              '${entry.action != null ? ' → ${entry.action}' : ''}',
              style: GoogleFonts.orbitron(
                color: _kTextPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ScheduleCountdownBadge(entry: entry, fontSize: 9),
        ],
      ),
    );
  }

  // ── Relay activity summary ──────────────────────────────────────────────
  Widget _relayActivity(
    Device device,
    Map<int, RelayStatus> rsMap,
    DeviceProvider dp,
  ) {
    final relays = [...device.relays]..sort((a, b) => a.id.compareTo(b.id));
    return _sectionCard(
      title: 'RELAY ACTIVITY SUMMARY',
      icon: Icons.view_list_rounded,
      child: Column(
        children: [
          for (final relay in relays)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          (rsMap[relay.id]?.isOn ?? relay.isOn)
                              ? _kGreen
                              : _kRed.withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 26,
                    child: Text(
                      'R${relay.id}',
                      style: GoogleFonts.orbitron(
                        color: _kTextMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      relayDisplayName(relay.id, configuredName: relay.name),
                      style: GoogleFonts.orbitron(
                        color: _kTextPrimary,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    (rsMap[relay.id]?.isOn ?? relay.isOn) ? 'ON' : 'OFF',
                    style: GoogleFonts.orbitron(
                      color:
                          (rsMap[relay.id]?.isOn ?? relay.isOn)
                              ? _kGreen
                              : _kTextMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── LAN devices — ESP32's local ARP-based scan, dynamic subnet ─────────
  Widget _devices(DeviceProvider dp) {
    final devices = [...dp.networkDevices]
      ..sort((a, b) {
        if (a.active != b.active) return a.active ? -1 : 1;
        return a.ip.compareTo(b.ip);
      });
    final activeCount = devices.where((d) => d.active).length;

    return _sectionCard(
      title: 'DEVICES',
      icon: Icons.lan_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                dp.networkSubnet.isEmpty
                    ? 'Subnet: --'
                    : 'Subnet: ${dp.networkSubnet}',
                style: GoogleFonts.orbitron(
                  color: _kTextMuted,
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .5,
                ),
              ),
              const Spacer(),
              Text(
                '$activeCount / ${devices.length} ACTIVE',
                style: GoogleFonts.orbitron(
                  color: _kGreen,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (devices.isEmpty)
            Text(
              'No devices discovered yet on the LAN.',
              style: GoogleFonts.orbitron(
                color: _kTextMuted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Column(
              children: [
                for (final device in devices) ...[
                  _deviceRow(device),
                  if (device != devices.last) const SizedBox(height: 6),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _deviceRow(NetworkDevice device) {
    final label = device.hostname.isNotEmpty ? device.hostname : device.ip;
    final agoText = _fmtAgoMs(device.lastSeenAgoMs);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kPanelBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: device.active ? _kGreen : _kRed.withOpacity(0.4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.orbitron(
                    color: _kTextPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  device.hostname.isNotEmpty ? device.ip : device.mac,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.orbitron(
                    color: _kTextMuted,
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            device.active ? 'ACTIVE · $agoText' : 'INACTIVE · $agoText',
            style: GoogleFonts.orbitron(
              color: device.active ? _kGreen : _kTextMuted,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtAgoMs(int ms) {
    if (ms < 5000) return 'just now';
    final d = Duration(milliseconds: ms);
    if (d.inMinutes < 1) return '${d.inSeconds}s ago';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
