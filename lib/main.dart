import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() async {
  await dotenv.load(fileName: ".env");
  runApp(
    ChangeNotifierProvider(
      create: (_) => ChatProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChatGPT + Gemini Fusion',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Modèle de données
class Message {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final String? apiSource;

  Message({
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.apiSource,
  });

  Map<String, dynamic> toJson() => {
        'role': isUser ? 'user' : 'assistant',
        'content': content,
      };
}

/// Services API
class ChatService {
  static final String _apiKey = dotenv.env['OPENAI_KEY']!;
  static const String _apiUrl = 'https://api.openai.com/v1/chat/completions';

  Future<String> sendMessage(List<Map<String, dynamic>> messages) async {
    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': messages,
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['choices'][0]['message']['content'];
    } else {
      throw Exception('Erreur API: ${response.statusCode}');
    }
  }
}

class GeminiService {
  static final String _apiKey = dotenv.env['GEMINI_KEY']!;

  Future<String?> getResponse(String prompt) async {
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_apiKey',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': prompt}]}],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 1024,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      }
      return 'Erreur API: ${response.statusCode}';
    } catch (e) {
      developer.log('Erreur Gemini', error: e);
      return 'Erreur de connexion';
    }
  }
}

/// State Management
class ChatProvider with ChangeNotifier {
  final List<Message> _messages = [];
  bool _isLoading = false;
  bool _useOpenAI = true;
  String? _error;
  final ChatService _chatService = ChatService();
  final GeminiService _geminiService = GeminiService();

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get useOpenAI => _useOpenAI;
  String? get error => _error;

  Future<void> sendMessage(String text) async {
    _addUserMessage(text);
    
    try {
      final response = _useOpenAI
          ? await _chatService.sendMessage(_getContextMessages())
          : await _geminiService.getResponse(text);
      
      _addBotMessage(response ?? 'Pas de réponse', apiSource: _useOpenAI ? 'chatgpt' : 'gemini');
      _error = null;
    } catch (e) {
      _error = e.toString();
      _addBotMessage("Erreur: ${e.toString()}");
    } finally {
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> _getContextMessages() {
    return _messages.map((m) => m.toJson()).toList();
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

  void _addBotMessage(String text, {String? apiSource}) {
    _messages.add(Message(
      content: text,
      isUser: false,
      timestamp: DateTime.now(),
      apiSource: apiSource,
    ));
    _isLoading = false;
  }

  void toggleApi() {
    _useOpenAI = !_useOpenAI;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

/// UI Components
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isSpeaking;
  final VoidCallback onSpeakPressed;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isSpeaking,
    required this.onSpeakPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      decoration: BoxDecoration(
        color: message.isUser 
            ? Theme.of(context).primaryColor 
            : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.content,
            style: TextStyle(
              color: message.isUser ? Colors.white : Colors.black87,
            ),
          ),
          if (!message.isUser) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Via ${message.apiSource?.toUpperCase() ?? 'API'}',
                  style: TextStyle(
                    fontSize: 10,
                    color: message.isUser ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isSpeaking ? Icons.volume_off : Icons.volume_up,
                    size: 20,
                    color: message.isUser ? Colors.white70 : Colors.blue,
                  ),
                  onPressed: onSpeakPressed,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Screens
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  late final stt.SpeechToText _speech;
  late final FlutterTts _flutterTts;
  bool _isListening = false;
  bool _isSpeaking = false;
  int _currentSpeakingIndex = -1;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initTts();
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage('fr-FR');
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _toggleSpeech(String text, int index) async {
    if (_isSpeaking && _currentSpeakingIndex == index) {
      await _flutterTts.stop();
      setState(() {
        _isSpeaking = false;
        _currentSpeakingIndex = -1;
      });
    } else {
      if (_isSpeaking) await _flutterTts.stop();
      await _flutterTts.speak(text);
      setState(() {
        _isSpeaking = true;
        _currentSpeakingIndex = index;
      });
    }
  }

  Future<void> _startListening() async {
    final available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) => setState(() {
          _controller.text = result.recognizedWords;
        }),
      );
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  @override
  void dispose() {
    _speech.stop();
    _flutterTts.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant Intelligent'),
        actions: [
          Consumer<ChatProvider>(
            builder: (context, provider, _) => IconButton(
              icon: Icon(provider.useOpenAI ? Icons.chat : Icons.g_mobiledata),
              onPressed: provider.toggleApi,
              tooltip: 'Basculer sur ${provider.useOpenAI ? 'Gemini' : 'ChatGPT'}',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, provider, _) {
                if (provider.error != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(provider.error!)),
                    );
                    provider.clearError();
                  });
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(10),
                  itemCount: provider.messages.length,
                  itemBuilder: (context, index) {
                    final reversedIndex = provider.messages.length - 1 - index;
                    final message = provider.messages[reversedIndex];
                    return Align(
                      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: MessageBubble(
                        message: message,
                        isSpeaking: _isSpeaking && _currentSpeakingIndex == reversedIndex,
                        onSpeakPressed: () => _toggleSpeech(message.content, reversedIndex),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Consumer<ChatProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading) {
                return const LinearProgressIndicator();
              }
              return Container();
            },
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                  onPressed: _isListening ? _stopListening : _startListening,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Écrivez ou parlez...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(context),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendMessage(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage(BuildContext context) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final provider = Provider.of<ChatProvider>(context, listen: false);
    provider.sendMessage(text);
    _controller.clear();
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          child: const Text('Se connecter'),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ChatPage()),
          ),
        ),
      ),
    );
  }
}
