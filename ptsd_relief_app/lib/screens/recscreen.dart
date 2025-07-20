import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ptsd_relief_app/components/navbar.dart';
import 'package:ptsd_relief_app/size_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/*

RECOMMENDATION ALGORITHM LOGIC
- Saved Chats are conversation that the user chooses to save (more specifically specific message in the overall conversation chain)
- Common Tips are tips the AI recommends based on the user's history (also feed to LLM to get)
   - Primary prompt: Given the prior conversation chain, give 5 comma separated pieces of advice that would be helpful to the user.
   - supplement: overall conversation history
   - Optimization logic: at the start of each new day, send this request and store the generated tips. 
     Proceed to store and go through these tips until either the next day or if we run out of new tips to show, whichever comes first

*/

class Recscreen extends StatefulWidget {
  const Recscreen({super.key});

  @override
  State<Recscreen> createState() => _RecscreenState();
}

class _RecscreenState extends State<Recscreen> {
  String ollamaUrl = "http://localhost:11434";
  List<Map<String, dynamic>> messages = [];
  List<String> commonTips = [];

  Future<void> storeLastTipRequest() async {
    // store the common tips list and the date and time when it was retrieved
    // for common tips, append a marker indicating if it was shown to the user already or not
    final prefs = await SharedPreferences.getInstance();
    List<String> annotatedTips = [];
    DateTime now = DateTime.now();
    String timestamp = now.toIso8601String();
    annotatedTips.add('timestamp: $timestamp');
    for (var tip in commonTips) {
      final String tipJson = jsonEncode({
        'tip': tip,
        'shown': false, // Initially set to false, can be updated later
      });
      annotatedTips.add(tipJson);
    }
    await prefs.setStringList('commonTips', annotatedTips);
  }

  Future<void> loadCommonTips() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? annotatedTips = prefs.getStringList('commonTips');
    print('Annotated tips loaded: $annotatedTips');
    if (annotatedTips != null && annotatedTips.length > 1) {
      commonTips = [];
      for (var annotatedTip in annotatedTips) {
        if (annotatedTip.startsWith('timestamp: ')) {
          // check if a day has passed since the last tips were stored
          final String timestamp = annotatedTip.substring(11);
          final DateTime lastTimestamp = DateTime.parse(timestamp);
          final DateTime now = DateTime.now();
          final Duration difference = now.difference(lastTimestamp);
          if (difference.inDays >= 1) {
            // It is the next day, regenerate the whole list of tips
            print('A day has passed since the last tips were stored.');
            sendChatMessage(
              'Given the prior conversation chain, give 5 comma separated pieces of tips or advice in english that would be helpful to a user suffering from ptsd. If there is not enough information, just give 5 general tips.',
            ).then((response) {
              print('Response from tips request: $response');
              if (response.containsKey('error')) {
                print('Error generating tips: ${response['error']}');
              } else {
                commonTips = List<String>.from(response['tips'] ?? []);
                storeLastTipRequest();
                print('New common tips generated: $commonTips');
              }
            });
            return;
          }
        } else {
          try {
            final Map<String, dynamic> tipData =
                jsonDecode(annotatedTip) as Map<String, dynamic>;
            if (tipData.containsKey('tip')) {
              print('Adding tip: ${tipData['tip']}');
              commonTips.add(
                "${tipData['tip'] as String} - ${tipData['shown'] ? 'Shown' : 'Not Shown'}",
              );
            }
          } catch (e) {
            print('Error decoding tip: $e');
          }
        }
      }
    } else {
      print('No common tips found in SharedPreferences');
      // get the new list of tips and store it
      sendChatMessage(
        'Given the prior conversation chain, give 5 comma separated pieces of tips or advice in english that would be helpful to a user suffering from ptsd. If there is not enough information, just give 5 general tips.',
      ).then((response) {
        print('Response from tips request: $response');
        // if (response.containsKey('error')) {
        //   print('Error generating tips: ${response['error']}');
        // } else {
        //   commonTips = List<String>.from(response['tips'] ?? []);
        //   storeLastTipRequest();
        //   print('New common tips generated: $commonTips');
        // }
      });
    }
  }

  Future<void> loadMessageHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? messageJsonList = prefs.getStringList('messageHistory');
    if (messageJsonList != null) {
      messages =
          messageJsonList
              .map(
                (messageJson) =>
                    jsonDecode(messageJson) as Map<String, dynamic>,
              )
              .toList();
      print('Loaded message history: $messages');
    } else {
      print('No message history found in SharedPreferences');
      messages = [];
    }
  }

  Future<Map<String, dynamic>> sendChatMessage(String message) async {
    // Load message history from SharedPreferences
    await loadMessageHistory();
    // Design Note: to test context is understood, the messahes block should have some other older messages
    final uri = Uri.parse('$ollamaUrl/api/chat');
    print('Sending tips request to: $uri');

    Map<String, dynamic> data;

    print('Sending text message: $message');
    print('Current messages: $messages');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        // 'model': 'qwen3:1.7b',
        // 'model': 'qwen2.5vl:3b',
        'model': 'gemma3n:e2b',

        'messages': messages,
        'stream': false,
      }),
    );

    print('Response status code: ${response.statusCode}');
    if (response.statusCode == 200) {
      data = jsonDecode(response.body);
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

  @override
  void initState() {
    super.initState();
    // Load common tips when the screen is initialized
    loadCommonTips().then((_) {
      print('Common tips loaded: $commonTips');
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Home Screen'),
      // ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: SizeConfig.horizontal! * 90,
                  height: SizeConfig.vertical! * 30,
                  child: Card(
                    color: Color.fromARGB(255, 103, 92, 91),
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            "Common Tips",
                            style: TextStyle(color: Colors.white, fontSize: 20),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                child: Card(
                                  color: const Color.fromARGB(
                                    255,
                                    242,
                                    247,
                                    242,
                                  ),
                                  child: const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: SizeConfig.horizontal! * 90,
                  height: SizeConfig.vertical! * 50,
                  child: Card(
                    color: const Color.fromARGB(255, 103, 92, 91),
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            "Saved Chats",
                            style: TextStyle(color: Colors.white, fontSize: 20),
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            children: [
                              Card(
                                color: const Color.fromARGB(255, 242, 247, 242),
                                child: InkWell(
                                  onDoubleTap: () {
                                    // This card will hold a value, we then build a route to the chat screen
                                    // we give the value as an optional parameter
                                    // If the Chat screen is given this parameter, it will also scroll to that spot
                                    // in addition to the default behaviors.
                                  },
                                  child: SizedBox(
                                    width: SizeConfig.horizontal! * 90,
                                    height: SizeConfig.vertical! * 20,
                                    child: const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Text(
                                          'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Navbar(currentIndex: 2),
    );
  }
}
