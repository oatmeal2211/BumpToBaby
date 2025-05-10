import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Import for Timer
import 'dart:io'; // Import for File operations
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // Import for Markdown rendering
import 'package:shared_preferences/shared_preferences.dart'; // Import for shared_preferences
import 'package:flutter/services.dart'; // Add this line
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart'; // Import for image picking

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
  // For search functionality
  List<Map<String, dynamic>> _filteredMessages = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // Variable for prompt engineering - you can set your base prompt here
  String _systemPrompt = "You are a helpful and empathetic AI assistant for pregnant mothers. Your name is BumpToBaby AI but no need to mention it in the response unless the user asks who you are. Provide support and information related to pregnancy. Try not to repeat the responses given provided based on the chat history. Explain those professional medical terms in a way that is easy to understand like pregnanct women is on her first pregnancy. Keep responses conscise and brief. Use markdown for better view formatting. Be more casual and conversational.";

  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false; // To show a loading indicator during API calls
  
  // For image handling
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  
  // Hardcoded response for image messages - now an array
  final List<String> _imageResponses = [
    "Thank you for sharing the image. It appears that there is swelling in the leg. Swelling in the legs during pregnancy is quite common, especially in the later stages, due to increased fluid retention and pressure from the growing uterus. However, certain types of swelling may require medical attention.\\n\\nI recommend she be seen by a healthcare provider to ensure everything is progressing safely. It's always better to have a professional examine the condition directly to provide appropriate care and peace of mind.",
    "Thank you for sharing the image. The photo shows a visible rash on your abdomen. Mild skin changes and itchiness can be common during pregnancy due to stretching skin and hormonal changes. However, certain rashes—especially if they are widespread or very itchy—may require further evaluation. I recommend showing this to a healthcare provider to rule out any pregnancy-specific skin conditions such as PUPPP or other causes. They can help you find safe ways to relieve the discomfort.",
    "Thank you for sharing the image. The dark vertical line on your belly, known as linea nigra, is a normal skin change that occurs during pregnancy due to hormonal shifts. It's completely harmless and usually fades on its own after delivery. There's no need to worry, but feel free to ask if you notice any sudden changes or have concerns about your skin during pregnancy."
  ];
  int _imageResponseIndex = 0; // Counter for cycling through image responses

  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false; // Track if TTS is currently active
  String? _currentlyPlayingMessageId; // Track which message is being read

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
    
    // Set up TTS completion listener
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _currentlyPlayingMessageId = null;
        });
      }
    });
    
    // Initialize filtered messages with all messages
    _filteredMessages = List.from(_messages);
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final String? messagesJson = prefs.getString('chat_messages');
    if (messagesJson != null) {
      try {
        final List<dynamic> decodedMessages = jsonDecode(messagesJson);
        if (mounted) { // Check if the widget is still in the tree
            setState(() {
                _messages.addAll(decodedMessages.map((item) => Map<String, dynamic>.from(item as Map)).toList());
                _filteredMessages = List.from(_messages); // Update filtered messages here
            });
        }
      } catch (e) {
        if (kDebugMode) {
          print("Error loading messages: $e");
        }
      }
    } else {
      // If there are no saved messages, ensure filteredMessages is also empty or initialized appropriately
      if (mounted) {
        setState(() {
          _filteredMessages = List.from(_messages); // Should be empty if _messages is empty
        });
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

  // Function to pick image from gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error picking image: $e");
      }
    }
  }

  // Show image source selection dialog
  Future<void> _showImageSourceDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                GestureDetector(
                  child: const Text('Take a Photo'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickImage(ImageSource.camera);
                  },
                ),
                const Padding(padding: EdgeInsets.all(8.0)),
                GestureDetector(
                  child: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // Function to handle sending messages (text or image)
  Future<void> _handleSendMessage() async {
    if (_selectedImage != null) {
      final File imageToSend = _selectedImage!; // Capture the image
      setState(() {
        _selectedImage = null; // Clear the preview IMMEDIATELY
      });
      await _sendImageMessage(imageToSend); // Process the captured image
    } else if (_textController.text.isNotEmpty) {
      // If there is text and no image, send text message to Gemini API
      await _sendMessage(_textController.text);
    }
  }
  
  // Function to send image message
  Future<void> _sendImageMessage(File imageFile) async { // Accept File as parameter
    // No longer need to check _selectedImage here as imageFile is passed
    
    final userImageMsg = {
      "isUser": true, 
      "hasImage": true, 
      "imagePath": imageFile.path, // Use the passed imageFile
      "text": "Sent an image", 
      "time": _getCurrentTime()
    };
    final loadingMsg = {"isUser": false, "isLoadingPlaceholder": true, "time": _getCurrentTime()};
    
    setState(() {
      _messages.insert(0, userImageMsg);
      _messages.insert(0, loadingMsg); // Add loading indicator
      _isLoading = true;
    });
    await _saveMessages();
    
    // Simulate a delay before showing the hardcoded response
    await Future.delayed(const Duration(seconds: 5));

    // Add the hardcoded response for image
    if (mounted) { // Check if the widget is still in the tree
      final String currentImageResponse = _imageResponses[_imageResponseIndex];
      _imageResponseIndex = (_imageResponseIndex + 1) % _imageResponses.length; // Increment and loop

      setState(() {
        _messages.removeWhere((msg) => msg['isLoadingPlaceholder'] == true); // Remove loading indicator
        _messages.insert(0, {
          "isUser": false, 
          "text": currentImageResponse, // Use the selected response
          "time": _getCurrentTime()
        });
        _isLoading = false;
      });
      await _saveMessages();
    }
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
            _imageResponseIndex = 0; // Reset the image response counter
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

  Future<void> _speak(String text, String messageId) async {
    // If already speaking this message, stop it
    if (_isSpeaking && _currentlyPlayingMessageId == messageId) {
      await _flutterTts.stop();
      setState(() {
        _isSpeaking = false;
        _currentlyPlayingMessageId = null;
      });
      return;
    }
    
    // If speaking a different message, stop that first
    if (_isSpeaking) {
      await _flutterTts.stop();
    }
    
    // Start speaking the new message
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(text);
    
    setState(() {
      _isSpeaking = true;
      _currentlyPlayingMessageId = messageId;
    });
  }

  // Search function to filter messages
  void _searchMessages(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredMessages = List.from(_messages);
      });
      return;
    }
    
    final lowercaseQuery = query.toLowerCase();
    setState(() {
      _filteredMessages = _messages.where((message) {
        final text = message['text'] as String;
        return text.toLowerCase().contains(lowercaseQuery);
      }).toList();
    });
  }

  // Toggle search bar visibility
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredMessages = List.from(_messages);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search messages...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                style: const TextStyle(color: Color(0xFF005792)),
                onChanged: _searchMessages,
                autofocus: true,
              )
            : const Text('Health Help', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF005792))),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
            color: const Color(0xFF005792),
          ),
        ],
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
              itemCount: _filteredMessages.length,
              itemBuilder: (context, index) {
                return _buildMessage(_filteredMessages[index]);
              },
            ),
          ),
          if (_selectedImage != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                height: 100,
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Image.file(_selectedImage!, height: 90),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _selectedImage = null;
                        });
                      },
                    ),
                  ],
                ),
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
                  onPressed: _showImageSourceDialog,
                  color: Colors.blueGrey[700],
                ),
                Expanded(
                  child: Focus(
                    onKey: (FocusNode node, RawKeyEvent event) {
                      if (event is RawKeyDownEvent) {
                        if (event.isControlPressed && event.logicalKey == LogicalKeyboardKey.enter) {
                          _handleSendMessage(); // Use the new handler
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
                  onPressed: _handleSendMessage, // Use the new handler
                  color: Colors.blue[600],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    final bool isUser = message['isUser'] as bool;
    final bool hasImage = message['hasImage'] ?? false;

    if (message['isLoadingPlaceholder'] == true) {
      return const AnimatedLoadingIndicator();
    }

    final String text = message['text'] as String;
    final String time = message['time'] as String;
    // Generate a unique ID for each message
    final String messageId = message['id'] ?? '${isUser}_${time}_${text.hashCode}';
    if (message['id'] == null) {
      message['id'] = messageId;
    }

    Widget messageContent;
    if (isUser) {
      if (hasImage) {
        // Display the image in the user's message bubble
        messageContent = Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(text),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                // Show the image in a larger view
                showDialog(
                  context: context,
                  builder: (context) {
                    return Dialog(
                      child: Image.file(
                        File(message['imagePath']),
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(message['imagePath']),
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        );
      } else {
        messageContent = Text(text);
      }
    } else {
      messageContent = MarkdownBody(
        data: text,
        selectable: true, // Allows users to select and copy text from markdown
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
                  IconButton(
                    icon: Icon(
                      _isSpeaking && _currentlyPlayingMessageId == messageId
                          ? Icons.pause
                          : Icons.volume_up,
                      size: 18.0,
                      color: Colors.blue,
                    ),
                    tooltip: _isSpeaking && _currentlyPlayingMessageId == messageId
                        ? 'Stop speaking'
                        : 'Read aloud',
                    onPressed: () => _speak(text, messageId),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ]
              ],
            )
          ],
        ),
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