// ==========================================================================
// CRANTROL Schedule Countdown Badge
//
// Compact red countdown chip shown on a relay tile / AUTO button / sequence
// card that has an active schedule. Stateless — the remaining Duration is
// recomputed from ScheduleEntry.targetAt each time the parent screen's
// existing 1-second UI ticker rebuilds it (the same pattern already used
// for relay hold timers), so it never runs its own timer or touches Firebase.
// ==========================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/device.dart';

const _kRed = Color(0xFFFF1744);

class ScheduleCountdownBadge extends StatelessWidget {
  final ScheduleEntry entry;
  final double fontSize;

  const ScheduleCountdownBadge({
    required this.entry,
    this.fontSize = 8,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = entry.remaining;
    final h = remaining.inHours.toString().padLeft(2, '0');
    final m = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    final text = remaining.inHours > 0 ? '$h:$m:$s' : '$m:$s';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _kRed.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kRed.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, color: _kRed, size: fontSize + 1),
          const SizedBox(width: 3),
          Text(
            text,
            style: GoogleFonts.orbitron(
              color: _kRed,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
