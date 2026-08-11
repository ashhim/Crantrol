import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/device.dart';
import '../providers/device_provider.dart';
import '../services/background_service_controller.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  final String deviceId;

  const SettingsScreen({required this.deviceId, super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _deviceNameController;
  late final TextEditingController _roomIdController;

  final Map<int, TextEditingController> _nameControllers = {};
  final Map<int, TextEditingController> _pinControllers = {};
  final Map<int, TextEditingController> _pulseControllers = {};
  final Map<int, bool> _activeLows = {};
  final Map<int, bool> _isPulses = {};
  final Map<int, bool> _enableds = {};

  String? _loadedDeviceId;
  bool _seedPending = false;

  @override
  void initState() {
    super.initState();
    _deviceNameController = TextEditingController();
    _roomIdController = TextEditingController();
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    _roomIdController.dispose();

    for (final controller in _nameControllers.values) {
      controller.dispose();
    }
    for (final controller in _pinControllers.values) {
      controller.dispose();
    }
    for (final controller in _pulseControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  void _seedControllers(Device device, {bool force = false}) {
    if (!force && _loadedDeviceId == device.deviceId) {
      return;
    }

    _loadedDeviceId = device.deviceId;
    _deviceNameController.text = device.deviceName;
    _roomIdController.text = device.roomId;

    for (final relay in device.relays) {
      final nameController = _nameControllers.putIfAbsent(
        relay.id,
        () => TextEditingController(),
      );
      final pinController = _pinControllers.putIfAbsent(
        relay.id,
        () => TextEditingController(),
      );
      final pulseController = _pulseControllers.putIfAbsent(
        relay.id,
        () => TextEditingController(),
      );

      if (force || nameController.text.isEmpty) {
        nameController.text = relay.name;
      }
      if (force || pinController.text.isEmpty) {
        pinController.text = relay.pin.toString();
      }
      if (force || pulseController.text.isEmpty) {
        pulseController.text = relay.pulseDurationMs.toString();
      }

      _activeLows[relay.id] = relay.activeLow;
      _isPulses[relay.id] = relay.isPulse;
      _enableds[relay.id] = relay.enabled;
    }
  }

  void _ensureSeeded(Device device) {
    if (_loadedDeviceId == device.deviceId || _seedPending) {
      return;
    }

    _seedPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _seedControllers(device, force: true);
        _seedPending = false;
      });
    });
  }

  TextEditingController _controllerFor(
    Map<int, TextEditingController> controllers,
    int relayId,
  ) {
    final controller = controllers[relayId];
    if (controller == null) {
      throw StateError('Relay controller missing for id $relayId');
    }
    return controller;
  }

  Future<void> _saveSettings(BuildContext context) async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final device = deviceProvider.selectedDevice;
    if (device == null) {
      return;
    }

    final Map<String, Map<String, dynamic>> relayConfigs = {};
    for (final relay in device.relays) {
      final id = relay.id;
      final name = _controllerFor(_nameControllers, id).text.trim();
      final pinText = _controllerFor(_pinControllers, id).text.trim();
      final pulseText = _controllerFor(_pulseControllers, id).text.trim();
      final pulseValue = int.tryParse(pulseText) ?? relay.pulseDurationMs;
      final relayPin = int.tryParse(pinText) ?? relay.pin;

      relayConfigs['relay$id'] = {
        'id': id,
        'name': name.isEmpty ? relay.name : name,
        'pin': relayPin,
        'activeLow': _activeLows[id] ?? relay.activeLow,
        'isPulse': _isPulses[id] ?? relay.isPulse,
        'pulseMs': pulseValue,
        'pulseDurationMs': pulseValue,
        'enabled': _enableds[id] ?? relay.enabled,
        'state': relay.isOn,
      };
    }

    final config = <String, dynamic>{
      'deviceName': _deviceNameController.text.trim(),
      'deviceId': device.deviceId,
      'roomId': _roomIdController.text.trim(),
      'roomCode': device.roomCode,
      'relayCount': kMaxRelaySlots,
      'relays': relayConfigs,
    };

    try {
      await deviceProvider.updateDeviceConfig(widget.deviceId, config);
      await deviceProvider.selectDevice(widget.deviceId);

      final refreshedDevice = deviceProvider.selectedDevice;
      if (mounted && refreshedDevice != null) {
        setState(() {
          _seedControllers(refreshedDevice, force: true);
        });
      }

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await BackgroundServiceController.stop();
      await NotificationService.cancel();
      await FirebaseService().signOut();
      if (mounted) {
        navigator.pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed:
                () => Provider.of<DeviceProvider>(
                  context,
                  listen: false,
                ).selectDevice(widget.deviceId),
          ),
        ],
      ),
      body: Consumer<DeviceProvider>(
        builder: (context, deviceProvider, _) {
          final device = deviceProvider.selectedDevice;
          if (device == null) {
            return const Center(child: Text('Device not found'));
          }

          if (_loadedDeviceId != device.deviceId) {
            _ensureSeeded(device);
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF5EEAD4)),
            );
          }

          final relays = [...device.relays]
            ..sort((a, b) => a.id.compareTo(b.id));

          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                              'DEVICE CONFIGURATION',
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(
                                color: const Color(0xFF5EEAD4),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _deviceNameController,
                              decoration: const InputDecoration(
                                labelText: 'Device Name',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _roomIdController,
                              decoration: const InputDecoration(
                                labelText: 'Room ID',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: relays.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final relay = relays[index];
                          final nameController = _controllerFor(
                            _nameControllers,
                            relay.id,
                          );
                          final pinController = _controllerFor(
                            _pinControllers,
                            relay.id,
                          );
                          final pulseController = _controllerFor(
                            _pulseControllers,
                            relay.id,
                          );
                          final activeLow =
                              _activeLows[relay.id] ?? relay.activeLow;
                          final isPulse = _isPulses[relay.id] ?? relay.isPulse;
                          final enabled = _enableds[relay.id] ?? relay.enabled;

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0B1220),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFF1F2937),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Relay ${relay.id}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'GPIO ${relay.pin}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.labelSmall?.copyWith(
                                              color: const Color(0xFF5EEAD4),
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
                                            enabled
                                                ? const Color(0xFF14532D)
                                                : const Color(0xFF475569),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        enabled ? 'ENABLED' : 'DISABLED',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Relay Name',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: pinController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'GPIO Pin',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: SwitchListTile(
                                        title: const Text(
                                          'Active Low',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        value: activeLow,
                                        contentPadding: EdgeInsets.zero,
                                        onChanged: (val) {
                                          setState(() {
                                            _activeLows[relay.id] = val;
                                          });
                                        },
                                      ),
                                    ),
                                    Expanded(
                                      child: SwitchListTile(
                                        title: const Text(
                                          'Enabled',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        value: enabled,
                                        contentPadding: EdgeInsets.zero,
                                        onChanged: (val) {
                                          setState(() {
                                            _enableds[relay.id] = val;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                SwitchListTile(
                                  title: const Text(
                                    'Pulse Control',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  value: isPulse,
                                  contentPadding: EdgeInsets.zero,
                                  onChanged: (val) {
                                    setState(() {
                                      _isPulses[relay.id] = val;
                                    });
                                  },
                                ),
                                if (isPulse) ...[
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: pulseController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Pulse Duration (ms)',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => _saveSettings(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5EEAD4),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Save Settings',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B1220),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF1F2937)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'About CRANTROL',
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'CRANTROL is the command center for your CRANTROL-compatible power relay system.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Version: 1.0.0',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // ── Logout button ──────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () => _logout(context),
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text(
                            'Logout',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF991B1B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
