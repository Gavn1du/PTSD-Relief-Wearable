import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:ptsd_relief_app/services/ollama_endpoint.dart';

class Llm {
  // Chat and images share one multimodal model so it stays resident on the
  // Pi; tips use a smaller, faster text-only model.
  static const String tipModel = "LiquidAI/lfm2.5-1.2b-instruct:q4_k_m";
  static const String textModel = "qwen3.5:2b-q4_K_M";
  static const String imageModel = "qwen3.5:2b-q4_K_M";

  Future<Uint8List> convertToPngBytes(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final ui.Image image = frame.image;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to convert image to PNG bytes');
    }
    return byteData.buffer.asUint8List();
  }

  Future<Map<String, dynamic>> sendMessage(
    String message, {
    String model = textModel,
  }) async {
    final uri = Uri.parse('${await OllamaEndpoint.baseUrl()}/api/chat');
    print('Sending request to: $uri');
    print('Message: $message');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': model,
        'stream': false,
        'think': false,
        ...OllamaEndpoint.requestOptions(maxTokens: 512),
        'messages': [
          {'role': 'user', 'content': message},
        ],
      }),
    );

    print('Response status code: ${response.statusCode}');
    if (response.statusCode == 200) {
      Map<String, dynamic> data = jsonDecode(response.body);
      print('Response data: $data');
      return data;
    } else {
      print('Error: ${response.statusCode}');
      return {
        'error': 'Failed to send message',
        'statusCode': response.statusCode,
      };
    }
  }
}
