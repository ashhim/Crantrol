import 'package:flutter_test/flutter_test.dart';
import 'package:applicatoin/models/device.dart';

void main() {
  test('normalizes relay config into ten relay slots with the new pin map', () {
    final relays = Device.relaysFromConfig({
      'relay1': {'id': 1, 'name': 'Relay 1', 'pin': 21, 'enabled': true},
      'relay10': {'id': 10, 'name': 'Relay 10', 'pin': 44, 'enabled': true},
    });

    expect(relays.length, 10);
    expect(relays[0].pin, 21);
    expect(relays[9].pin, 44);
    expect(relays[9].name, 'Relay 10');
  });

  test(
    'treats relay 9 and 10 as pulse relays while keeping plugs 1-8 as normal controls',
    () {
      expect(isPulseRelay(9), isTrue);
      expect(isPulseRelay(10), isTrue);
      expect(isPulseRelay(1), isFalse);
      expect(isPulseRelay(8), isFalse);
    },
  );

  test('preserves GPIO0 as a real pin value when resolving relay pins', () {
    expect(resolveRelayPin(0, 21), 0);
    expect(resolveRelayPin(null, 21), 21);
  });

  test(
    'marks device offline when connectivity flags are false even if heartbeat is fresh',
    () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final status = DeviceStatus.fromJson({
        'deviceId': 'device_001',
        'heartbeatAt': now,
        'lastSeenAt': now,
        'ethernetLinked': true,
        'internetOk': false,
        'firebaseAuthenticated': true,
        'relays': {},
      });

      expect(status.isOnline, isFalse);
    },
  );

  test(
    'marks device online only when ethernet, internet, and firebase are all healthy',
    () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final status = DeviceStatus.fromJson({
        'deviceId': 'device_001',
        'heartbeatAt': now,
        'lastSeenAt': now,
        'ethernetLinked': true,
        'internetOk': true,
        'firebaseAuthenticated': true,
        'relays': {},
      });

      expect(status.isOnline, isTrue);
    },
  );
}
