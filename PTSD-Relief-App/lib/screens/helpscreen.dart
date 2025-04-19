import 'package:flutter/material.dart';
import 'package:ptsd_relief_app/components/navbar.dart';
import 'package:chatview/chatview.dart';

class Helpscreen extends StatefulWidget {
  const Helpscreen({super.key});

  @override
  State<Helpscreen> createState() => _HelpscreenState();
}

class _HelpscreenState extends State<Helpscreen> {
  late List<Message> messageList;

  late final ChatController chatController;

  void onSendTap(
    String message,
    ReplyMessage replyMessage,
    MessageType messageType,
  ) {
    final message = Message(
      id: '3',
      message: "How are you",
      createdAt: DateTime.now(),
      sentBy: "user1",
      replyMessage: replyMessage,
      messageType: messageType,
    );
    chatController.addMessage(message);
  }

  @override
  void initState() {
    super.initState();
    messageList = [
      Message(
        id: '1',
        message: "Hi",
        createdAt: DateTime.now(),
        sentBy: "Flutter",
      ),
      Message(
        id: '2',
        message: "Hello",
        createdAt: DateTime.now(),
        sentBy: "Simform",
      ),
    ];

    chatController = ChatController(
      initialMessageList: messageList,
      scrollController: ScrollController(),
      currentUser: ChatUser(id: '1', name: 'Flutter'),
      otherUsers: [ChatUser(id: '2', name: 'Simform')],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Home Screen'),
      // ),
      body: ChatView(
        chatController: chatController,
        onSendTap: onSendTap,
        chatViewState: ChatViewState.hasMessages,
      ),
      bottomNavigationBar: Navbar(currentIndex: 3),
    );
  }
}
