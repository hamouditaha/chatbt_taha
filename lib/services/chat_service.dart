import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/message.dart';

class ChatService {
  static final String _apiKey = dotenv.env['OPENAI_KEY']!;
  static const String _apiUrl = 'https://api.openai.com/v1/chat/completions';

  Future<String> sendMessage(List<Message> messages) async {
    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': messages.map((m) => m.toJson()).toList(),
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['choices'][0]['message']['content'];
    } else {
      throw Exception('Erreur API: ${response.statusCode}');
    }
  }
}