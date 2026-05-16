import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:ptsd_relief_app/services/auth.dart';
import 'package:ptsd_relief_app/services/bluetooth_connection.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  static const String _deviceName = 'VitalLink Helper';
  final NetworkInfo info = NetworkInfo();
  final TextEditingController wifiSsidController = TextEditingController();
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
    await _requestWifiNamePermission();
    final ssid = (await info.getWifiName() ?? '').replaceAll('"', '');
    if (!mounted) return;
    setState(() {
      wifiSSID = ssid;
      if (ssid.isNotEmpty && wifiSsidController.text.trim().isEmpty) {
        wifiSsidController.text = ssid;
      }
    });
  }

  Future<void> _requestWifiNamePermission() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        final status = await Permission.locationWhenInUse.status;
        if (!status.isGranted && !status.isPermanentlyDenied) {
          await Permission.locationWhenInUse.request();
        }
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return;
    }
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

    print(
      'Device found: advertisedName="$advertisedName", platformName="$platformName"',
    );

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

  Future<bool> _requestBluetoothPermissions({
    String permissionAction = 'scan for your VitalLink Helper',
  }) async {
    final statuses = await _requestPlatformBluetoothPermissions();
    debugPrint('Bluetooth permission check: $statuses');

    if (_hasRequiredBluetoothPermissions(statuses)) {
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
              : 'Bluetooth permission is needed before we can $permissionAction.';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          permanentlyDenied
              ? 'Bluetooth access is blocked. Enable it in Settings.'
              : 'Please allow Bluetooth access to $permissionAction.',
        ),
        action:
            permanentlyDenied
                ? SnackBarAction(label: 'Settings', onPressed: openAppSettings)
                : null,
      ),
    );

    return false;
  }

  Future<Map<Permission, PermissionStatus>>
  _requestPlatformBluetoothPermissions() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.locationWhenInUse,
        ].request();
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return {Permission.bluetooth: await Permission.bluetooth.request()};
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return const {};
    }
  }

  bool _hasRequiredBluetoothPermissions(
    Map<Permission, PermissionStatus> statuses,
  ) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final hasModernAndroidBluetooth =
            (statuses[Permission.bluetoothScan]?.isGranted ?? false) &&
            (statuses[Permission.bluetoothConnect]?.isGranted ?? false);
        final hasLegacyScanPermission =
            statuses[Permission.locationWhenInUse]?.isGranted ?? false;
        return hasModernAndroidBluetooth || hasLegacyScanPermission;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return statuses[Permission.bluetooth]?.isGranted ?? false;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return true;
    }
  }

  Future<bool> _ensureBluetoothIsOn() async {
    final adapterState = await _settledBluetoothAdapterState();
    debugPrint('Bluetooth adapter state: $adapterState');

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

  Future<BluetoothAdapterState> _settledBluetoothAdapterState() async {
    var adapterState = await FlutterBluePlus.adapterState.first;

    if (adapterState != BluetoothAdapterState.unknown &&
        adapterState != BluetoothAdapterState.turningOn &&
        adapterState != BluetoothAdapterState.turningOff) {
      return adapterState;
    }

    try {
      adapterState = await FlutterBluePlus.adapterState
          .where(
            (state) =>
                state != BluetoothAdapterState.unknown &&
                state != BluetoothAdapterState.turningOn &&
                state != BluetoothAdapterState.turningOff,
          )
          .first
          .timeout(const Duration(seconds: 1));
    } on TimeoutException {
      // Keep the latest transient state if the native adapter does not settle.
    }

    return adapterState;
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

    final hasPermissions = await _requestBluetoothPermissions(
      permissionAction: 'connect to your VitalLink Helper',
    );
    if (!hasPermissions) return;

    final bluetoothReady = await _ensureBluetoothIsOn();
    if (!bluetoothReady) return;

    await _loadWifiName();
    final detectedSsid = (await info.getWifiName() ?? '').replaceAll('"', '');
    final currentSsid =
        wifiSsidController.text.trim().isNotEmpty
            ? wifiSsidController.text.trim()
            : detectedSsid.trim();
    final uid = Auth().user?.uid ?? '';

    if (currentSsid.isEmpty || uid.isEmpty) {
      final missingValues = [
        if (currentSsid.isEmpty) 'Wi-Fi network name',
        if (uid.isEmpty) 'signed-in user',
      ].join(' and ');

      if (!mounted) return;
      setState(() {
        statusMessage = 'Missing $missingValues before setup can continue.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Missing $missingValues before setup.')),
      );
      return;
    }

    await FlutterBluePlus.stopScan();

    if (!mounted) return;
    setState(() {
      isScanning = false;
      isConnecting = true;
      connectingDeviceId = deviceId;
      statusMessage = 'Connecting to ${_displayName(result)}...';
    });

    try {
      final response = await context
          .read<BluetoothConnectionService>()
          .provision(
            device,
            ssid: currentSsid,
            password: wifiPasswordController.text,
            uid: uid,
          );

      if (!mounted) return;
      setState(() {
        statusMessage = 'Connected to ${_displayName(result)}. $response';
        print('Device response: $response');
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(response)));
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

  Widget _buildStatusCard(BuildContext context) {
    final theme = Theme.of(context);
    final bluetooth = context.watch<BluetoothConnectionService>();
    final statusColor =
        isConnecting
            ? theme.colorScheme.primary
            : bluetooth.isConnected
            ? Colors.green
            : nearbyDevices.isNotEmpty
            ? Colors.green
            : theme.colorScheme.secondary;
    final displayedStatus =
        bluetooth.isConnected && !isConnecting
            ? 'Connected to ${bluetooth.connectedDeviceName}. Receiving live heart rate updates.'
            : statusMessage;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isConnecting
                  ? Icons.bluetooth_connected
                  : bluetooth.isConnected
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
              child: Text(displayedStatus, style: theme.textTheme.bodyLarge),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, ScanResult result) {
    final bluetooth = context.watch<BluetoothConnectionService>();
    final deviceId = result.device.remoteId.toString();
    final isThisDeviceConnecting =
        (isConnecting || bluetooth.isConnecting) &&
        connectingDeviceId == deviceId;
    final isThisDeviceConnected = bluetooth.isConnectedTo(result.device);

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
                : isThisDeviceConnected
                ? const ElevatedButton(
                  onPressed: null,
                  child: Text('Connected'),
                )
                : ElevatedButton(
                  onPressed:
                      isConnecting || bluetooth.isConnecting
                          ? null
                          : () => _connectToDevice(result),
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
                    controller: wifiSsidController,
                    decoration: const InputDecoration(
                      labelText: 'Wi-Fi network name',
                      border: OutlineInputBorder(),
                    ),
                  ),
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
          if (context.watch<BluetoothConnectionService>().isConnected)
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.bluetooth_connected),
                ),
                title: Text(
                  context
                      .watch<BluetoothConnectionService>()
                      .connectedDeviceName,
                ),
                subtitle: Text(
                  'Active connection${context.watch<BluetoothConnectionService>().liveBpm == null ? '' : ' - ${context.watch<BluetoothConnectionService>().liveBpm} BPM'}',
                ),
                trailing: const ElevatedButton(
                  onPressed: null,
                  child: Text('Connected'),
                ),
              ),
            ),
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
    wifiSsidController.dispose();
    wifiPasswordController.dispose();
    super.dispose();
  }
}
