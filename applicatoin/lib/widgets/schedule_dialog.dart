// ==========================================================================
// CRANTROL Scheduler Dialog
//
// Opened on long-press of a relay tile, the AUTO button, or the PC/SP
// schedule icon. Opens directly as a calendar + clock picker — a date field
// (defaults to today, tap to pick any future date) and a time field (tap to
// pick an exact hour/minute/AM-PM) — no quick-delay chips or "IN.../AT TIME"
// mode selector. Stores a single target timestamp in Firebase
// (devices/{id}/schedules/{key}). No per-second writes — every client
// computes the live countdown locally from that timestamp.
// ==========================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/device.dart';
import '../providers/device_provider.dart';

const _kPanel = Color(0xFF0C1018);
const _kPanelBorder = Color(0xFF1A2332);
const _kCard = Color(0xFF111820);
const _kGreen = Color(0xFF00E676);
const _kRed = Color(0xFFFF1744);
const _kAmber = Color(0xFFD4A017);
const _kTextPrimary = Color(0xFFE0E0E0);
const _kTextMuted = Color(0xFF5A6A7A);

Future<void> showSchedulerDialog(
  BuildContext context, {
  required String deviceId,
  required String scheduleKey,
  required String label,
  bool showOnOffToggle = true,
  bool defaultTurnOn = true,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder:
        (_) => _SchedulerDialog(
          deviceId: deviceId,
          scheduleKey: scheduleKey,
          label: label,
          showOnOffToggle: showOnOffToggle,
          defaultTurnOn: defaultTurnOn,
        ),
  );
}

class _SchedulerDialog extends StatefulWidget {
  final String deviceId;
  final String scheduleKey;
  final String label;
  final bool showOnOffToggle;
  final bool defaultTurnOn;

  const _SchedulerDialog({
    required this.deviceId,
    required this.scheduleKey,
    required this.label,
    required this.showOnOffToggle,
    required this.defaultTurnOn,
  });

  @override
  State<_SchedulerDialog> createState() => _SchedulerDialogState();
}

class _SchedulerDialogState extends State<_SchedulerDialog> {
  late DateTime _pickedDate = _today();
  TimeOfDay? _pickedTime;
  late bool _turnOn = widget.defaultTurnOn;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Computed target timestamp — null until a time is picked. Date defaults
  /// to today unless the operator picks a different one via the calendar.
  DateTime? _computeTarget() {
    final time = _pickedTime;
    if (time == null) return null;
    return DateTime(
      _pickedDate.year,
      _pickedDate.month,
      _pickedDate.day,
      time.hour,
      time.minute,
    );
  }

  /// True when the computed target is today at a time that has already
  /// passed — past dates are already excluded by the calendar's firstDate,
  /// this catches the "today but an earlier hour" case.
  bool _isPastTarget(DateTime target) => !target.isAfter(DateTime.now());

  ThemeData _pickerTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      colorScheme: const ColorScheme.dark(
        primary: _kGreen,
        surface: _kPanel,
        onSurface: _kTextPrimary,
      ),
    );
  }

  Future<void> _pickDate() async {
    final today = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickedDate.isBefore(today) ? today : _pickedDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      builder: (context, child) =>
          Theme(data: _pickerTheme(context), child: child!),
    );
    if (picked != null) {
      setState(() => _pickedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _pickedTime ?? TimeOfDay.now(),
      builder: (context, child) =>
          Theme(data: _pickerTheme(context), child: child!),
    );
    if (picked != null) {
      setState(() => _pickedTime = picked);
    }
  }

  /// "Today" / "Tomorrow" / "25 August 2026" — never a bare weekday-less
  /// numeric date, so the operator always knows exactly which day is picked.
  String _dateLabel(DateTime date) {
    final today = _today();
    final diff = date.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return DateFormat('d MMMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DeviceProvider>();
    final existing = dp.scheduleFor(widget.scheduleKey);
    final target = _computeTarget();

    return AlertDialog(
      backgroundColor: _kPanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: _kAmber.withOpacity(0.35)),
      ),
      title: Row(
        children: [
          const Icon(Icons.schedule, color: _kAmber, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'SCHEDULE ${widget.label}',
              style: GoogleFonts.orbitron(
                color: _kAmber,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (existing != null) ...[
                _existingScheduleBanner(existing),
                const SizedBox(height: 16),
              ],
              _dateRow(),
              const SizedBox(height: 10),
              _timeRow(),
              if (widget.showOnOffToggle) ...[
                const SizedBox(height: 16),
                _onOffToggle(),
              ],
              if (target != null) ...[
                const SizedBox(height: 16),
                _isPastTarget(target)
                    ? _pastTimeWarning()
                    : _targetPreview(target),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (existing != null)
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await dp.cancelSchedule(widget.deviceId, widget.scheduleKey);
            },
            child: Text(
              'CANCEL SCHEDULE',
              style: GoogleFonts.orbitron(
                color: _kRed,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'CLOSE',
            style: GoogleFonts.orbitron(
              color: _kTextMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed:
              (target == null || _isPastTarget(target))
                  ? null
                  : () async {
                    Navigator.pop(context);
                    await dp.setSchedule(
                      widget.deviceId,
                      widget.scheduleKey,
                      targetAt: target,
                      action:
                          widget.showOnOffToggle
                              ? (_turnOn ? 'ON' : 'OFF')
                              : null,
                    );
                  },
          style: ElevatedButton.styleFrom(
            backgroundColor: _kAmber,
            foregroundColor: Colors.black,
          ),
          child: Text(
            'SET SCHEDULE',
            style: GoogleFonts.orbitron(
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _existingScheduleBanner(ScheduleEntry entry) {
    final remaining = entry.remaining;
    final h = remaining.inHours.toString().padLeft(2, '0');
    final m = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kRed.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer, color: _kRed, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ALREADY SCHEDULED',
                  style: GoogleFonts.orbitron(
                    color: _kTextMuted,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  '$h:$m:$s remaining'
                  '${entry.action != null ? ' · target ${entry.action}' : ''}',
                  style: GoogleFonts.orbitron(
                    color: _kRed,
                    fontSize: 12,
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

  Widget _dateRow() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kPanelBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: _kAmber, size: 16),
            const SizedBox(width: 10),
            Text(
              _dateLabel(_pickedDate),
              style: GoogleFonts.orbitron(
                color: _kTextPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: _kTextMuted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _segmentButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _kAmber.withOpacity(0.15) : _kCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _kAmber : _kPanelBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.orbitron(
            color: selected ? _kAmber : _kTextMuted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _timeRow() {
    return GestureDetector(
      onTap: _pickTime,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kPanelBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: _kAmber, size: 18),
            const SizedBox(width: 10),
            Text(
              _pickedTime == null
                  ? 'Pick a clock time'
                  : _pickedTime!.format(context),
              style: GoogleFonts.orbitron(
                color: _pickedTime == null ? _kTextMuted : _kTextPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: _kTextMuted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _pastTimeWarning() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _kRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _kRed, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'That time has already passed today — pick a later time or a future date.',
              style: GoogleFonts.orbitron(
                color: _kRed,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _onOffToggle() {
    return Row(
      children: [
        Expanded(
          child: _segmentButton(
            label: 'TARGET OFF',
            selected: !_turnOn,
            onTap: () => setState(() => _turnOn = false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _segmentButton(
            label: 'TARGET ON',
            selected: _turnOn,
            onTap: () => setState(() => _turnOn = true),
          ),
        ),
      ],
    );
  }

  Widget _targetPreview(DateTime target) {
    final hh = target.hour.toString().padLeft(2, '0');
    final mm = target.minute.toString().padLeft(2, '0');
    final dateLabel = _dateLabel(DateTime(target.year, target.month, target.day));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _kGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available, color: _kGreen, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Will fire at $hh:$mm · $dateLabel',
              style: GoogleFonts.orbitron(
                color: _kGreen,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
