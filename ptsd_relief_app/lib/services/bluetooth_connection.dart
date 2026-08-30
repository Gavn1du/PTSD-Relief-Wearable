import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class FallDetectionEvent {
  const FallDetectionEvent({required this.kind, required this.recordedAt});

  final String? kind;
  final DateTime recordedAt;

  bool get detected => kind != null;

  String get description {
    switch (kind) {
      case 'real_tumbling':
        return 'tumbling';
      case 'real_tripping':
        return 'tripping';
      case 'real_slipping':
        return 'slipping';
      default:
        return 'fall-like motion';
    }
  }

  static FallDetectionEvent? tryParse(String message) {
    final parts = message.trim().split(':');
    if (parts.length != 3 || parts[0] != 'FALL') return null;

    final kind = switch (parts[1]) {
      'OK' => null,
      'TB' => 'real_tumbling',
      'TR' => 'real_tripping',
      'SL' => 'real_slipping',
      _ => '',
    };
    if (kind == '') return null;

    final timestampMs = int.tryParse(parts[2], radix: 16);
    if (timestampMs == null || timestampMs <= 0) return null;

    return FallDetectionEvent(
      kind: kind,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(timestampMs),
    );
  }
}

class BluetoothConnectionService extends ChangeNotifier {
  static const String uartServiceUuid = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String rxUuid = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String txUuid = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E';

  BluetoothDevice? _device;
  BluetoothCharacteristic? _rx;
  BluetoothCharacteristic? _tx;
  StreamSubscription<List<int>>? _notificationSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  final StreamController<String> _messages =
      StreamController<String>.broadcast();

  int? _liveBpm;
  DateTime? _liveBpmUpdatedAt;
  FallDetectionEvent? _lastFallEvent;
  DateTime? _fallStatusUpdatedAt;
  bool _fallMonitoringActive = false;
  bool _isConnecting = false;
  bool _isConnected = false;

  int? get liveBpm => _liveBpm;
  DateTime? get liveBpmUpdatedAt => _liveBpmUpdatedAt;
  FallDetectionEvent? get lastFallEvent => _lastFallEvent;
  DateTime? get fallStatusUpdatedAt => _fallStatusUpdatedAt;
  bool get fallMonitoringActive => _fallMonitoringActive;
  bool get isConnecting => _isConnecting;
  bool get isConnected => _isConnected;
  String? get connectedDeviceId => _device?.remoteId.toString();
  String get connectedDeviceName {
    final name = _device?.platformName.trim() ?? '';
    return name.isEmpty ? 'VitalLink Helper' : name;
  }

  bool isConnectedTo(BluetoothDevice device) =>
      _isConnected && connectedDeviceId == device.remoteId.toString();

  Future<String> provision(
    BluetoothDevice device, {
    required String ssid,
    required String password,
    required String uid,
  }) async {
    await _connect(device);

    final responseFuture = _messages.stream
        .where(
          (message) => message.startsWith('OK:') || message.startsWith('ERR:'),
        )
        .first
        .timeout(
          const Duration(seconds: 30),
          onTimeout:
              () =>
                  throw TimeoutException(
                    'Timed out waiting for the device setup response.',
                  ),
        );

    await _writeChunked(
      _rx!,
      utf8.encode(jsonEncode({'ssid': ssid, 'password': password, 'uid': uid})),
    );

    final response = await responseFuture;
    if (response.startsWith('ERR:')) {
      throw Exception(response);
    }
    return response;
  }

  Future<void> _connect(BluetoothDevice device) async {
    if (isConnectedTo(device) && _rx != null && _tx != null) {
      return;
    }

    _setConnecting(true);
    try {
      if (_device != null && connectedDeviceId != device.remoteId.toString()) {
        await disconnect();
      }

      _device = device;
      try {
        await device.connect();
      } catch (error) {
        if (!error.toString().toLowerCase().contains('already')) {
          rethrow;
        }
      }

      final services = await device.discoverServices();
      final uartService = _findService(services, uartServiceUuid);
      if (uartService == null) {
        throw Exception('Compatible device service not found.');
      }

      _rx = _findCharacteristic(uartService, rxUuid);
      _tx = _findCharacteristic(uartService, txUuid);
      if (_rx == null || _tx == null) {
        throw Exception('Could not open the device communication channel.');
      }

      await _tx!.setNotifyValue(true);
      await _notificationSubscription?.cancel();
      _notificationSubscription = _tx!.lastValueStream.listen(_handleMessage);

      await _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _clearConnection();
        }
      });

      _isConnected = true;
      notifyListeners();
    } finally {
      _setConnecting(false);
    }
  }

  void _handleMessage(List<int> value) {
    if (value.isEmpty) return;

    final message = utf8.decode(value).trim();
    if (message.isEmpty) return;

    if (message.startsWith('BPM:')) {
      final bpm = int.tryParse(message.substring(4).trim());
      if (bpm != null) {
        _liveBpm = bpm;
        _liveBpmUpdatedAt = DateTime.now();
        notifyListeners();
      }
      return;
    }

    final fallUpdate = FallDetectionEvent.tryParse(message);
    if (fallUpdate != null) {
      _fallMonitoringActive = true;
      _fallStatusUpdatedAt = fallUpdate.recordedAt;
      _lastFallEvent = fallUpdate.detected ? fallUpdate : null;
      notifyListeners();
      return;
    }

    _messages.add(message);
  }

  Future<void> disconnect() async {
    final device = _device;
    await _notificationSubscription?.cancel();
    await _connectionSubscription?.cancel();
    _notificationSubscription = null;
    _connectionSubscription = null;
    _rx = null;
    _tx = null;
    _device = null;
    _isConnected = false;
    _liveBpm = null;
    _liveBpmUpdatedAt = null;
    _fallMonitoringActive = false;
    notifyListeners();

    if (device != null) {
      await device.disconnect();
    }
  }

  void _clearConnection() {
    _notificationSubscription?.cancel();
    _connectionSubscription?.cancel();
    _notificationSubscription = null;
    _connectionSubscription = null;
    _rx = null;
    _tx = null;
    _device = null;
    _isConnected = false;
    _liveBpm = null;
    _liveBpmUpdatedAt = null;
    _fallMonitoringActive = false;
    notifyListeners();
  }

  void _setConnecting(bool value) {
    _isConnecting = value;
    notifyListeners();
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

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _connectionSubscription?.cancel();
    _messages.close();
    super.dispose();
  }
}
