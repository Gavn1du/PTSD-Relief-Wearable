import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:markdown_widget/widget/markdown.dart';
import 'package:ptsd_relief_app/components/navbar.dart';
import 'package:chatview/chatview.dart';
import 'package:ptsd_relief_app/components/data.dart';
import 'package:ptsd_relief_app/components/theme.dart';
import 'dart:convert';
import 'package:ptsd_relief_app/size_config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// TODO: implement markdown rendering

class Helpscreen extends StatefulWidget {
  const Helpscreen({super.key});

  @override
  State<Helpscreen> createState() => _HelpscreenState();
}

class _HelpscreenState extends State<Helpscreen> {
  late List<Message> messageList;
  AppTheme theme = LightTheme();
  bool isDarkTheme = false;

  String? pendingImagePath;

  Future<void> saveMessagePosition(Message message) async {
    final prefs = await SharedPreferences.getInstance();
    // save to a string list called 'messagePositions'
    final List<String> messagePositions =
        prefs.getStringList('messagePositions') ?? [];
    final String position = jsonEncode({
      'id': message.id,
      // 'createdAt': message.createdAt.toIso8601String(),
      'sentBy': message.sentBy,
      'message': message.message,
    });

    // Check for duplicates by checking message ID
    if (messagePositions.any((pos) => jsonDecode(pos)['id'] == message.id)) {
      print('Duplicate message position found, not saving: $position');
      return;
    }

    messagePositions.add(position);

    // DEBUG: clear the message positions
    // messagePositions.clear();

    await prefs.setStringList('messagePositions', messagePositions);
  }

  Future<void> deleteMessagePosition(String messageId) async {
    final prefs = await SharedPreferences.getInstance();
    // save to a string list called 'messagePositions'
    final List<String> messagePositions =
        prefs.getStringList('messagePositions') ?? [];

    // Remove the message with the given ID
    final updatedPositions =
        messagePositions
            .where((pos) => jsonDecode(pos)['id'] != messageId)
            .toList();

    print('Messages after deletion: $updatedPositions');

    await prefs.setStringList('messagePositions', updatedPositions);
  }

  // TODO: consider optimisations for large message history

  // Function to save message history to SharedPreferences
  Future<void> saveMessageHistory(List<Message> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> messageJsonList =
        messages.map((msg) => jsonEncode(msg.toJson())).toList();
    await prefs.setStringList('messageHistory', messageJsonList);
  }

  // Function to load message history from SharedPreferences
  Future<void> loadMessageHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? messageJsonList = prefs.getStringList('messageHistory');
    if (messageJsonList != null) {
      messageList =
          messageJsonList
              .map((jsonstr) => Message.fromJson(jsonDecode(jsonstr)))
              .toList();

      for (var msg in messageList) {
        chatController.addMessage(msg);
      }

      print('Loaded message history: ${messageList.length} messages');
      // for (var msg in messageList) {
      //   print(
      //     'Message: ${msg.message}, Sent by: ${msg.sentBy}, Created at: ${msg.createdAt}',
      //   );
      // }
    } else {
      print('No message history found in SharedPreferences');
      messageList = [];
      chatController.initialMessageList = messageList;
    }
  }

  // ===== OLLAMA TEST FUNCTIONS =====
  String ollamaUrl = "http://localhost:11434";

  Future<void> sendPrompt(String prompt) async {
    final uri = Uri.parse('$ollamaUrl/api/generate');
    print('Sending request to: $uri');
    print('Prompt: $prompt');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': 'qwen3:1.7b',
        'prompt': prompt,
        'stream': false,
      }),
    );
    print('Response status code: ${response.statusCode}');
    print('Response body: ${response.body}');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Response data: $data');
      final generatedText = data['text'];
      print('Generated text: $generatedText');
    } else {
      print('Error: ${response.statusCode}');
    }
  }
  /*
  flutter: Prompt: Hello world!
  flutter: null
  flutter: Response status code: 200
  flutter: Response body: {"model":"qwen3:1.7b","created_at":"2025-05-18T02:24:19.612078Z","response":"\u003cthink\u003e\nOkay, the user said \"Hello world!\" so I need to respond appropriately. Let me see, they might be testing if I can recognize the greeting. I should acknowledge it and maybe add a friendly message. Let me make sure to keep it welcoming and offer assistance. Something like, \"Hello! How can I assist you today?\" That should cover it.\n\u003c/think\u003e\n\nHello! How can I assist you today? 😊","done":true,"done_reason":"stop","context":[151644,872,198,9707,1879,0,151645,198,151644,77091,198,151667,198,32313,11,279,1196,1053,330,9707,1879,8958,773,358,1184,311,5889,34901,13,6771,752,1490,11,807,2578,387,7497,421,358,646,15282,279,42113,13,358,1265,24645,432,323,7196,912,264,11657,1943,13,6771,752,1281,2704,311,2506,432,35287,323,3010,12994,13,24656,1075,11,330,9707,0,2585,646,358,7789,498,3351,7521,2938,1265,3421,432,624,151668,271,9707,0,2585,646,358,7789,498,3351,30,26525,2<…>
  flutter: Response data: {model: qwen3:1.7b, created_at: 2025-05-18T02:24:19.612078Z, response: <think>
  Okay, the user said "Hello world!" so I need to respond appropriately. Let me see, they might be testing if I can recognize the greeting. I should acknowledge it and maybe add a friendly message. Let me make sure to keep it welcoming and offer assistance. Something like, "Hello! How can I assist you today?" That should cover it.
  </think>

  Hello! How can I assist you today? 😊, done: true, done_reason: stop, context: [151644, 872, 198, 9707, 1879, 0, 151645, 198, 151644, 77091, 198, 151667, 198, 32313, 11, 279, 1196, 1053, 330, 9707, 1879, 8958, 773, 358, 1184, 311, 5889, 34901, 13, 6771, 752, 1490, 11, 807, 2578, 387, 7497, 421, 358, 646, 15282, 279, 42113, 13, 358, 1265, 24645, 432, 323, 7196, 912, 264, 11657, 1943, 13, 6771, 752, 1281, 2704, 311, 2506, 432, 35287, 323, 3010, 12994, 13, 24656, 1075, 11, 330, 9707, 0, 2585, 646, 358, 7789, 498, 3351, 7521, 2938, 1265, 3421, 432, 624, 151668,<…>
  flutter: Generated text: null
   */

  // stream variant
  Future<void> sendPromptStream(String prompt) async {
    final uri = Uri.parse('$ollamaUrl/api/generate');
    print('Sending request to: $uri');
    print('Prompt: $prompt');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': 'qwen3:1.7b',
        'prompt': prompt,
        'stream': true,
      }),
    );
    print('Response status code: ${response.statusCode}');
    if (response.statusCode == 200) {
      final stream = response.body;
      print('Response stream: $stream');
    } else {
      print('Error: ${response.statusCode}');
    }
  }

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

  Future<void> testSendAssetImage() async {
    final ByteData data = await rootBundle.load('assets/testpng.png');
    final Uint8List bytes = data.buffer.asUint8List();
    final String b64Image = base64Encode(bytes);
    final String uri = 'data:image/png;base64,$b64Image';
    print('Sending request to: $uri');
    print('Image data length: ${bytes.length} bytes');
    final response = await http.post(
      Uri.parse('$ollamaUrl/api/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': 'qwen2.5vl:3b',
        'stream': false, // Set to true if you want streaming
        'messages': [
          {
            'role': 'user',
            'content': 'Describe this image',
            'images': [b64Image],
          },
        ],
      }),
    );
    print('TEST Response status code: ${response.statusCode}');
    print('TEST Response body: ${response.body}');
  }

  Future<Map<String, dynamic>> sendImage(
    String imagePath, [
    String prompt = 'Describe this image',
  ]) async {
    /*
    TEST Messages: [
    {role: user, content: Hi}, 
    {role: assistant, content: Hello}, 
    {role: user, content: /Users/gavindu/Library/Developer/CoreSimulator/Devices/27BCD2D4-0315-476B-89F3-89D6AFD138DF/data/Containers/Data/Application/E55F64D3-5192-43D5-B8F6-A10A29DB3339/tmp/image_picker_7FA5F383-3EFC-4D78-B9E1-CBE67D12827D-58853-0000182B325B85BE.jpg}, 
    {role: user, content: Analyze the middle}
    ]
     */
    final uri = Uri.parse('$ollamaUrl/api/chat');
    print('Sending request to: $uri');
    print('Image path: $imagePath');

    List<Map<String, dynamic>> messages = [];
    for (Message msg in chatController.initialMessageList) {
      messages.add({
        'role':
            msg.sentBy == chatController.currentUser.id ? 'user' : 'assistant',
        'content': msg.message,
      });
    }

    // Remove the last two message since we are merging below
    if (messages.length >= 2) {
      messages.removeRange(messages.length - 2, messages.length);
    }

    // 1) Read & base64 encode the image
    final bytes = await convertToPngBytes(File(imagePath));
    final base64Image = base64Encode(bytes);

    messages.add({
      'role': 'user',
      'content': prompt,
      'images': [base64Image],
    });

    // Print the messages for debugging
    print('TEST Messages: $messages');

    // 2) Build the JSON
    final body = jsonEncode({
      'model': 'qwen2.5vl:3b',
      'stream': false, // Set to true if you want streaming
      'messages': messages,
    });

    //3) Send the request
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    print('Response status code: ${response.statusCode}');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print('Error: ${response.statusCode}');
      return {
        'error': 'Failed to send image',
        'statusCode': response.statusCode,
      };
    }
  }
  /*
  flutter: Prompt: Hello world!
  flutter: Response status code: 200
  flutter: Response stream: {"model":"qwen3:1.7b","created_at":"2025-05-18T02:30:37.349406Z","response":"\u003cthink\u003e","done":false}
  {"model":"qwen3:1.7b","created_at":"2025-05-18T02:30:37.349956Z","response":"\n","done":false}
  {"model":"qwen3:1.7b","created_at":"2025-05-18T02:30:37.358727Z","response":"Okay","done":false}
  {"model":"qwen3:1.7b","created_at":"2025-05-18T02:30:37.38218Z","response":",","done":false}
  {"model":"qwen3:1.7b","created_at":"2025-05-18T02:30:37.407605Z","response":" the","done":false}
  {"model":"qwen3:1.7b","created_at":"2025-05-18T02:30:37.465172Z","response":" user","done":false}
  {"model":"qwen3:1.7b","created_at":"2025-05-18T02:30:37.500468Z","response":" said","done":false}
  {"model":"qwen3:1.7b","created_at":"2025-05-18T02:30:37.532573Z","response":" \"","done":false}
  {"model":"qwen3:1.7b","created_at":"2025-05-18T02:30:37.568951Z","response":"Hello","done":false}
  {"model":"qwen3:1.7b","created_at":"2025-05-18T02:30:38.057925Z","response":" world","done":false}
  {"<…>
   */

  // chat variants
  Future<Map<String, dynamic>> sendChatMessage(
    String message, [
    bool isImage = false,
  ]) async {
    // Design Note: to test context is understood, the messahes block should have some other older messages
    final uri = Uri.parse('$ollamaUrl/api/chat');
    print('Sending request to: $uri');
    print('Message: $message');

    List<Map<String, dynamic>> messages = [];
    for (Message msg in chatController.initialMessageList) {
      messages.add({
        'role':
            msg.sentBy == chatController.currentUser.id ? 'user' : 'assistant',
        'content': msg.message,
      });
    }

    print('Messages: $messages');
    Map<String, dynamic> data;
    if (isImage) {
      print('Sending image message: $message');

      // Intercept the image path here as we will wait for the prompt before sending
      setState(() {
        pendingImagePath = message; // message is the image path
      });
      data = {
        'status': 'pending',
        'message': 'Image message is pending',
        'statusCode': 200,
      };
      // data = await sendImage(message);
    } else {
      print('Sending text message: $message');

      if (pendingImagePath != null) {
        var pendingPath = pendingImagePath;
        setState(() {
          pendingImagePath = null; // Clear the pending image path
        });
        data = await sendImage(pendingPath!, message);
      } else {
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': 'qwen3:1.7b',
            // 'model': 'qwen2.5vl:3b',
            'messages': messages,
            // 'messages': [
            //   {
            //     'role': 'system',
            //     'content': 'What would you like my code block to print?',
            //   },
            //   {'role': 'user', 'content': message},
            // ],
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
    }

    print('Response data: $data');
    return data;
  }
  // =================================

  late final ChatController chatController;

  void _showHideTypingIndicator() {
    chatController.setTypingIndicator = !chatController.showTypingIndicator;
  }

  void receiveMessage() async {
    chatController.addMessage(
      Message(
        id: DateTime.now().toString(),
        message: 'I will schedule the meeting.',
        createdAt: DateTime.now(),
        sentBy: '2',
      ),
    );
    await Future.delayed(const Duration(milliseconds: 500));
    chatController.addReplySuggestions([
      const SuggestionItemData(text: 'Thanks.'),
      const SuggestionItemData(text: 'Thank you very much.'),
      const SuggestionItemData(text: 'Great.'),
    ]);
  }

  void onSendTap(
    String message,
    ReplyMessage replyMessage,
    MessageType messageType,
  ) {
    chatController.addMessage(
      Message(
        id: DateTime.now().toString(),
        message: message,
        createdAt: DateTime.now(),
        sentBy: chatController.currentUser.id,
        replyMessage: replyMessage,
        messageType: messageType,
      ),
    );
    // Future.delayed(const Duration(milliseconds: 300), () {
    //   chatController.initialMessageList.last.setStatus =
    //       MessageStatus.undelivered;
    // });
    // Future.delayed(const Duration(seconds: 1), () {
    //   chatController.initialMessageList.last.setStatus = MessageStatus.read;
    // });

    chatController.setTypingIndicator = true;

    bool isImage = messageType == MessageType.image;

    // Check if sending image or text
    if (messageType == MessageType.image) {
      print('Sending image message: $message');
    } else if (messageType == MessageType.text) {
      print('Sending text message: $message');
    } else {
      print('Unknown message type: $messageType');
      return;
    }

    // Send the message to the LLM server
    sendChatMessage(message, isImage)
        .then((response) {
          chatController.setTypingIndicator = false;
          if (response.containsKey('error')) {
            print("Error: ${response['error']}");
            return;
          } else {
            if (response['status'] == 'pending') {
              print('Image message is pending, waiting for prompt...');
              // setState(() {
              //   pendingImagePath = message; // Store the image path
              // });
              return;
            }

            Map<String, dynamic> messageData = response['message'] ?? {};
            String generatedText = messageData['content'] ?? '';
            print('Generated text: $generatedText');

            // Trim out the think segment between the <think> tags
            generatedText =
                generatedText
                    .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
                    .trim();
            print('Trimmed generated text: $generatedText');

            chatController.addMessage(
              Message(
                id: DateTime.now().toString(),
                message: generatedText,
                createdAt: DateTime.now(),
                sentBy: '2',
                replyMessage: replyMessage,
                messageType: MessageType.text,
                status: MessageStatus.delivered,
              ),
            );
            // receiveMessage();

            // Save the message history after sending
            saveMessageHistory(chatController.initialMessageList);
            print('Message sent and saved successfully.');
          }
        })
        .catchError((error) {
          print('Error sending message: $error');
        });
  }

  void _onThemeIconTap() {
    setState(() {
      if (isDarkTheme) {
        theme = LightTheme();
        isDarkTheme = false;
      } else {
        theme = DarkTheme();
        isDarkTheme = true;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    messageList = [
      // Message(id: '1', message: "Hi", createdAt: DateTime.now(), sentBy: "1"),
      // Message(
      //   id: '2',
      //   message: "Hello",
      //   createdAt: DateTime.now(),
      //   sentBy: "2",
      // ),
    ];
    chatController = ChatController(
      initialMessageList: messageList,
      scrollController: ScrollController(),
      currentUser: ChatUser(
        id: '1',
        name: 'User',
        profilePhoto: Data.profileImage,
      ),
      otherUsers: [
        ChatUser(id: '2', name: 'Chatbot', profilePhoto: Data.profileImage),
      ],
    );

    // Load message history from SharedPreferences
    loadMessageHistory();

    // Send test image
    // testSendAssetImage();

    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   sendChatMessage("Hello world!");
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Home Screen'),
      // ),
      body: Stack(
        children: [
          ChatView(
            chatController: chatController,
            onSendTap: onSendTap,
            featureActiveConfig: const FeatureActiveConfig(
              lastSeenAgoBuilderVisibility: true,
              receiptsBuilderVisibility: true,
              enableScrollToBottomButton: true,
            ),
            scrollToBottomButtonConfig: ScrollToBottomButtonConfig(
              backgroundColor: theme.textFieldBackgroundColor,
              border: Border.all(
                color: isDarkTheme ? Colors.transparent : Colors.grey,
              ),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: theme.themeIconColor,
                weight: 10,
                size: 30,
              ),
            ),
            chatViewState: ChatViewState.hasMessages,
            chatViewStateConfig: ChatViewStateConfiguration(
              loadingWidgetConfig: ChatViewStateWidgetConfiguration(
                loadingIndicatorColor: theme.outgoingChatBubbleColor,
              ),
              onReloadButtonTap: () {},
            ),
            typeIndicatorConfig: TypeIndicatorConfiguration(
              flashingCircleBrightColor: theme.flashingCircleBrightColor,
              flashingCircleDarkColor: theme.flashingCircleDarkColor,
            ),
            appBar: ChatViewAppBar(
              leading: SizedBox(width: 20),
              elevation: theme.elevation,
              backGroundColor: theme.appBarColor,
              profilePicture: Data.profileImage,
              backArrowColor: theme.backArrowColor,
              chatTitle: "Chat view",
              chatTitleTextStyle: TextStyle(
                color: theme.appBarTitleTextStyle,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 0.25,
              ),
              userStatus: "online",
              userStatusTextStyle: const TextStyle(color: Colors.grey),
              actions: [
                // IconButton(
                //   onPressed: _onThemeIconTap,
                //   icon: Icon(
                //     isDarkTheme
                //         ? Icons.brightness_4_outlined
                //         : Icons.dark_mode_outlined,
                //     color: theme.themeIconColor,
                //   ),
                // ),
                // IconButton(
                //   tooltip: 'Toggle TypingIndicator',
                //   onPressed: _showHideTypingIndicator,
                //   icon: Icon(Icons.keyboard, color: theme.themeIconColor),
                // ),
                IconButton(
                  tooltip: 'Change Chatbot Settings',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return ChatbotSettingsPopup(
                          isDarkTheme: isDarkTheme,
                          onThemeToggle: (newIsDark) {
                            setState(() {
                              isDarkTheme = newIsDark;
                              theme = isDarkTheme ? DarkTheme() : LightTheme();
                            });
                          },
                        );
                      },
                    );
                  },
                  icon: Icon(Icons.tune, color: theme.themeIconColor),
                ),
              ],
            ),
            chatBackgroundConfig: ChatBackgroundConfiguration(
              messageTimeIconColor: theme.messageTimeIconColor,
              messageTimeTextStyle: TextStyle(
                color: theme.messageTimeTextColor,
              ),
              defaultGroupSeparatorConfig: DefaultGroupSeparatorConfiguration(
                textStyle: TextStyle(
                  color: theme.chatHeaderColor,
                  fontSize: 17,
                ),
              ),
              backgroundColor: theme.backgroundColor,
            ),
            sendMessageConfig: SendMessageConfiguration(
              // imagePickerIconsConfig: ImagePickerIconsConfiguration(
              //   cameraIconColor: theme.cameraIconColor,
              //   galleryIconColor: theme.galleryIconColor,
              // ),
              enableCameraImagePicker: false,
              allowRecordingVoice: false,
              replyMessageColor: theme.replyMessageColor,
              defaultSendButtonColor: theme.sendButtonColor,
              replyDialogColor: theme.replyDialogColor,
              replyTitleColor: theme.replyTitleColor,
              textFieldBackgroundColor: theme.textFieldBackgroundColor,
              closeIconColor: theme.closeIconColor,
              textFieldConfig: TextFieldConfiguration(
                onMessageTyping: (status) {
                  /// Do with status
                  debugPrint(status.toString());
                },
                compositionThresholdTime: const Duration(seconds: 1),
                textStyle: TextStyle(color: theme.textFieldTextColor),
              ),
              micIconColor: theme.replyMicIconColor,
              voiceRecordingConfiguration: VoiceRecordingConfiguration(
                backgroundColor: theme.waveformBackgroundColor,
                recorderIconColor: theme.recordIconColor,
                waveStyle: WaveStyle(
                  showMiddleLine: false,
                  waveColor: theme.waveColor ?? Colors.white,
                  extendWaveform: true,
                ),
              ),
            ),
            chatBubbleConfig: ChatBubbleConfiguration(
              outgoingChatBubbleConfig: ChatBubble(
                linkPreviewConfig: LinkPreviewConfiguration(
                  backgroundColor: theme.linkPreviewOutgoingChatColor,
                  bodyStyle: theme.outgoingChatLinkBodyStyle,
                  titleStyle: theme.outgoingChatLinkTitleStyle,
                ),
                receiptsWidgetConfig: const ReceiptsWidgetConfig(
                  showReceiptsIn: ShowReceiptsIn.all,
                ),
                color: theme.outgoingChatBubbleColor,
              ),
              inComingChatBubbleConfig: ChatBubble(
                linkPreviewConfig: LinkPreviewConfiguration(
                  linkStyle: TextStyle(
                    color: theme.inComingChatBubbleTextColor,
                    decoration: TextDecoration.underline,
                  ),
                  backgroundColor: theme.linkPreviewIncomingChatColor,
                  bodyStyle: theme.incomingChatLinkBodyStyle,
                  titleStyle: theme.incomingChatLinkTitleStyle,
                ),
                textStyle: TextStyle(color: theme.inComingChatBubbleTextColor),
                onMessageRead: (message) {
                  /// send your message reciepts to the other client
                  debugPrint('Message Read');
                },
                senderNameTextStyle: TextStyle(
                  color: theme.inComingChatBubbleTextColor,
                ),
                color: theme.inComingChatBubbleColor,
              ),
            ),
            replyPopupConfig: ReplyPopupConfiguration(
              // TODO: add a pass through gesture detector to catch when this pops up so we can show custom text instead of More, Report, and Reply
              backgroundColor: theme.replyPopupColor,
              buttonTextStyle: TextStyle(color: theme.replyPopupColor),
              topBorderColor: theme.replyPopupTopBorderColor,
              onMoreTap: (Message message, bool isReplying) {
                /// Do something when more button is tapped
                debugPrint('More tapped for message: ${message.message}');
                saveMessagePosition(message);
              },
              onReplyTap: (Message message) {
                /// Do something when reply button is tapped
                debugPrint('Reply tapped for message: ${message.message}');
                // saveMessagePosition(message);
              },
              onReportTap: (message) {
                /// Do something when report button is tapped
                debugPrint('Report tapped for message: ${message.message}');
                deleteMessagePosition(message.id);
              },
            ),
            reactionPopupConfig: ReactionPopupConfiguration(
              shadow: BoxShadow(
                color: isDarkTheme ? Colors.black54 : Colors.grey.shade400,
                blurRadius: 20,
              ),
              backgroundColor: theme.reactionPopupColor,
            ),
            messageConfig: MessageConfiguration(
              messageReactionConfig: MessageReactionConfiguration(
                backgroundColor: theme.messageReactionBackGroundColor,
                borderColor: theme.messageReactionBackGroundColor,
                reactedUserCountTextStyle: TextStyle(
                  color: theme.inComingChatBubbleTextColor,
                ),
                reactionCountTextStyle: TextStyle(
                  color: theme.inComingChatBubbleTextColor,
                ),
                reactionsBottomSheetConfig: ReactionsBottomSheetConfiguration(
                  backgroundColor: theme.backgroundColor,
                  reactedUserTextStyle: TextStyle(
                    color: theme.inComingChatBubbleTextColor,
                  ),
                  reactionWidgetDecoration: BoxDecoration(
                    color: theme.inComingChatBubbleColor,
                    boxShadow: [
                      BoxShadow(
                        color:
                            isDarkTheme ? Colors.black12 : Colors.grey.shade200,
                        offset: const Offset(0, 20),
                        blurRadius: 40,
                      ),
                    ],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            profileCircleConfig: const ProfileCircleConfiguration(
              profileImageUrl: Data.profileImage,
            ),
            repliedMessageConfig: RepliedMessageConfiguration(
              backgroundColor: theme.repliedMessageColor,
              verticalBarColor: theme.verticalBarColor,
              repliedMsgAutoScrollConfig: RepliedMsgAutoScrollConfig(
                enableHighlightRepliedMsg: true,
                highlightColor: Colors.pinkAccent.shade100,
                highlightScale: 1.1,
              ),
              textStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.25,
              ),
              replyTitleTextStyle: TextStyle(
                color: theme.repliedTitleTextColor,
              ),
            ),
            swipeToReplyConfig: SwipeToReplyConfiguration(
              replyIconColor: theme.swipeToReplyIconColor,
            ),
            replySuggestionsConfig: ReplySuggestionsConfig(
              itemConfig: SuggestionItemConfig(
                decoration: BoxDecoration(
                  color: theme.textFieldBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.outgoingChatBubbleColor ?? Colors.white,
                  ),
                ),
                textStyle: TextStyle(
                  color: isDarkTheme ? Colors.white : Colors.black,
                ),
              ),
              onTap:
                  (item) => onSendTap(
                    item.text,
                    const ReplyMessage(),
                    MessageType.text,
                  ),
            ),
          ),
          (pendingImagePath != null)
              ? Positioned(
                bottom: 80,
                left: 25,
                child: SizedBox(
                  width: SizeConfig.horizontal! * 80,
                  height: SizeConfig.vertical! * 7,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "What would you like the assistant to do with this image?",
                      ),
                    ),
                  ),
                ),
              )
              : const SizedBox.shrink(),
          // Test Card
          // Positioned(
          //   top: 50,
          //   left: 25,
          //   child: SizedBox(
          //     width: SizeConfig.horizontal! * 80,
          //     height: SizeConfig.vertical! * 30,
          //     child: Card(
          //       child: Padding(
          //         padding: const EdgeInsets.all(8.0),
          //         child: MarkdownWidget(
          //           data:
          //               "The Empire State Building is a renowned skyscraper in New York City. Here's a concise overview of its size: - **Height**: It stands at **1,454 feet (443 meters)** tall, including the antenna. The building itself is **1,250 feet (380 meters)** tall, with the antenna adding **200 feet (61 meters)**",
          //         ),
          //       ),
          //     ),
          //   ),
          // ),

          // ../../../../.pub-cache/hosted/pub.dev/flutter_math_fork-0.7.4/lib/src/render/layout/layout_builder_baseline.dart:26:9: Error: Type
          // 'RenderObjectWithLayoutCallbackMixin' not found.
          //         RenderObjectWithLayoutCallbackMixin,
          //         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
          // ../../../../.pub-cache/hosted/pub.dev/flutter_math_fork-0.7.4/lib/src/render/layout/layout_builder_baseline.dart:23:7: Error: The
          // type 'RenderObjectWithLayoutCallbackMixin' can't be mixed in.
          // class _RenderLayoutBuilderPreserveBaseline extends RenderBox
          //       ^
          // ../../../../.pub-cache/hosted/pub.dev/flutter_math_fork-0.7.4/lib/src/render/layout/layout_builder_baseline.dart:63:5: Error: The
          // method 'runLayoutCallback' isn't defined for the class '_RenderLayoutBuilderPreserveBaseline'.
          //  - '_RenderLayoutBuilderPreserveBaseline' is from 'package:flutter_math_fork/src/render/layout/layout_builder_baseline.dart'
          //  ('../../../../.pub-cache/hosted/pub.dev/flutter_math_fork-0.7.4/lib/src/render/layout/layout_builder_baseline.dart').
          // Try correcting the name to the name of an existing method, or defining a method named 'runLayoutCallback'.
          //     runLayoutCallback();// Positioned(
          //   top: 400,
          //   left: 25,
          //   child: SizedBox(
          //     width: SizeConfig.horizontal! * 80,
          //     height: SizeConfig.vertical! * 30,
          //     child: Card(
          //       child: Padding(
          //         padding: const EdgeInsets.all(8.0),
          //         child: GptMarkdown(
          //           "The Empire State Building is a renowned skyscraper in New York City. Here's a concise overview of its size: - **Height**: It stands at **1,454 feet (443 meters)** tall, including the antenna. The building itself is **1,250 feet (380 meters)** tall, with the antenna adding **200 feet (61 meters)**",
          //         ),
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
      bottomNavigationBar: Navbar(currentIndex: 3),
    );
  }
}

class ChatbotSettingsPopup extends StatefulWidget {
  ChatbotSettingsPopup({
    super.key,
    required this.isDarkTheme,
    required this.onThemeToggle,
  });

  bool isDarkTheme;
  final Function(bool) onThemeToggle;

  @override
  State<ChatbotSettingsPopup> createState() => _ChatbotSettingsPopupState();
}

class _ChatbotSettingsPopupState extends State<ChatbotSettingsPopup> {
  bool streamingEnabled = false;
  late SharedPreferences prefs;

  // Load the streaming preference from SharedPreferences
  Future<void> loadPreferences() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      streamingEnabled = prefs.getBool('streamingEnabled') ?? false;
    });
  }

  @override
  void initState() {
    super.initState();
    loadPreferences();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chatbot Settings'),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            // const Text('Settings 1'),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Chatbot Name',
                border: OutlineInputBorder(),
                hintText: 'Give your chatbot a name!',
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Theme: ", style: TextStyle(fontSize: 16)),
                IconButton(
                  onPressed: () {
                    widget.onThemeToggle(!widget.isDarkTheme);

                    // change for this popup too
                    setState(() {
                      widget.isDarkTheme = !widget.isDarkTheme;
                    });
                  },
                  icon: Icon(
                    widget.isDarkTheme
                        ? Icons.brightness_4_outlined
                        : Icons.dark_mode_outlined,
                    // color: theme.themeIconColor,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Streaming: ", style: TextStyle(fontSize: 16)),
                Switch.adaptive(
                  value: streamingEnabled,
                  onChanged: (value) {
                    setState(() {
                      streamingEnabled = value;
                      prefs.setBool('streamingEnabled', value);
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Close'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
