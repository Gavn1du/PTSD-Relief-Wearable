import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;

class Llm {
  String ollamaUrl = "http://192.168.1.61:11434";
  String tipModel = "gemma3:1b";
  String textModel = "qwen3:1.7b";
  String imageModel = "qwen2.5vl:3b";

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
    String model = "qwen3:1.7b",
  }) async {
    final uri = Uri.parse('$ollamaUrl/api/chat');
    print('Sending request to: $uri');
    print('Message: $message');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': textModel,
        'stream': false,
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
