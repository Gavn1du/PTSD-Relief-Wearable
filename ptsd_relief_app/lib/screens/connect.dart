import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ptsd_relief_app/services/auth.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  static const String _deviceName = 'VitalLink Helper';
  static const String _uartServiceUuid = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String _rxUuid = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String _txUuid = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E';

  final NetworkInfo info = NetworkInfo();
  final TextEditingController wifiPasswordController = TextEditingController();

  StreamSubscription<List<ScanResult>>? scanSubscription;
  Timer? scanTimer;

  List<ScanResult> nearbyDevices = [];
  bool isScanning = false;
  bool isConnecting = false;
  String? connectingDeviceId;
  String wifiSSID = '';
  String statusMessage =
      'Tap "Scan Nearby Devices" to look for your VitalLink Helper.';

  @override
  void initState() {
    super.initState();
    _loadWifiName();
    _listenForNearbyDevices();
  }

  Future<void> _loadWifiName() async {
    final ssid = (await info.getWifiName() ?? '').replaceAll('"', '');
    if (!mounted) return;
    setState(() {
      wifiSSID = ssid;
    });
  }

  void _listenForNearbyDevices() {
    scanSubscription?.cancel();
    scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      bool addedDevice = false;

      for (final result in results) {
        if (!_isSupportedDevice(result)) {
          continue;
        }

        final alreadyTracked = nearbyDevices.any(
          (device) =>
              device.device.remoteId.toString() ==
              result.device.remoteId.toString(),
        );

        if (alreadyTracked) {
          continue;
        }

        addedDevice = true;
        setState(() {
          nearbyDevices = [...nearbyDevices, result];
          statusMessage =
              'Device found nearby. Tap it below to connect and finish setup.';
        });
      }

      if (addedDevice) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nearby device found. Tap it below to connect.'),
          ),
        );
        _finishScan(foundDevice: true);
      }
    });
  }

  bool _isSupportedDevice(ScanResult result) {
    final advertisedName =
        result.advertisementData.advName.trim().toLowerCase();
    final platformName = result.device.platformName.trim().toLowerCase();
    return advertisedName.contains('vitallink') ||
        platformName.contains('vitallink');
  }

  String _displayName(ScanResult result) {
    final advertisedName = result.advertisementData.advName.trim();
    final platformName = result.device.platformName.trim();
    if (advertisedName.isNotEmpty) {
      return advertisedName;
    }
    if (platformName.isNotEmpty) {
      return platformName;
    }
    return _deviceName;
  }

  String _signalStrengthLabel(int rssi) {
    if (rssi >= -60) {
      return 'Strong signal';
    }
    if (rssi >= -75) {
      return 'Nearby';
    }
    return 'Weak signal';
  }

  Future<bool> _requestBluetoothPermissions() async {
    final statuses =
        await [
          Permission.bluetooth,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.locationWhenInUse,
        ].request();

    final hasModernAndroidBluetooth =
        (statuses[Permission.bluetoothScan]?.isGranted ?? false) &&
        (statuses[Permission.bluetoothConnect]?.isGranted ?? false);
    final hasGeneralBluetooth =
        statuses[Permission.bluetooth]?.isGranted ?? false;
    final hasLegacyScanPermission =
        statuses[Permission.locationWhenInUse]?.isGranted ?? false;

    if (hasModernAndroidBluetooth ||
        hasGeneralBluetooth ||
        hasLegacyScanPermission) {
      return true;
    }

    final permanentlyDenied = statuses.values.any(
      (status) => status.isPermanentlyDenied || status.isRestricted,
    );

    if (!mounted) return false;

    setState(() {
      statusMessage =
          permanentlyDenied
              ? 'Bluetooth access is blocked. Open Settings and allow Bluetooth to connect your device.'
              : 'Bluetooth permission is needed before we can scan for your VitalLink Helper.';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          permanentlyDenied
              ? 'Bluetooth access is blocked. Enable it in Settings.'
              : 'Please allow Bluetooth access to scan nearby devices.',
        ),
        action:
            permanentlyDenied
                ? SnackBarAction(label: 'Settings', onPressed: openAppSettings)
                : null,
      ),
    );

    return false;
  }

  Future<bool> _ensureBluetoothIsOn() async {
    final adapterState = await FlutterBluePlus.adapterState.first;

    if (adapterState == BluetoothAdapterState.on) {
      return true;
    }

    if (!mounted) return false;

    setState(() {
      statusMessage =
          'Bluetooth is turned off. Turn it on to scan nearby devices.';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Turn on Bluetooth to scan nearby devices.'),
      ),
    );

    return false;
  }

  Future<void> _startScan() async {
    FocusScope.of(context).unfocus();
    scanTimer?.cancel();

    final hasPermissions = await _requestBluetoothPermissions();
    if (!hasPermissions) return;

    final bluetoothReady = await _ensureBluetoothIsOn();
    if (!bluetoothReady) return;

    await FlutterBluePlus.stopScan();

    if (!mounted) return;
    setState(() {
      nearbyDevices = [];
      isScanning = true;
      statusMessage = 'Scanning the area for nearby VitalLink devices...';
    });

    scanTimer = Timer(const Duration(seconds: 6), () {
      _finishScan();
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));
    } catch (error) {
      scanTimer?.cancel();
      if (!mounted) return;
      setState(() {
        isScanning = false;
        statusMessage =
            'Bluetooth scan could not start. Please check Bluetooth permissions and try again.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not start Bluetooth scan. Check Bluetooth access and try again.',
          ),
        ),
      );
    }
  }

  Future<void> _finishScan({bool foundDevice = false}) async {
    scanTimer?.cancel();
    await FlutterBluePlus.stopScan();

    if (!mounted) return;
    setState(() {
      isScanning = false;
      if (nearbyDevices.isNotEmpty || foundDevice) {
        statusMessage =
            'Device found nearby. Tap it below to connect and finish setup.';
      } else {
        statusMessage =
            'No VitalLink device was found nearby. Move closer and scan again.';
      }
    });
  }

  Future<void> _connectToDevice(ScanResult result) async {
    final device = result.device;
    final deviceId = device.remoteId.toString();

    FocusScope.of(context).unfocus();
    await FlutterBluePlus.stopScan();

    if (!mounted) return;
    setState(() {
      isScanning = false;
      isConnecting = true;
      connectingDeviceId = deviceId;
      statusMessage = 'Connecting to ${_displayName(result)}...';
    });

    try {
      try {
        await device.connect();
      } catch (error) {
        final message = error.toString().toLowerCase();
        if (!message.contains('already')) {
          rethrow;
        }
      }

      await _loadWifiName();

      final currentSsid = (await info.getWifiName() ?? '').replaceAll('"', '');
      final wifiData = {
        'ssid': currentSsid,
        'password': wifiPasswordController.text,
        'uid': Auth().user?.uid ?? '',
      };

      final services = await device.discoverServices();
      final uartService = _findService(services, _uartServiceUuid);
      if (uartService == null) {
        throw Exception('Compatible device service not found.');
      }

      final rx = _findCharacteristic(uartService, _rxUuid);
      final tx = _findCharacteristic(uartService, _txUuid);

      if (rx == null || tx == null) {
        throw Exception('Could not open the device communication channel.');
      }

      await tx.setNotifyValue(true);
      tx.lastValueStream.listen((value) {
        if (!mounted || value.isEmpty) return;
        final response = utf8.decode(value).trim();
        if (response.isEmpty) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(response)));
      });

      await _writeChunked(rx, utf8.encode(jsonEncode(wifiData)));

      if (!mounted) return;
      setState(() {
        statusMessage =
            'Connected to ${_displayName(result)}. Wi-Fi details were sent to the device.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to ${_displayName(result)} successfully.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        statusMessage =
            'Connection failed. Please scan again and try reconnecting.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not connect to the device: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isConnecting = false;
          connectingDeviceId = null;
        });
      }
    }
  }

  BluetoothService? _findService(List<BluetoothService> services, String uuid) {
    for (final service in services) {
      if (service.uuid.toString().toUpperCase() == uuid) {
        return service;
      }
    }
    return null;
  }

  BluetoothCharacteristic? _findCharacteristic(
    BluetoothService service,
    String uuid,
  ) {
    for (final characteristic in service.characteristics) {
      if (characteristic.uuid.toString().toUpperCase() == uuid) {
        return characteristic;
      }
    }
    return null;
  }

  Future<void> _writeChunked(
    BluetoothCharacteristic characteristic,
    List<int> data, {
    int chunkSize = 20,
  }) async {
    for (int i = 0; i < data.length; i += chunkSize) {
      final end = (i + chunkSize < data.length) ? i + chunkSize : data.length;
      await characteristic.write(data.sublist(i, end), withoutResponse: true);
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  Widget _buildStatusCard(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor =
        isConnecting
            ? theme.colorScheme.primary
            : nearbyDevices.isNotEmpty
            ? Colors.green
            : theme.colorScheme.secondary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isConnecting
                  ? Icons.bluetooth_connected
                  : isScanning
                  ? Icons.radar
                  : nearbyDevices.isNotEmpty
                  ? Icons.check_circle
                  : Icons.bluetooth_searching,
              color: statusColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(statusMessage, style: theme.textTheme.bodyLarge),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, ScanResult result) {
    final deviceId = result.device.remoteId.toString();
    final isThisDeviceConnecting =
        isConnecting && connectingDeviceId == deviceId;

    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.memory)),
        title: Text(_displayName(result)),
        subtitle: Text(
          '${_signalStrengthLabel(result.rssi)}\n${result.device.remoteId}',
        ),
        isThreeLine: true,
        trailing:
            isThisDeviceConnecting
                ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : ElevatedButton(
                  onPressed:
                      isConnecting ? null : () => _connectToDevice(result),
                  child: const Text('Connect'),
                ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detectedWifi = wifiSSID.isEmpty ? 'Not detected' : wifiSSID;

    return Scaffold(
      appBar: AppBar(title: const Text('Connect Device')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusCard(context),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step 1: Scan nearby devices',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We will look around for your VitalLink Helper and show it here when it is found. You do not need to type the device name.',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isScanning || isConnecting ? null : _startScan,
                      icon:
                          isScanning
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(Icons.bluetooth_searching),
                      label: Text(
                        isScanning
                            ? 'Scanning Nearby...'
                            : 'Scan Nearby Devices',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step 2: Send Wi-Fi details',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('Current Wi-Fi: $detectedWifi'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: wifiPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Wi-Fi password',
                      border: OutlineInputBorder(),
                      helperText:
                          'Used to help the device join the same network.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Nearby Devices',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (nearbyDevices.isEmpty && !isScanning)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No compatible devices are listed yet. Start a scan and keep the device nearby.',
                ),
              ),
            ),
          ...nearbyDevices.map((result) => _buildDeviceCard(context, result)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    scanTimer?.cancel();
    scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    wifiPasswordController.dispose();
    super.dispose();
  }
}
