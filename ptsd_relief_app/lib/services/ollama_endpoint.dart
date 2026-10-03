import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where to reach the Ollama server running on the VitalLink Helper (Pi 5).
///
/// The Pi reports its address over BLE (`NET:` messages). Outdoors it hosts
/// its own hotspot and is always at [hotspotHost]; at home it joins the home
/// Wi-Fi and reports whatever address the router gave it.
class OllamaEndpoint {
  static const int port = 11434;
  static const String hotspotHost = '10.42.0.1';
  static const String _hostKey = 'ollamaHost';

  static const MethodChannel _channel = MethodChannel(
    'vitallink/local_network',
  );

  static String? _host;
  static final Map<String, String> _androidBridges = {};

  /// Called when the device reports a new address over BLE.
  static Future<void> setHost(String host) async {
    if (host == _host) return;
    _host = host;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostKey, host);
  }

  static Future<String> _currentHost() async {
    if (_host != null) return _host!;
    final prefs = await SharedPreferences.getInstance();
    _host = prefs.getString(_hostKey) ?? hotspotHost;
    return _host!;
  }

  /// Base URL for Ollama requests, e.g. `http://10.42.0.1:11434`.
  ///
  /// The Pi's hotspot has no internet, so Android keeps mobile data as the
  /// default network and would send these requests out over cellular. On
  /// Android a small native bridge forwards a loopback port over the Wi-Fi
  /// network that can reach the Pi; everything else (Firebase) keeps using
  /// mobile data. iOS routes local-subnet traffic over Wi-Fi on its own.
  static Future<String> baseUrl() async {
    final host = await _currentHost();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return 'http://$host:$port';
    }

    final cached = _androidBridges[host];
    if (cached != null) return cached;
    try {
      final localPort = await _channel.invokeMethod<int>('bridge', {
        'host': host,
        'port': port,
      });
      if (localPort != null) {
        return _androidBridges[host] = 'http://127.0.0.1:$localPort';
      }
    } on PlatformException catch (error) {
      debugPrint('Local network bridge unavailable: $error');
    }
    return 'http://$host:$port';
  }

  /// Options that keep replies short and the model resident between messages,
  /// which cuts the time (and battery) the Pi spends at full CPU load.
  static Map<String, dynamic> requestOptions({
    required int maxTokens,
    String keepAlive = '30m',
  }) => {
    'keep_alive': keepAlive,
    'options': {'num_predict': maxTokens},
  };
}
