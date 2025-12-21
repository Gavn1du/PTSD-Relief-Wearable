import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:ptsd_relief_app/services/auth.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  late StreamSubscription<List<ScanResult>> scanSubscription;

  final info = NetworkInfo();
  String wifiSSID = '';

  TextEditingController wifiPasswordController = TextEditingController();

  // available devices
  List<BluetoothDevice> devicesList = [];

  Future<void> connectToDevice() async {
    FlutterBluePlus.startScan(
      withServices: [Guid("6E400001-B5A3-F393-E0A9-E50E24DCCA9E")],
      timeout: const Duration(seconds: 4),
    );

    print('Scanning for devices...');

    scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      print('Scan results received: ${results.length} devices found.');

      for (ScanResult result in results) {
        // Check that the advertisement name is correct
        if (result.advertisementData.advName != "VitalLink Helper") {
          continue;
        }

        BluetoothDevice device = result.device;

        if (!devicesList.any((d) => d.remoteId == device.remoteId)) {
          setState(() {
            devicesList.add(device);
          });
          print('Device found: ${device.platformName} (${device.remoteId})');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          children: [
            ListView.builder(
              shrinkWrap: true,
              itemCount: devicesList.length,
              itemBuilder: (context, index) {
                BluetoothDevice device = devicesList[index];
                return ListTile(
                  title: Text(device.platformName),
                  subtitle: Text(device.remoteId.toString()),
                  onTap: () {
                    // Handle device selection

                    device.connect().then((_) async {
                      print('Connected to ${device.platformName}');

                      // Get current WiFi SSID
                      wifiSSID = (await info.getWifiName() ?? '').replaceAll(
                        '"',
                        '',
                      );
                      print('Current WiFi SSID: $wifiSSID');

                      // Prepare data to send
                      Map<String, String> wifiData = {
                        'ssid': wifiSSID,
                        'password': wifiPasswordController.text,
                        'uid': Auth().user?.uid ?? '',
                      };
                      String jsonData = jsonEncode(wifiData);
                      List<int> bytes = utf8.encode(jsonData);

                      // Send data over Bluetooth
                      List<BluetoothService> services =
                          await device.discoverServices();

                      final uartService = services.firstWhere(
                        (service) =>
                            service.uuid.toString().toUpperCase() ==
                            "6E400001-B5A3-F393-E0A9-E50E24DCCA9E",
                      );
                      final txCharacteristic = uartService.characteristics
                          .firstWhere(
                            (c) =>
                                c.uuid.toString().toUpperCase() ==
                                "6E400003-B5A3-F393-E0A9-E50E24DCCA9E",
                          );
                      final rxCharacteristic = uartService.characteristics
                          .firstWhere(
                            (c) =>
                                c.uuid.toString().toUpperCase() ==
                                "6E400002-B5A3-F393-E0A9-E50E24DCCA9E",
                          );

                      await rxCharacteristic.setNotifyValue(true);
                      rxCharacteristic.lastValueStream.listen((value) {
                        String response = utf8.decode(value);
                        print('Received response: $response');
                      });

                      await txCharacteristic.write(
                        bytes,
                        withoutResponse: true,
                      );
                      print('WiFi credentials sent over Bluetooth.');
                    });
                  },
                );
              },
            ),
            TextField(controller: wifiPasswordController),
            ElevatedButton(onPressed: () {}, child: const Text('Connect')),
          ],
        ),
      ),
    );
  }
}
