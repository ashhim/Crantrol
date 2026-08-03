// ==========================================================================
// CRANTROL Dashboard Screen
// Industrial control-panel interface matching the reference design spec.
// ==========================================================================

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/device.dart';
import '../providers/device_provider.dart';
import '../widgets/common_widgets.dart';

// ── Dashboard colour palette ─────────────────────────────────────────────────
const _kPanel        = Color(0xFF0C1018);
const _kPanelBorder  = Color(0xFF1A2332);
const _kCard         = Color(0xFF111820);
const _kMetalLight   = Color(0xFF3A4A5A);
const _kMetalMid     = Color(0xFF252F3A);
const _kMetalDark    = Color(0xFF0D1117);
const _kGreen        = Color(0xFF00E676);
const _kRed          = Color(0xFFFF1744);
const _kAmber        = Color(0xFFD4A017);
const _kBlue         = Color(0xFF00B0FF);
const _kTextPrimary  = Color(0xFFE0E0E0);
const _kTextMuted    = Color(0xFF5A6A7A);

// ─────────────────────────────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  final String deviceId;
  const DashboardScreen({required this.deviceId, super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  // ── Animation controllers ──────────────────────────────────────────────
  late final AnimationController _sosGlow = AnimationController(
    duration: const Duration(milliseconds: 1500),
    vsync: this,
  )..repeat(reverse: true);

  // ── State ──────────────────────────────────────────────────────────────
  Timer? _uiTimer;
  bool _isAutoRunning = false;
  int  _autoStep      = 0;
  bool _isPCPressed   = false;
  bool _isSPPressed   = false;
  bool _isSOSPressed  = false;
  bool _isAlertPressed = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<DeviceProvider>(context, listen: false)
          .selectDevice(widget.deviceId);
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _sosGlow.dispose();
    super.dispose();
  }

  // ── Timer helpers ──────────────────────────────────────────────────────
  String _fmt(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// Relay timer from Firebase-synced data (consistent across all devices).
  String _relayTimer(DeviceProvider dp, int relayId, bool isOn) {
    final timerData = dp.relayTimerData(relayId);
    if (timerData == null) return '';

    final startedAt = timerData['startedAt'] as int? ?? 0;
    final lastElapsedMs = timerData['lastElapsedMs'] as int? ?? 0;

    if (isOn && startedAt > 0) {
      // Relay is ON: compute live elapsed from stored start time
      final elapsed = DateTime.now().millisecondsSinceEpoch - startedAt;
      return _fmt(Duration(milliseconds: elapsed > 0 ? elapsed : 0));
    } else if (!isOn && lastElapsedMs > 0) {
      // Relay is OFF: show frozen elapsed from last session
      return _fmt(Duration(milliseconds: lastElapsedMs));
    }
    return '';
  }

  String _relayName(int id, String configured) {
    if (configured.isNotEmpty &&
        !configured.startsWith('PLUG') &&
        configured != 'Relay $id') {
      return configured.toUpperCase();
    }
    const names = {
      1: 'PC POWER', 2: 'MONITOR 1', 3: 'MONITOR 2', 4: 'MOTHERBOARD',
      5: 'RELAY 5',  6: 'RELAY 6',   7: 'RELAY 7',   8: 'RELAY 8',
    };
    return names[id] ?? configured.toUpperCase();
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, dp, _) {
        if (dp.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: _kGreen),
          );
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

        final relays = device.relays;
        final rsMap = <int, RelayStatus>{
          for (final rs in status?.relayStates ?? const <RelayStatus>[])
            rs.id: rs,
        };

        final plugs = relays.where((r) => isPlugRelay(r.id)).toList()
          ..sort((a, b) => a.id.compareTo(b.id));

        final pcStatus = rsMap[9]  ?? RelayStatus.placeholder(9);
        final spStatus = rsMap[10] ?? RelayStatus.placeholder(10);

        // Use provider's robust online check (considers event recency)
        final isOnline = dp.isDeviceOnline;

        final activeCount = relays.fold<int>(0, (s, r) {
          return s + ((rsMap[r.id]?.isOn ?? r.isOn) ? 1 : 0);
        });

        return SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
            child: Column(
              children: [
                _header(isOnline),
                const SizedBox(height: 10),
                _mainControls(dp, pcStatus, spStatus),
                const SizedBox(height: 10),
                _relayGrid(dp, plugs, rsMap, activeCount),
                const SizedBox(height: 10),
                _systemCommands(dp),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  HEADER  —  CRANTROL + status dot
  // ═════════════════════════════════════════════════════════════════════════
  Widget _header(bool online) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text.rich(
            TextSpan(
              style: GoogleFonts.orbitron(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
              children: const [
                TextSpan(text: 'CR',    style: TextStyle(color: _kTextPrimary)),
                TextSpan(text: 'A',     style: TextStyle(color: _kGreen)),
                TextSpan(text: 'NTROL', style: TextStyle(color: _kTextPrimary)),
              ],
            ),
          ),
          Container(
            width: 14, height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: online ? _kGreen : _kRed,
              boxShadow: [
                BoxShadow(
                  color: (online ? _kGreen : _kRed).withOpacity(0.65),
                  blurRadius: 10, spreadRadius: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  MAIN CONTROLS  —  PC  ·  SOS  ·  SP (with hold timers)
  // ═════════════════════════════════════════════════════════════════════════
  Widget _mainControls(
    DeviceProvider dp, RelayStatus pcSt, RelayStatus spSt,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kPanelBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 12, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Three circular controls ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _circularControl(
                  label: 'PC', sublabel: 'POWER',
                  isActive: pcSt.isOn || _isPCPressed,
                  accent: _kGreen,
                  isPressed: _isPCPressed,
                  onTapDown: () {
                    setState(() => _isPCPressed = true);
                    dp.setRelayStateDirect(widget.deviceId, 9, true);
                    HapticFeedback.mediumImpact();
                  },
                  onTapUp: () {
                    setState(() => _isPCPressed = false);
                    dp.setRelayStateDirect(widget.deviceId, 9, false);
                  },
                  onTapCancel: () {
                    setState(() => _isPCPressed = false);
                    dp.setRelayStateDirect(widget.deviceId, 9, false);
                  },
                ),
                _sosControl(dp),
                _circularControl(
                  label: 'SP', sublabel: 'POWER',
                  isActive: spSt.isOn || _isSPPressed,
                  accent: _kGreen,
                  isPressed: _isSPPressed,
                  onTapDown: () {
                    setState(() => _isSPPressed = true);
                    dp.setRelayStateDirect(widget.deviceId, 10, true);
                    HapticFeedback.mediumImpact();
                  },
                  onTapUp: () {
                    setState(() => _isSPPressed = false);
                    dp.setRelayStateDirect(widget.deviceId, 10, false);
                  },
                  onTapCancel: () {
                    setState(() => _isSPPressed = false);
                    dp.setRelayStateDirect(widget.deviceId, 10, false);
                  },
                ),
              ],
            ),
          ),
          // ── Hold timers (replace PULSE labels) ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _timerPill(
                    _relayTimer(dp, 9, pcSt.isOn || _isPCPressed),
                    _isPCPressed),
                _timerPill(
                    _relayTimer(dp, 10, spSt.isOn || _isSPPressed),
                    _isSPPressed),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Timer pill (replaces old PULSE labels) ─────────────────────────────
  Widget _timerPill(String time, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _kMetalDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? _kGreen.withOpacity(0.4) : _kPanelBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined,
            color: active ? _kGreen.withOpacity(0.7) : _kTextMuted,
            size: 10),
          const SizedBox(width: 4),
          Text(
            time,
            style: GoogleFonts.orbitron(
              color: active ? _kGreen : _kTextMuted,
              fontSize: 9,
              fontWeight: FontWeight.w600, letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ── Circular control (PC / SP) ─────────────────────────────────────────
  Widget _circularControl({
    required String label,
    required String sublabel,
    required bool isActive,
    required Color accent,
    required bool isPressed,
    required VoidCallback onTapDown,
    required VoidCallback onTapUp,
    required VoidCallback onTapCancel,
  }) {
    const double size = 90;
    return SizedBox(
      width: 105,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.power_settings_new,
            color: isActive ? accent : _kTextMuted,
            size: 14,
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTapDown: (_) => onTapDown(),
            onTapUp:   (_) => onTapUp(),
            onTapCancel:    onTapCancel,
            child: AnimatedScale(
              scale: isPressed ? 0.92 : 1.0,
              duration: const Duration(milliseconds: 80),
              child: Container(
                width: size, height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: [0, 0.35, 0.7, 1],
                    colors: [
                      _kMetalLight, _kMetalMid, _kMetalDark, Color(0xFF0A0E14),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 10, offset: const Offset(0, 5),
                    ),
                    if (isActive)
                      BoxShadow(
                        color: accent.withOpacity(0.35),
                        blurRadius: 22, spreadRadius: 4,
                      ),
                  ],
                ),
                padding: const EdgeInsets.all(5),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      radius: 0.85,
                      colors: [
                        isActive
                            ? accent.withOpacity(0.14)
                            : const Color(0xFF151C25),
                        const Color(0xFF0D1117),
                      ],
                    ),
                    border: Border.all(
                      color: isActive
                          ? accent.withOpacity(0.55)
                          : _kPanelBorder,
                      width: 2.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: GoogleFonts.orbitron(
                        color: isActive ? accent : _kTextMuted,
                        fontSize: 24, fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sublabel,
            style: GoogleFonts.orbitron(
              color: _kTextMuted, fontSize: 8,
              fontWeight: FontWeight.w700, letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  // ── SOS control ────────────────────────────────────────────────────────
  Widget _sosControl(DeviceProvider dp) {
    return SizedBox(
      width: 95,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 18),
          AnimatedBuilder(
            animation: _sosGlow,
            builder: (_, __) {
              final p = _sosGlow.value;
              return GestureDetector(
                onTapDown:  (_) => setState(() => _isSOSPressed = true),
                onTapUp: (_) {
                  setState(() => _isSOSPressed = false);
                  _doSOS(dp);
                },
                onTapCancel: () => setState(() => _isSOSPressed = false),
                child: AnimatedScale(
                  scale: _isSOSPressed ? 0.90 : 1.0,
                  duration: const Duration(milliseconds: 80),
                  child: Container(
                    width: 78, height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.lerp(
                            const Color(0xFF4A2020),
                            const Color(0xFF5A2828), p)!,
                          const Color(0xFF2A1010),
                          const Color(0xFF1A0808),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 10, offset: const Offset(0, 5),
                        ),
                        BoxShadow(
                          color: _kRed.withOpacity(0.18 + p * 0.22),
                          blurRadius: 22, spreadRadius: 4,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          radius: 0.85,
                          colors: [
                            _kRed.withOpacity(0.12 + p * 0.08),
                            const Color(0xFF1A0808),
                          ],
                        ),
                        border: Border.all(
                          color: _kRed.withOpacity(0.50 + p * 0.25),
                          width: 2.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'SOS',
                          style: GoogleFonts.orbitron(
                            color: _kRed, fontSize: 18,
                            fontWeight: FontWeight.w900, letterSpacing: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  RELAY GRID  —  relays 1-8 only
  // ═════════════════════════════════════════════════════════════════════════
  Widget _relayGrid(
    DeviceProvider dp,
    List<Relay> plugs,
    Map<int, RelayStatus> rsMap,
    int activeCount,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kPanelBorder),
      ),
      child: Column(
        children: [
          // ── header ─────────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.bolt, color: _kGreen, size: 14),
              const SizedBox(width: 5),
              Text(
                'RELAY CONTROLS',
                style: GoogleFonts.orbitron(
                  color: _kTextPrimary, fontSize: 11,
                  fontWeight: FontWeight.w700, letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                '$activeCount / 10 ACTIVE',
                style: GoogleFonts.orbitron(
                  color: _kGreen, fontSize: 9,
                  fontWeight: FontWeight.w600, letterSpacing: .5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                _kPanelBorder,
                Colors.transparent,
              ]),
            ),
          ),
          const SizedBox(height: 8),
          // ── 4×2 grid ───────────────────────────────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 0.55,
            ),
            itemCount: plugs.length,
            itemBuilder: (_, i) {
              final r  = plugs[i];
              final rs = rsMap[r.id] ?? RelayStatus.placeholder(r.id);
              final pending = dp.isRelayCommandPending(r.id);
              return _relayCard(
                relay: r, rs: rs, pending: pending,
                onTap: () {
                  if (r.enabled && !pending) {
                    dp.setRelayState(widget.deviceId, r.id, !rs.isOn);
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Single relay card ──────────────────────────────────────────────────
  Widget _relayCard({
    required Relay relay,
    required RelayStatus rs,
    required bool pending,
    required VoidCallback onTap,
  }) {
    final on = rs.isOn;
    // dp is available via closure from _relayGrid's caller
    final dp = Provider.of<DeviceProvider>(context, listen: false);
    final timer = _relayTimer(dp, relay.id, on);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: on ? _kGreen.withOpacity(0.30) : _kPanelBorder,
          ),
          boxShadow: on
              ? [BoxShadow(
                  color: _kGreen.withOpacity(0.08),
                  blurRadius: 8, spreadRadius: 1,
                )]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'R${relay.id}',
              style: GoogleFonts.orbitron(
                color: on ? _kGreen : _kGreen.withOpacity(0.45),
                fontSize: 13, fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              _relayName(relay.id, relay.name),
              textAlign: TextAlign.center,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.orbitron(
                color: _kTextMuted, fontSize: 6.5,
                fontWeight: FontWeight.w500, letterSpacing: .3,
              ),
            ),
            const SizedBox(height: 5),
            _industrialSwitch(on),
            const SizedBox(height: 4),
            if (timer.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(timer,
                    style: GoogleFonts.orbitron(
                      color: on
                          ? _kGreen.withOpacity(0.7)
                          : _kTextMuted.withOpacity(0.6),
                      fontSize: 7, fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.access_time,
                    color: on
                        ? _kGreen.withOpacity(0.5)
                        : _kTextMuted.withOpacity(0.4),
                    size: 8,
                  ),
                ],
              )
            else
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? _kGreen : _kRed.withOpacity(0.35),
                  boxShadow: on
                      ? [BoxShadow(
                          color: _kGreen.withOpacity(0.5),
                          blurRadius: 4, spreadRadius: 1,
                        )]
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Industrial toggle switch ───────────────────────────────────────────
  Widget _industrialSwitch(bool on) {
    return Container(
      width: 32, height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF090D14),
        border: Border.all(
          color: on ? _kGreen.withOpacity(0.40) : _kPanelBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 5, offset: const Offset(0, 2),
          ),
          if (on) BoxShadow(
            color: _kGreen.withOpacity(0.18),
            blurRadius: 10, spreadRadius: 1,
          ),
        ],
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        alignment: on ? Alignment.topCenter : Alignment.bottomCenter,
        child: Container(
          width: 24, height: 24,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: on
                  ? [_kGreen.withOpacity(0.80), _kGreen.withOpacity(0.35)]
                  : [const Color(0xFF3A4A5A), const Color(0xFF222E3A)],
            ),
            border: Border.all(
              color: on ? _kGreen.withOpacity(0.6) : const Color(0xFF4A5A6A),
            ),
            boxShadow: on
                ? [BoxShadow(
                    color: _kGreen.withOpacity(0.50),
                    blurRadius: 8, spreadRadius: 1,
                  )]
                : [BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 4, offset: const Offset(0, 2),
                  )],
          ),
          child: Center(
            child: Container(
              width: 10, height: 2,
              decoration: BoxDecoration(
                color: on ? Colors.white.withOpacity(0.9) : const Color(0xFF6A7A8A),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  SYSTEM COMMANDS  —  AUTO · ALERT · RESET (no header text, tighter)
  // ═════════════════════════════════════════════════════════════════════════
  Widget _systemCommands(DeviceProvider dp) {
    return Row(
      children: [
        Expanded(child: _cmdBtn(
          icon: Icons.warning_amber_rounded,
          label: 'AUTO', accent: _kAmber,
          loading: _isAutoRunning,
          onTap: _isAutoRunning ? null : () => _doAuto(dp),
        )),
        const SizedBox(width: 8),
        Expanded(child: _alertBtn(dp)),
        const SizedBox(width: 8),
        Expanded(child: _cmdBtn(
          icon: Icons.refresh_rounded,
          label: 'RESET', accent: _kBlue,
          onTap: () => _doReset(dp),
        )),
      ],
    );
  }

  Widget _cmdBtn({
    required IconData icon,
    required String label,
    required Color accent,
    bool loading = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withOpacity(0.22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 6, offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            if (loading)
              SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                  color: accent, strokeWidth: 2.5,
                ),
              )
            else
              Icon(icon, color: accent, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.orbitron(
                color: accent, fontSize: 10,
                fontWeight: FontWeight.w700, letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ALERT button (hold-to-beep) ────────────────────────────────────────
  Widget _alertBtn(DeviceProvider dp) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isAlertPressed = true);
        HapticFeedback.heavyImpact();
        dp.setBuzzerState(widget.deviceId, true);
      },
      onTapUp: (_) {
        setState(() => _isAlertPressed = false);
        dp.setBuzzerState(widget.deviceId, false);
      },
      onTapCancel: () {
        setState(() => _isAlertPressed = false);
        dp.setBuzzerState(widget.deviceId, false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _isAlertPressed ? _kRed.withOpacity(0.15) : _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isAlertPressed
                ? _kRed.withOpacity(0.5)
                : _kRed.withOpacity(0.22),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 6, offset: const Offset(0, 3),
            ),
            if (_isAlertPressed)
              BoxShadow(
                color: _kRed.withOpacity(0.20),
                blurRadius: 12, spreadRadius: 2,
              ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.notifications_active_rounded,
              color: _kRed, size: 24),
            const SizedBox(height: 6),
            Text(
              'ALERT',
              style: GoogleFonts.orbitron(
                color: _kRed, fontSize: 10,
                fontWeight: FontWeight.w700, letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  ACTION HANDLERS
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _doSOS(DeviceProvider dp) async {
    HapticFeedback.heavyImpact();

    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => AlertDialog(
        backgroundColor: _kPanel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: _kRed.withOpacity(0.35)),
        ),
        title: Row(children: [
          const Icon(Icons.warning_rounded, color: _kRed, size: 22),
          const SizedBox(width: 8),
          Text('EMERGENCY STOP',
            style: GoogleFonts.orbitron(
              color: _kRed, fontSize: 15, fontWeight: FontWeight.w900,
            ),
          ),
        ]),
        content: Text(
          'Turn OFF all relays 1-8 immediately?',
          style: GoogleFonts.orbitron(
            color: _kTextPrimary, fontSize: 12,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCEL',
              style: GoogleFonts.orbitron(
                color: _kTextMuted, fontSize: 11, fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('CONFIRM SOS',
              style: GoogleFonts.orbitron(
                color: _kRed, fontSize: 11, fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      await dp.toggleSOS(widget.deviceId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: _kGreen, size: 18),
            const SizedBox(width: 8),
            Text('SOS COMPLETE — Relays 1-8 OFF',
              style: GoogleFonts.orbitron(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600,
              ),
            ),
          ]),
          backgroundColor: _kPanel,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: _kGreen.withOpacity(0.3)),
          ),
          duration: const Duration(seconds: 2),
        ));
      }
    }
  }

  Future<void> _doAuto(DeviceProvider dp) async {
    if (_isAutoRunning) return;
    HapticFeedback.mediumImpact();
    setState(() { _isAutoRunning = true; _autoStep = 1; });

    try {
      // 1. Relay 1 + 2 ON
      await dp.setRelayState(widget.deviceId, 1, true);
      await dp.setRelayState(widget.deviceId, 2, true);

      if (!mounted) return;
      setState(() => _autoStep = 2);

      // 2. Wait 5 s
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() => _autoStep = 3);

      // 3. Pulse relay 9
      await dp.pulseRelay(widget.deviceId, 9);
      await Future.delayed(const Duration(seconds: 4));
    } finally {
      if (mounted) {
        setState(() { _isAutoRunning = false; _autoStep = 0; });
      }
    }
  }

  Future<void> _doReset(DeviceProvider dp) async {
    HapticFeedback.heavyImpact();

    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => AlertDialog(
        backgroundColor: _kPanel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: _kBlue.withOpacity(0.35)),
        ),
        title: Row(children: [
          const Icon(Icons.restart_alt_rounded, color: _kBlue, size: 22),
          const SizedBox(width: 8),
          Text('HARDWARE RESET',
            style: GoogleFonts.orbitron(
              color: _kBlue, fontSize: 15, fontWeight: FontWeight.w900,
            ),
          ),
        ]),
        content: Text(
          'Restart the ESP32 hardware module?',
          style: GoogleFonts.orbitron(
            color: _kTextPrimary, fontSize: 12,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCEL',
              style: GoogleFonts.orbitron(
                color: _kTextMuted, fontSize: 11, fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('RESTART',
              style: GoogleFonts.orbitron(
                color: _kBlue, fontSize: 11, fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      await dp.sendSystemCommand(widget.deviceId, 'RESTART');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.restart_alt_rounded, color: _kBlue, size: 18),
            const SizedBox(width: 8),
            Text('HARDWARE RESET SENT',
              style: GoogleFonts.orbitron(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700,
              ),
            ),
          ]),
          backgroundColor: _kPanel,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: _kBlue.withOpacity(0.3)),
          ),
          duration: const Duration(seconds: 3),
        ));
      }
    }
  }
}
