# ptsd_relief_app

A new Flutter project.

## Checklist
- [X] Ollama chat system functional
- [X] Find an appropriate vision capable model
- [X] Implement image upload and processing
- [X] Figma design improvments
- [X] Proper logging of chat snippets
- [X] Hardware: order a Raspberry Pi 5 and sensors
- [ ] App Publication: make Apple happy
- [ ] Bug Fixes + Feature Improvements
    - Help Screen Refinements
- [ ] Research Paper
    - [X] Section 1
    - [ ] Section 2
    - [ ] Section 3
    - [ ] Section 4
    - [ ] Section 5
    - [ ] Section 6
    - [ ] Section 7
    - [ ] Section 8


Reply Popup Pieces Path
chat_view.dart --> ChatListWidget --> ReplyPopupWidget --> PackageStrings

ChatBubble Path
chat_view.dart --> ChatListWidget --> ChatGroupedListWidget --> ChatBubbleWidget --> MessageView --> TextMessageView

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Command to start using Ollama
```bash
ollama serve
```
```bash
curl http://localhost:11434
```
Note: current rpi server is 192.168.1.162

## Pull and Manage Models
```bash
ollama pull <model_name>
```
```bash
ollama list
```
```bash
ollama show <model_name>
```
```bash
ollama rm <model_name>
```

## Run the model
```bash
ollama run <model_name> --prompt "What is the capital of France?"
```


## Models that work
- gemma3:1b
- deepseek-r1:1.5b
- qwen3:1.7b

Selected Model: **qwen3:1.7b**


# Running Ollama as a server for the flutter app
```bash
OLLAMA_HOST="0.0.0.0" ollama serve
```

## Request example (single-response)
```bash
POST /api/generate HTTP/1.1
Host: <HOST>:11434
Content-Type: application/json

{
  "model": "qwen3:1.7b",
  "prompt": "Hello, how are you?",
  "stream": true
}
```

## Request Example (chat-style)
```bash
POST /api/chat HTTP/1.1
Host: <HOST>:11434
Content-Type: application/json

{
  "model": "qwen3:1.7b",
  "messages": [
    {"role":"system","content":"You are a helpful assistant."},
    {"role":"user","content":"What’s the weather today?"}
  ],
  "stream": true
}
```




Dev Notes:
- to enable markdown rendering in the chat view, change reply_message_view.dart to use the markdown widget instead of text widget.

# ======

class PackageStrings {
  static const String today = "Today";
  static const String yesterday = "Yesterday";
  static const String repliedToYou = "Replied to you";
  static const String repliedBy = "Replied by";
  static const String more = "Save";
  static const String unsend = "Unsend";
  static const String reply = "Reply";
  static const String replyTo = "Replying to";
  static const String message = "Message";
  static const String reactionPopupTitle =
      "Tap and hold to multiply your reaction";
  static const String photo = "Photo";
  static const String send = "Send";
  static const String you = "You";
  static const String report = "";
}



# ======

/*
 * Copyright (c) 2022 Simform Solutions
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
import 'package:flutter/material.dart';

import 'package:chatview/src/extensions/extensions.dart';
import 'package:chatview/src/models/models.dart';

import '../utils/constants/constants.dart';
import 'link_preview.dart';
import 'reaction_widget.dart';
import 'package:markdown_widget/markdown_widget.dart';

class TextMessageView extends StatelessWidget {
  const TextMessageView({
    Key? key,
    required this.isMessageBySender,
    required this.message,
    this.chatBubbleMaxWidth,
    this.inComingChatBubbleConfig,
    this.outgoingChatBubbleConfig,
    this.messageReactionConfig,
    this.highlightMessage = false,
    this.highlightColor,
  }) : super(key: key);

  /// Represents current message is sent by current user.
  final bool isMessageBySender;

  /// Provides message instance of chat.
  final Message message;

  /// Allow users to give max width of chat bubble.
  final double? chatBubbleMaxWidth;

  /// Provides configuration of chat bubble appearance from other user of chat.
  final ChatBubble? inComingChatBubbleConfig;

  /// Provides configuration of chat bubble appearance from current user of chat.
  final ChatBubble? outgoingChatBubbleConfig;

  /// Provides configuration of reaction appearance in chat bubble.
  final MessageReactionConfiguration? messageReactionConfig;

  /// Represents message should highlight.
  final bool highlightMessage;

  /// Allow user to set color of highlighted message.
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final textMessage = message.message;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
            constraints: BoxConstraints(
                maxWidth: chatBubbleMaxWidth ??
                    MediaQuery.of(context).size.width * 0.75),
            padding: _padding ??
                const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
            margin: _margin ??
                EdgeInsets.fromLTRB(
                    5, 0, 6, message.reaction.reactions.isNotEmpty ? 15 : 2),
            decoration: BoxDecoration(
              color: highlightMessage ? highlightColor : _color,
              borderRadius: _borderRadius(textMessage),
            ),
            child: textMessage.isUrl
                ? LinkPreview(
                    linkPreviewConfig: _linkPreviewConfig,
                    url: textMessage,
                  )
                : MarkdownBlock(
                    data: textMessage,
                    config: MarkdownConfig(
                      configs: [
                        PConfig(
                          textStyle: _textStyle ??
                              textTheme.bodyMedium!.copyWith(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                        ),
                        TableConfig(
                          wrapper: (child) => SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: child,
                          ),
                        )
                      ],
                    ),
                  )),
        if (message.reaction.reactions.isNotEmpty)
          ReactionWidget(
            key: key,
            isMessageBySender: isMessageBySender,
            reaction: message.reaction,
            messageReactionConfig: messageReactionConfig,
          ),
      ],
    );
  }

  EdgeInsetsGeometry? get _padding => isMessageBySender
      ? outgoingChatBubbleConfig?.padding
      : inComingChatBubbleConfig?.padding;

  EdgeInsetsGeometry? get _margin => isMessageBySender
      ? outgoingChatBubbleConfig?.margin
      : inComingChatBubbleConfig?.margin;

  LinkPreviewConfiguration? get _linkPreviewConfig => isMessageBySender
      ? outgoingChatBubbleConfig?.linkPreviewConfig
      : inComingChatBubbleConfig?.linkPreviewConfig;

  TextStyle? get _textStyle => isMessageBySender
      ? outgoingChatBubbleConfig?.textStyle
      : inComingChatBubbleConfig?.textStyle;

  BorderRadiusGeometry _borderRadius(String message) => isMessageBySender
      ? outgoingChatBubbleConfig?.borderRadius ??
          (message.length < 37
              ? BorderRadius.circular(replyBorderRadius1)
              : BorderRadius.circular(replyBorderRadius2))
      : inComingChatBubbleConfig?.borderRadius ??
          (message.length < 29
              ? BorderRadius.circular(replyBorderRadius1)
              : BorderRadius.circular(replyBorderRadius2));

  Color get _color => isMessageBySender
      ? outgoingChatBubbleConfig?.color ?? Colors.purple
      : inComingChatBubbleConfig?.color ?? Colors.grey.shade500;
}
