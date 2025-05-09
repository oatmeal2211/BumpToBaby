import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Import for Timer
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // Import for Markdown rendering
import 'package:shared_preferences/shared_preferences.dart'; // Import for shared_preferences
import 'package:flutter/services.dart'; // Add this line

class HealthHelpPage extends StatefulWidget {
  const HealthHelpPage({super.key});

  @override
  State<HealthHelpPage> createState() => _HealthHelpPageState();
}

class _HealthHelpPageState extends State<HealthHelpPage> {
  int _selectedIndex = 3; // Health Help is the 4th item (index 3)
  String? _apiKey;

  // Placeholder for chat messages - now initially empty
  final List<Map<String, dynamic>> _messages = [];

  // Variable for prompt engineering - you can set your base prompt here
  String _systemPrompt = "You are a helpful and empathetic AI assistant for pregnant mothers. Your name is BumpToBaby AI but no need to mention it in the response unless the user asks who you are. Provide support and information related to pregnancy. Try not to repeat the responses given provided based on the chat history. Explain those professional medical terms in a way that is easy to understand like pregnanct women is on her first pregnancy. Keep responses conscise and brief. Use markdown for formatting. Be more casual and conversational.";

  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false; // To show a loading indicator during API calls

  @override
  void initState() {
    super.initState();
    _apiKey = dotenv.env['GEMINI_API_KEY'];
    if (_apiKey == null) {
      if (kDebugMode) {
        print("API Key not found. Make sure your .env file is set up correctly.");
      }
    }
    _loadMessages(); // Load messages when the widget initializes
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final String? messagesJson = prefs.getString('chat_messages');
    if (messagesJson != null) {
      try {
        final List<dynamic> decodedMessages = jsonDecode(messagesJson);
        // Ensure messages are loaded in the correct order if they were saved in display order
        // Since we insert at 0 for display, they are likely already in reverse chronological order in storage.
        // If not, you might need to reverse them here or save them in chronological order.
        if (mounted) { // Check if the widget is still in the tree
            setState(() {
                _messages.addAll(decodedMessages.map((item) => Map<String, dynamic>.from(item as Map)).toList());
            });
        }
      } catch (e) {
        if (kDebugMode) {
          print("Error loading messages: $e");
        }
        // Optionally clear corrupted data
        // await prefs.remove('chat_messages');
      }
    }
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    // Messages are already in reverse chronological order (_messages.insert(0, ...))
    // So they will be saved in that order.
    // When loaded, they will be added to the end, maintaining this order for display.
    final String messagesJson = jsonEncode(_messages);
    await prefs.setString('chat_messages', messagesJson);
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty || _apiKey == null) return;

    final String userMessageText = text;
    _textController.clear();

    final userMsg = {"isUser": true, "text": userMessageText, "time": _getCurrentTime()};
    final loadingMsg = {"isUser": false, "isLoadingPlaceholder": true, "time": _getCurrentTime()};

    setState(() {
      _messages.insert(0, userMsg);
      _messages.insert(0, loadingMsg);
      _isLoading = true;
    });
    await _saveMessages(); // Save after adding user message and placeholder

    String botResponse = "Sorry, something went wrong while getting a response.";
    try {
      // Limit the context to the last 5 messages
      final limitedMessages = _messages.take(10).toList(); // Get the last 10 messages
      final fullPrompt = "$_systemPrompt\n\n${limitedMessages.map((msg) => msg['text']).join('\n')}\nUser: $userMessageText\nAI:";

      // Print the concatenated message to the debug console
      if (kDebugMode) {
        print("Sending to Gemini API: $fullPrompt");
      }

      botResponse = await _callGeminiApi(userMessageText);
    } catch (e) {
      botResponse = "Sorry, I couldn't get a response: $e";
      if (kDebugMode) {
        print("Error in _sendMessage catch: $e");
      }
    } finally {
      if (mounted) {
        setState(() {
          _messages.removeWhere((msg) => msg['isLoadingPlaceholder'] == true);
          _messages.insert(0, {"isUser": false, "text": botResponse, "time": _getCurrentTime()});
          _isLoading = false;
        });
        await _saveMessages();
      }
    }
  }

  Future<void> _clearChat() async {
    if (mounted) {
        setState(() {
            _messages.clear();
        });
        await _saveMessages(); // This will save an empty list
    }
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return "${now.hour}:${now.minute.toString().padLeft(2, '0')}";
  }

  Future<String> _callGeminiApi(String userMessage) async {
    if (_apiKey == null) {
      return "Error: API Key is not configured.";
    }

    const model = "gemini-1.5-flash-latest"; // Or your preferred model
    final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_apiKey");

    final headers = {
      'Content-Type': 'application/json',
    };

    // Combine system prompt with user message for context
    final fullPrompt = "$_systemPrompt\n\n${_messages.map((msg) => msg['text']).join('\n')}\nUser: $userMessage\nAI:";

    final body = jsonEncode({
      "contents": [
        {
          "parts": [
            {"text": fullPrompt}
          ]
        }
      ],
      "generationConfig": {
        "temperature": 0.7,
        "maxOutputTokens": 1000,
      }
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody['candidates'] != null &&
            responseBody['candidates'][0]['content'] != null &&
            responseBody['candidates'][0]['content']['parts'] != null &&
            responseBody['candidates'][0]['content']['parts'][0]['text'] != null) {
          return responseBody['candidates'][0]['content']['parts'][0]['text']
              .trim();
        } else {
          if (kDebugMode) print("Error parsing Gemini response: ${response.body}");
          return "Error: Could not parse response from API. Details: ${responseBody['error']?['message'] ?? 'Unknown structure'}";
        }
      } else {
        if (kDebugMode) print("Gemini API Error ${response.statusCode}: ${response.body}");
        return "Error: API request failed with status ${response.statusCode}. Details: ${response.body}";
      }
    } catch (e) {
      if (kDebugMode) print("Error calling Gemini API: $e");
      return "Error: Failed to connect to API. $e";
    }
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    final bool isUser = message['isUser'] as bool;

    if (message['isLoadingPlaceholder'] == true) {
      return const AnimatedLoadingIndicator();
    }

    final String text = message['text'] as String;
    final String time = message['time'] as String;

    Widget messageContent;
    if (isUser) {
      messageContent = Text(text);
    } else {
      messageContent = MarkdownBody(
        data: text,
        selectable: true, // Allows users to select and copy text from markdown
        // You can customize the style sheet if needed:
        // styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(...),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: isUser ? Colors.lightBlue[100] : Colors.red[100],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15.0),
            topRight: const Radius.circular(15.0),
            bottomLeft:
                isUser ? const Radius.circular(15.0) : const Radius.circular(0),
            bottomRight:
                isUser ? const Radius.circular(0) : const Radius.circular(15.0),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            messageContent,
            const SizedBox(height: 4.0),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: const TextStyle(fontSize: 10.0, color: Colors.grey),
                ),
                if (isUser) ...[
                  const SizedBox(width: 3.0),
                  const Icon(Icons.done_all, size: 14.0, color: Colors.blue)
                ],
                if (!isUser) ...[
                  // Speaker icon was here, now removed
                  // You could add other elements specific to bot messages here later
                ]
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Help', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF005792))),
        backgroundColor: Colors.white, // Or the specific background from image
        elevation: 0, // Remove shadow if needed
        centerTitle: false, // Align title to the left
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Chat with our AI Assistant',
                        style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.brown[700]),
                      ),
                      const SizedBox(height: 2.0),
                      const Text(
                        '• Online',
                        style: TextStyle(
                          fontSize: 12.0,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red[700]),
                  tooltip: 'Clear Chat',
                  onPressed: _clearChat,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              reverse: true, // Show latest messages at the bottom
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessage(_messages[index]);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor, // Use theme card color or a specific color
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.camera_alt_outlined),
                  onPressed: () {
                    // TODO: Implement image picking
                  },
                  color: Colors.blueGrey[700],
                ),
                Expanded(
                  child: Focus(
                    onKey: (FocusNode node, RawKeyEvent event) {
                      if (event is RawKeyDownEvent) {
                        if (event.isControlPressed && event.logicalKey == LogicalKeyboardKey.enter) {
                          _sendMessage(_textController.text); // Call _sendMessage
                          return KeyEventResult.handled; // Prevent further processing
                        }
                      }
                      return KeyEventResult.ignored; // Allow other key events to be processed
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      decoration: BoxDecoration(
                        color: Colors.lightBlue[50], // Input field background
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                      child: TextField(
                        controller: _textController,
                        decoration: const InputDecoration(
                          hintText: 'Type your message here...',
                          border: InputBorder.none,
                        ),
                        keyboardType: TextInputType.multiline,
                        maxLines: 3, // Limit to 3 lines
                        minLines: 1, // Starts as a single line
                        textCapitalization: TextCapitalization.sentences,
                        scrollPhysics: const BouncingScrollPhysics(), // Make it scrollable
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.mic_none_outlined),
                  onPressed: () {
                    // TODO: Implement voice input
                  },
                  color: Colors.blueGrey[700],
                ),
                IconButton(
                  icon: const Icon(Icons.send_outlined),
                  onPressed: () {
                    _sendMessage(_textController.text); // Call _sendMessage
                  },
                  color: Colors.blue[600],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // To show all labels
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            label: 'My Schedule',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.child_care_outlined),
            label: 'Baby Tracker',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor_heart_outlined), // Using a health related icon
            activeIcon: Icon(Icons.monitor_heart),
            label: 'Health Help',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            label: 'Community',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.pink[400], // Or your app's primary color
        unselectedItemColor: Colors.grey[600],
        showUnselectedLabels: true,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            // TODO: Implement navigation to other pages
          });
        },
      ),
    );
  }
}

class AnimatedLoadingIndicator extends StatefulWidget {
  const AnimatedLoadingIndicator({super.key});

  @override
  State<AnimatedLoadingIndicator> createState() => _AnimatedLoadingIndicatorState();
}

class _AnimatedLoadingIndicatorState extends State<AnimatedLoadingIndicator> {
  int _dotCount = 0;
  Timer? _timer;
  final int _maxDots = 7; // For "[.......]"

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (mounted) {
        setState(() {
          _dotCount = (_dotCount + 1) % (_maxDots + 1);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String dotsPart = '.' * _dotCount;
    String spacesPart = ' ' * (_maxDots - _dotCount);
    String loadingTextContent = '$dotsPart$spacesPart';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.red[100],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(15.0),
            topRight: Radius.circular(15.0),
            bottomLeft: Radius.circular(0),
            bottomRight: Radius.circular(15.0),
          ),
        ),
        child: Text(
          '[$loadingTextContent]',
          style: const TextStyle(
            fontFamily: 'monospace',
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
} 