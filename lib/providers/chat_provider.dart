import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/chat_service.dart';

class ChatProvider with ChangeNotifier {
  final List<Message> _messages = [];
  bool _isLoading = false;

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;

  final ChatService _chatService = ChatService();

  Future<void> sendMessage(String text) async {
    _addUserMessage(text);
    
    try {
      final response = await _chatService.sendMessage(_messages);
      _addBotMessage(response);
    } catch (e) {
      _addBotMessage("Désolé, une erreur s'est produite");
    }
  }

  void _addUserMessage(String text) {
    _messages.add(Message(
      content: text,
      isUser: true,
      timestamp: DateTime.now(),
    ));
    _isLoading = true;
    notifyListeners();
  }

  void _addBotMessage(String text) {
    _messages.add(Message(
      content: text,
      isUser: false,
      timestamp: DateTime.now(),
    ));
    _isLoading = false;
    notifyListeners();
  }
}