import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final uri = Uri.parse('$ollamaUrl/api/chat');
    print('Sending request to: $uri');
    print('Image path: $imagePath');

    // 1) Read & base64 encode the image
    final bytes = await convertToPngBytes(File(imagePath));
    final base64Image = base64Encode(bytes);

    // 2) Build the JSON
    final body = jsonEncode({
      'model': 'qwen2.5vl:3b',
      'stream': false, // Set to true if you want streaming
      'messages': [
        {
          'role': 'user',
          'content': prompt,
          'images': [base64Image],
        },
      ],
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
        data = await sendImage(pendingImagePath!, message);
        setState(() {
          pendingImagePath = null; // Clear the pending image path
        });
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
      Message(id: '1', message: "Hi", createdAt: DateTime.now(), sentBy: "1"),
      Message(
        id: '2',
        message: "Hello",
        createdAt: DateTime.now(),
        sentBy: "2",
      ),
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
              backgroundColor: theme.replyPopupColor,
              buttonTextStyle: TextStyle(color: theme.replyPopupButtonColor),
              topBorderColor: theme.replyPopupTopBorderColor,
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
              // imageMessageConfig: ImageMessageConfiguration(
              //   margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
              //   shareIconConfig: ShareIconConfiguration(
              //     defaultIconBackgroundColor: theme.shareIconBackgroundColor,
              //     defaultIconColor: theme.shareIconColor,
              //   ),
              // ),
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
