import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant ChatGPT'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, provider, _) {
                return ListView.builder(
                  reverse: true,
                  itemCount: provider.messages.length,
                  itemBuilder: (context, index) {
                    final message = provider.messages.reversed.toList()[index];
                    return MessageBubble(message: message);
                  },
                );
              },
            ),
          ),
          const ChatInput(),
        ],
      ),
    );
  }
}