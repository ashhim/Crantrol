// ==========================================================================
// CRANTROL Power Sequence Service
//
// Single source of truth for the PC AUTO ON/OFF relay sequence timings.
// Used by DeviceProvider (foreground UI) and the background notification
// isolate so both paths execute the exact same steps.
//
// Hardware mapping (unchanged from firmware defaults — do not renumber):
//   Relay 1  = PC Power   (mains/PSU feed relay — authoritative PC state)
//   Relay 2  = paired with Relay 1 in the PC power sequence
//   Relay 9  = "Power"    (front-panel PC power-button simulate, hold/release)
// ==========================================================================

/// One step of a power sequence: set [relayId] to [turnOn], waiting
/// [delayBefore] before performing the action.
class PowerSequenceStep {
  final int relayId;
  final bool turnOn;
  final Duration delayBefore;

  const PowerSequenceStep({
    required this.relayId,
    required this.turnOn,
    this.delayBefore = Duration.zero,
  });
}

class PowerSequenceService {
  static const int kRelayPcMain = 1;
  static const int kRelaySecondaryMain = 2;
  static const int kRelayPcButton = 9;

  /// PC is OFF -> ON sequence:
  /// Turn ON Relay 1 + Relay 2, wait 6s, hold the PC power button for 3s,
  /// release it. Final state: PC ON.
  static List<PowerSequenceStep> onSequence() => const [
    PowerSequenceStep(relayId: kRelayPcMain, turnOn: true),
    PowerSequenceStep(relayId: kRelaySecondaryMain, turnOn: true),
    PowerSequenceStep(
      relayId: kRelayPcButton,
      turnOn: true,
      delayBefore: Duration(seconds: 6),
    ),
    PowerSequenceStep(
      relayId: kRelayPcButton,
      turnOn: false,
      delayBefore: Duration(seconds: 3),
    ),
  ];

  /// PC is ON -> OFF sequence:
  /// Hold the PC power button for 3s, release it, wait 15s, turn OFF
  /// Relay 1 + Relay 2. Final state: PC OFF.
  static List<PowerSequenceStep> offSequence() => const [
    PowerSequenceStep(relayId: kRelayPcButton, turnOn: true),
    PowerSequenceStep(
      relayId: kRelayPcButton,
      turnOn: false,
      delayBefore: Duration(seconds: 3),
    ),
    PowerSequenceStep(
      relayId: kRelayPcMain,
      turnOn: false,
      delayBefore: Duration(seconds: 15),
    ),
    PowerSequenceStep(relayId: kRelaySecondaryMain, turnOn: false),
  ];

  /// AUTO must not blindly toggle — inspect the current PC state (Relay 1)
  /// and run the matching sequence.
  static List<PowerSequenceStep> stepsFor({required bool pcCurrentlyOn}) {
    return pcCurrentlyOn ? offSequence() : onSequence();
  }

  /// 'ON' if this sequence will power the PC on, 'OFF' otherwise.
  static String kindFor({required bool pcCurrentlyOn}) =>
      pcCurrentlyOn ? 'OFF' : 'ON';
}
