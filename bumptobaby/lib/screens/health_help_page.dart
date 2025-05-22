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
import 'package:url_launcher/url_launcher.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:google_fonts/google_fonts.dart';
import 'package:bumptobaby/utils/chat_actions.dart';

class HealthHelpPage extends StatefulWidget {
  const HealthHelpPage({super.key});

  @override
  State<HealthHelpPage> createState() => _HealthHelpPageState();
}

class _HealthHelpPageState extends State<HealthHelpPage> {
  int _selectedIndex = 3; // Health Help is the 4th item (index 3)
  String? _apiKey;
  String _selectedLanguage = 'English'; // Default language
  final List<String> _languages = ['English', 'Malay', 'Chinese', 'Tamil'];

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
  
  // Hardcoded response for image messages - now an array of languages
  final Map<String, List<String>> _imageResponsesByLanguage = {
    'English': [
      "Thank you for sharing the image. It appears that there is swelling in the leg. Swelling in the legs during pregnancy is quite common, especially in the later stages, due to increased fluid retention and pressure from the growing uterus. However, certain types of swelling may require medical attention. I recommend she be seen by a healthcare provider to ensure everything is progressing safely. It's always better to have a professional examine the condition directly to provide appropriate care and peace of mind.",
      "Thank you for sharing the image. The photo shows a visible rash on your abdomen. Mild skin changes and itchiness can be common during pregnancy due to stretching skin and hormonal changes. However, certain rashes—especially if they are widespread or very itchy—may require further evaluation. I recommend showing this to a healthcare provider to rule out any pregnancy-specific skin conditions such as PUPPP or other causes. They can help you find safe ways to relieve the discomfort.",
      "Thank you for sharing the image. The dark vertical line on your belly, known as linea nigra, is a normal skin change that occurs during pregnancy due to hormonal shifts. It's completely harmless and usually fades on its own after delivery. There's no need to worry, but feel free to ask if you notice any sudden changes or have concerns about your skin during pregnancy."
    ],
    'Malay': [
      "Terima kasih kerana berkongsi gambar. Kelihatan bahawa terdapat bengkak di kaki. Bengkak di kaki semasa kehamilan agak biasa, terutamanya pada peringkat akhir, disebabkan oleh peningkatan pengekalan cecair dan tekanan dari rahim yang semakin membesar. Namun, jenis bengkak tertentu mungkin memerlukan perhatian perubatan. Saya cadangkan dia berjumpa dengan penyedia penjagaan kesihatan untuk memastikan segalanya berkembang dengan selamat. Lebih baik mempunyai profesional memeriksa keadaan secara langsung untuk memberikan penjagaan yang sesuai dan ketenangan fikiran.",
      "Terima kasih kerana berkongsi gambar. Foto menunjukkan ruam yang kelihatan pada perut anda. Perubahan kulit ringan dan gatal boleh menjadi perkara biasa semasa kehamilan disebabkan oleh kulit yang meregang dan perubahan hormon. Namun, ruam tertentu—terutamanya jika ia tersebar luas atau sangat gatal—mungkin memerlukan penilaian lanjut. Saya cadangkan anda menunjukkannya kepada penyedia penjagaan kesihatan untuk menyingkirkan sebarang keadaan kulit khusus kehamilan seperti PUPPP atau sebab lain. Mereka boleh membantu anda mencari cara yang selamat untuk melegakan ketidakselesaan.",
      "Terima kasih kerana berkongsi gambar. Garis menegak gelap di perut anda, yang dikenali sebagai linea nigra, adalah perubahan kulit normal yang berlaku semasa kehamilan disebabkan oleh perubahan hormon. Ia sama sekali tidak berbahaya dan biasanya pudar dengan sendirinya selepas kelahiran. Tidak perlu risau, tetapi jangan ragu untuk bertanya jika anda perasan sebarang perubahan mendadak atau mempunyai kebimbangan tentang kulit anda semasa kehamilan."
    ],
    'Chinese': [
      "感谢分享图片。看起来腿部有肿胀。妊娠期间腿部肿胀是很常见的，尤其是在后期，这是由于体液潴留增加和子宫增大造成的压力。然而，某些类型的肿胀可能需要医疗关注。我建议她去看医疗保健提供者，确保一切进展安全。最好让专业人士直接检查这种情况，以提供适当的护理和安心。",
      "感谢分享图片。照片显示您腹部有明显的皮疹。妊娠期间轻微的皮肤变化和瘙痒很常见，这是由于皮肤拉伸和荷尔蒙变化引起的。然而，某些皮疹，尤其是分布广泛或非常瘙痒的，可能需要进一步评估。我建议您将此展示给医疗保健提供者，以排除任何与妊娠相关的特定皮肤状况，如PUPPP或其他原因。他们可以帮助您找到缓解不适的安全方法。",
      "感谢分享图片。您腹部的深色垂直线，被称为妊娠线（linea nigra），是由于荷尔蒙变化而在妊娠期间出现的正常皮肤变化。它完全无害，通常在分娩后自行褪色。不需要担心，但如果您注意到任何突然变化或对妊娠期间的皮肤有任何疑虑，请随时询问。"
    ],
    'Tamil': [
      "படத்தைப் பகிர்ந்தமைக்கு நன்றி. காலில் வீக்கம் இருப்பதாகத் தெரிகிறது. கர்ப்பகாலத்தில் கால்களில் வீக்கம் மிகவும் பொதுவானது, குறிப்பாக பிற்கால கட்டங்களில், அதிகரித்த திரவ தக்கவைப்பு மற்றும் வளரும் கருப்பையின் அழுத்தம் காரணமாக. எனினும், சில வகையான வீக்கங்கள் மருத்துவ கவனிப்பு தேவைப்படலாம். எல்லாம் பாதுகாப்பாக முன்னேறுகிறதா என்பதை உறுதிப்படுத்த அவரை ஒரு சுகாதார வழங்குநரால் பார்க்க வேண்டும் என்று பரிந்துரைக்கிறேன். பொருத்தமான பராமரிப்பு மற்றும் மன அமைதி வழங்க நிலைமையை நேரடியாக ஒரு நிபுணர் பரிசோதிப்பது எப்போதும் சிறந்தது.",
      "படத்தைப் பகிர்ந்தமைக்கு நன்றி. புகைப்படம் உங்கள் வயிற்றில் தெளிவான அரிப்பைக் காட்டுகிறது. இலேசான தோல் மாற்றங்கள் மற்றும் அரிப்பு கர்ப்பகாலத்தில் பொதுவானவை, இது தோல் விரிவடைதல் மற்றும் ஹார்மோன் மாற்றங்கள் காரணமாக. இருப்பினும், சில அரிப்புகள்—குறிப்பாக அவை பரவலாக இருந்தால் அல்லது மிகவும் அரிப்பாக இருந்தால்—மேலும் மதிப்பீடு தேவைப்படலாம். PUPPP போன்ற கர்ப்பகால குறிப்பிட்ட தோல் நிலைகள் அல்லது பிற காரணங்களை விலக்குவதற்கு இதை ஒரு சுகாதார வழங்குநருக்குக் காட்டுமாறு பரிந்துரைக்கிறேன். அசௌகரியத்தைத் தணிக்க பாதுகாப்பான வழிகளைக் கண்டுபிடிக்க அவர்கள் உங்களுக்கு உதவ முடியும்.",
      "படத்தைப் பகிர்ந்தமைக்கு நன்றி. உங்கள் வயிற்றில் உள்ள கருமையான செங்குத்து கோடு, லினியா நைக்ரா என்று அழைக்கப்படுகிறது, இது ஹார்மோன் மாற்றங்கள் காரணமாக கர்ப்பகாலத்தில் ஏற்படும் ஒரு சாதாரண தோல் மாற்றம். இது முற்றிலும் தீங்கற்றது மற்றும் பொதுவாக பிரசவத்திற்குப் பிறகு தானாகவே மறைந்துவிடும். கவலைப்பட வேண்டிய அவசியமில்லை, ஆனால் திடீர் மாற்றங்களைக் கவனித்தால் அல்லது கர்ப்பகாலத்தில் உங்கள் தோல் பற்றிய கவலைகள் இருந்தால் தயங்காமல் கேளுங்கள்."
    ]
  };
  int _imageResponseIndex = 0; // Counter for cycling through image responses

  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false; // Track if TTS is currently active
  String? _currentlyPlayingMessageId; // Track which message is being read

  // For speech recognition
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  // Add suggestion questions
  final List<String> _initialSuggestions = [
    "What are common pregnancy symptoms?",
    "How to track my baby's growth?",
    "What foods should I avoid during pregnancy?",
    "When should I see a doctor?"
  ];

  // Add initial greeting messages by language
  final Map<String, String> _greetingsByLanguage = {
    'English': """Hello! 👋 I'm your pregnancy companion, here to help you with any questions about your pregnancy journey.

Here are some questions you might want to ask:""",
    'Malay': """Hai! 👋 Saya adalah rakan kehamilan anda, di sini untuk membantu anda dengan sebarang soalan tentang perjalanan kehamilan anda.

Berikut adalah beberapa soalan yang mungkin ingin anda tanyakan:""",
    'Chinese': """你好！👋 我是您的妊娠伴侣，在这里帮助您解答关于妊娠旅程的任何问题。

以下是一些您可能想问的问题：""",
    'Tamil': """வணக்கம்! 👋 நான் உங்கள் கர்ப்பகால துணை, உங்கள் கர்ப்பகால பயணம் பற்றிய எந்த கேள்விகளுக்கும் உதவ இங்கே இருக்கிறேன்.

நீங்கள் கேட்க விரும்பக்கூடிய சில கேள்விகள் இங்கே:"""
  };

  @override
  void initState() {
    super.initState();
    _apiKey = dotenv.env['GEMINI_API_KEY'];
    if (_apiKey == null) {
      if (kDebugMode) {
        print("API Key not found. Make sure your .env file is set up correctly.");
      }
    }
    _loadMessages();
    _loadLanguagePreference();
    
    _initSpeech();
    
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _currentlyPlayingMessageId = null;
        });
      }
    });
    
    _filteredMessages = List.from(_messages);

    // Add initial greeting after a short delay only if there are no messages
    Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _messages.isEmpty) { // Check if there are no chat messages
            _sendInitialGreeting();
        }
    });
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
      final String messageText = _textController.text;
      // Check for "preeclampsia" keyword
      if (messageText.toLowerCase().contains("preeclampsia")) {
        // Handle preeclampsia mock response
        _textController.clear(); // Clear the input field

        final userMsg = {"isUser": true, "text": messageText, "time": _getCurrentTime()};
        final loadingMsg = {"isUser": false, "isLoadingPlaceholder": true, "time": _getCurrentTime()};

        setState(() {
          _messages.insert(0, userMsg);
          _messages.insert(0, loadingMsg);
          _filteredMessages = List.from(_messages); // Update filtered messages
          _isLoading = true;
        });
        await _saveMessages();

        await Future.delayed(const Duration(seconds: 3)); // 3-second delay

        // Default English response
        String preeclampsiaResponse = """
Oh dear! Preeclampsia is something that can happen during pregnancy—usually after 20 weeks—when your blood pressure gets too high and your body starts showing signs that it's under a bit of stress, like protein showing up in your urine.

You might not feel anything at all, or you could notice swelling (especially in your hands and face), headaches that won't go away, blurry vision or seeing spots, and pain in your upper belly. It can creep up silently, which is why your prenatal visits are super important—they help catch it early!

If it gets more serious, doctors may need to step in and, in some cases, deliver the baby early to keep both of you safe. But don't panic—there are ways to manage it, and your healthcare team will guide you through.

This info is highly credible—it's a simple summary of an article from WebMD, which is medically reviewed by doctors.

Want to read the full article? You can check it out here: [https://www.webmd.com/baby/what-is-preeclampsia](https://www.webmd.com/baby/what-is-preeclampsia)

Would you like to open this link?
""";

        // Adjust response based on selected language
        if (_selectedLanguage == 'Malay') {
          preeclampsiaResponse = """
Aduh! Preeklampsia adalah sesuatu yang boleh berlaku semasa kehamilan—biasanya selepas 20 minggu—apabila tekanan darah anda terlalu tinggi dan badan anda mula menunjukkan tanda-tanda bahawa ia berada di bawah tekanan, seperti protein yang muncul dalam air kencing anda.

Anda mungkin tidak merasakan apa-apa, atau anda mungkin perasan bengkak (terutamanya di tangan dan muka), sakit kepala yang tidak hilang, penglihatan kabur atau melihat bintik-bintik, dan sakit di bahagian atas perut. Ia boleh datang secara senyap, itulah sebabnya lawatan pranatal anda sangat penting—mereka membantu mengesan awal!

Jika ia menjadi lebih serius, doktor mungkin perlu campur tangan dan, dalam beberapa kes, melahirkan bayi awal untuk memastikan kedua-dua anda selamat. Tetapi jangan panik—ada cara untuk menguruskannya, dan pasukan penjagaan kesihatan anda akan membimbing anda.

Maklumat ini sangat dipercayai—ia adalah ringkasan mudah artikel dari WebMD, yang disemak secara perubatan oleh doktor.

Ingin membaca artikel penuh? Anda boleh lihat di sini: [https://www.webmd.com/baby/what-is-preeclampsia](https://www.webmd.com/baby/what-is-preeclampsia)

Adakah anda ingin membuka pautan ini?
""";
        } else if (_selectedLanguage == 'Chinese') {
          preeclampsiaResponse = """
哎呀！子痫前症是一种可能在妊娠期间发生的情况—通常在20周后—当您的血压过高，您的身体开始显示出压力迹象，如尿液中出现蛋白质。

您可能完全没有感觉，或者您可能会注意到肿胀（尤其是手部和面部），持续不退的头痛，视力模糊或看到斑点，以及上腹部疼痛。它可能悄悄出现，这就是为什么您的产前检查非常重要—它们有助于早期发现！

如果情况变得更严重，医生可能需要介入，在某些情况下，提前分娩以确保您和宝宝的安全。但不要惊慌—有方法可以管理它，您的医疗团队会指导您。

这些信息非常可靠—这是WebMD文章的简单总结，经过医生的医学审核。

想阅读完整文章？您可以在这里查看：[https://www.webmd.com/baby/what-is-preeclampsia](https://www.webmd.com/baby/what-is-preeclampsia)

您想打开这个链接吗？
""";
        } else if (_selectedLanguage == 'Tamil') {
          preeclampsiaResponse = """
அடடா! முன்-கிளாம்சியா என்பது கர்ப்பகாலத்தில் ஏற்படக்கூடிய ஒன்று—பொதுவாக 20 வாரங்களுக்குப் பிறகு—உங்கள் இரத்த அழுத்தம் மிக அதிகமாக இருக்கும்போது மற்றும் உங்கள் உடல் அழுத்தத்தில் இருப்பதற்கான அறிகுறிகளைக் காட்டத் தொடங்கும், சிறுநீரில் புரதம் தோன்றுவது போன்றவை.

நீங்கள் எதையும் உணராமல் இருக்கலாம், அல்லது வீக்கம் (குறிப்பாக உங்கள் கைகள் மற்றும் முகத்தில்), தொடர்ந்து இருக்கும் தலைவலி, மங்கலான பார்வை அல்லது புள்ளிகளைப் பார்ப்பது, மற்றும் உங்கள் மேல் வயிற்றில் வலி போன்றவற்றைக் கவனிக்கலாம். இது அமைதியாக வரலாம், அதனால்தான் உங்கள் கர்ப்பகால பரிசோதனைகள் மிகவும் முக்கியமானவை—அவை ஆரம்பத்திலேயே கண்டறிய உதவுகின்றன!

அது மிகவும் தீவிரமானால், மருத்துவர்கள் தலையிட வேண்டியிருக்கலாம், சில சமயங்களில், உங்கள் இருவரின் பாதுகாப்பிற்காக குழந்தையை முன்கூட்டியே பிரசவிக்க வேண்டியிருக்கலாம். ஆனால் பதற்றமடைய வேண்டாம்—இதை நிர்வகிக்க வழிகள் உள்ளன, மற்றும் உங்கள் சுகாதார குழு உங்களுக்கு வழிகாட்டும்.

இந்த தகவல் மிகவும் நம்பகமானது—இது WebMD கட்டுரையின் எளிய சுருக்கம், மருத்துவர்களால் மருத்துவ ரீதியாக மதிப்பாய்வு செய்யப்பட்டது.

முழு கட்டுரையை படிக்க விரும்புகிறீர்களா? நீங்கள் இங்கே பார்க்கலாம்: [https://www.webmd.com/baby/what-is-preeclampsia](https://www.webmd.com/baby/what-is-preeclampsia)

இந்த இணைப்பைத் திறக்க விரும்புகிறீர்களா?
""";
        }

        if (mounted) {
          setState(() {
            _messages.removeWhere((msg) => msg['isLoadingPlaceholder'] == true);
            _messages.insert(0, {"isUser": false, "text": preeclampsiaResponse, "time": _getCurrentTime()});
            _filteredMessages = List.from(_messages); // Update filtered messages
            _isLoading = false;
          });
          await _saveMessages();
        }
      } else {
        // If not preeclampsia, send text message to Gemini API
        await _sendMessage(messageText);
      }
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
      _filteredMessages = List.from(_messages); // Update filtered messages
      _isLoading = true;
    });
    await _saveMessages();
    
    // Simulate a delay before showing the hardcoded response
    await Future.delayed(const Duration(seconds: 5));

    // Add the hardcoded response for image in the selected language
    if (mounted) { // Check if the widget is still in the tree
      // Get responses for the selected language, or fall back to English
      final List<String> responses = _imageResponsesByLanguage[_selectedLanguage] ?? 
                                    _imageResponsesByLanguage['English']!;
      
      final String currentImageResponse = responses[_imageResponseIndex];
      _imageResponseIndex = (_imageResponseIndex + 1) % responses.length; // Increment and loop

      setState(() {
        _messages.removeWhere((msg) => msg['isLoadingPlaceholder'] == true); // Remove loading indicator
        _messages.insert(0, {
          "isUser": false, 
          "text": currentImageResponse, // Use the selected response
          "time": _getCurrentTime()
        });
        _filteredMessages = List.from(_messages); // Update filtered messages
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
      _filteredMessages = List.from(_messages);
      _isLoading = true;
    });
    await _saveMessages();

    String botResponse = "Sorry, something went wrong while getting a response.";
    List<ChatAction>? actions;

    try {
      final limitedMessages = _messages.take(10).toList();
      final fullPrompt = "$_systemPrompt\n\n${limitedMessages.map((msg) => msg['text']).join('\n')}\nUser: $userMessageText\nAI:";

      if (kDebugMode) {
        print("Sending to Gemini API: $fullPrompt");
      }

      botResponse = await _callGeminiApi(userMessageText);
      
      // Create a set to avoid duplicate actions
      final Set<ChatAction> actionSet = {};
      
      // Check for keywords and add relevant actions
      final response = botResponse.toLowerCase();
      
      if (response.contains("growth") || 
          response.contains("weight") ||
          response.contains("height") ||
          response.contains("measurement") ||
          response.contains("development") ||
          response.contains("milestone")) {
        actionSet.add(ChatActionHandler.growthTracker);
      }
      
      if (response.contains("nutrition") || 
          response.contains("food") ||
          response.contains("diet") ||
          response.contains("meal") ||
          response.contains("eat") ||
          response.contains("vitamin") ||
          response.contains("supplement")) {
        actionSet.add(ChatActionHandler.nutritionGuide);
      }
      
      if (response.contains("health") || 
          response.contains("checkup") ||
          response.contains("monitor") ||
          response.contains("track") ||
          response.contains("lifestyle")||
          response.contains("mood")||
          response.contains("sleep")||
          response.contains("vaccination")||
          response.contains("schedule")) {
        actionSet.add(ChatActionHandler.healthTracker);
      }

      if (response.contains("family plan") || 
          response.contains("contraception") ||
          response.contains("birth control") ||
          response.contains("conception") ||
          response.contains("trying to conceive") ||
          response.contains("fertility") ||
          response.contains("pregnant")||
          response.contains("have a baby")||
          response.contains("want a baby")) {
        actionSet.add(ChatActionHandler.familyPlanning);
      }

      if (response.contains("clinic") || 
          response.contains("hospital") ||
          response.contains("doctor") ||
          response.contains("medical center") ||
          response.contains("healthcare provider") ||
          response.contains("appointment") ||
          response.contains("checkup") ||
          response.contains("nearby") ||
          response.contains("location")||
          response.contains("vaccination")) {
        actionSet.add(ChatActionHandler.nearestClinic);
      }

      if (response.contains("community") || 
          response.contains("support group") ||
          response.contains("forum") ||
          response.contains("chat") ||
          response.contains("connect") ||
          response.contains("share") ||
          response.contains("experience") ||
          response.contains("other moms") ||
          response.contains("discussion")) {
        actionSet.add(ChatActionHandler.community);
      }

      if (response.contains("learn") || 
          response.contains("video") ||
          response.contains("audio") ||
          response.contains("watch") ||
          response.contains("listen") ||
          response.contains("resource") ||
          response.contains("guide") ||
          response.contains("tutorial") ||
          response.contains("education")) {
        actionSet.add(ChatActionHandler.audioVisualLearning);
      }

      // Convert set to list if any actions were added
      if (actionSet.isNotEmpty) {
        actions = actionSet.toList();
      }
    } catch (e) {
      botResponse = "Sorry, I couldn't get a response: $e";
      if (kDebugMode) {
        print("Error in _sendMessage catch: $e");
      }
    } finally {
      if (mounted) {
        setState(() {
          _messages.removeWhere((msg) => msg['isLoadingPlaceholder'] == true);
          _messages.insert(0, {
            "isUser": false, 
            "text": botResponse, 
            "time": _getCurrentTime(),
            if (actions != null) "actions": actions.map((a) => a.toJson()).toList(),
          });
          _filteredMessages = List.from(_messages);
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
            _filteredMessages.clear(); // Clear filtered messages too
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

    // Adjust system prompt based on selected language
    String languageInstruction = "";
    if (_selectedLanguage != 'English') {
      languageInstruction = "Please respond in $_selectedLanguage language. ";
    }
    
    // Combine system prompt with user message for context
    final fullPrompt = "$_systemPrompt $languageInstruction\n\n${_messages.map((msg) => msg['text']).join('\n')}\nUser: $userMessage\nAI:";

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
    
    // Set language based on the selected language
    String ttsLanguage = "en-US"; // Default English
    switch (_selectedLanguage) {
      case 'Malay':
        ttsLanguage = "ms-MY"; // Malaysian Malay
        break;
      case 'Chinese':
        ttsLanguage = "zh-CN"; // Mandarin Chinese
        break;
      case 'Tamil':
        ttsLanguage = "ta-IN"; // Tamil (India)
        break;
      default:
        ttsLanguage = "en-US"; // Default to English
    }
    
    // Start speaking the new message
    await _flutterTts.setLanguage(ttsLanguage);
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

  // Load language preference from shared preferences
  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedLanguage = prefs.getString('selected_language');
    if (savedLanguage != null && _languages.contains(savedLanguage)) {
      setState(() {
        _selectedLanguage = savedLanguage;
      });
    }
  }

  // Save language preference to shared preferences
  Future<void> _saveLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', _selectedLanguage);
  }

  // Initialize speech recognition
  Future<void> _initSpeech() async {
    // Simple initialization - we'll handle more specific configuration when we start listening
    try {
      await _speech.initialize(
        onStatus: (status) {
          if (kDebugMode) {
            print('Speech recognition status: $status');
          }
          // If status indicates the recognition is done, update state
          if (status == 'done' && mounted) {
            setState(() {
              _isListening = false;
            });
          }
        },
        onError: (errorNotification) {
          if (kDebugMode) {
            print('Speech recognition error: $errorNotification');
          }
          if (mounted) {
            setState(() {
              _isListening = false;
            });
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('Speech recognition initialization error: $e');
      }
      // We'll handle this gracefully - speech might not be available on all devices
    }
  }

  // Start listening for speech
  void _startListening() async {
    // Map selected language to locale code for speech recognition
    String localeId = 'en_US'; // Default English
    switch (_selectedLanguage) {
      case 'Malay':
        localeId = 'ms_MY';
        break;
      case 'Chinese':
        localeId = 'zh_CN';
        break;
      case 'Tamil':
        localeId = 'ta_IN';
        break;
      default:
        localeId = 'en_US';
    }

    try {
      if (_isListening) {
        // Already listening, so stop
        _speech.stop();
        setState(() {
          _isListening = false;
        });
      } else {
        // Not listening, so start
        setState(() {
          _isListening = true;
        });
        
        // We don't need to initialize again here as we already did in initState
        // Just start listening directly
        await _speech.listen(
          onResult: (result) {
            setState(() {
              _textController.text = result.recognizedWords;
              // If recognition is done, update UI
              if (result.finalResult) {
                _isListening = false;
              }
            });
          },
          localeId: localeId,
          listenFor: const Duration(seconds: 30), // Listen for up to 30 seconds
          pauseFor: const Duration(seconds: 3), // Auto-stop after 3 seconds of silence
          cancelOnError: true,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error during speech recognition: $e");
      }
      setState(() {
        _isListening = false;
      });
      
      // Show a user-friendly error message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech recognition is not available on this device'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Send initial greeting message
  void _sendInitialGreeting() {
    final greeting = _greetingsByLanguage[_selectedLanguage] ?? _greetingsByLanguage['English']!;
    
    setState(() {
      _messages.insert(0, {
        "isUser": false,
        "text": greeting,
        "time": _getCurrentTime(),
        "showSuggestions": true // Flag to show suggestion buttons
      });
      _filteredMessages = List.from(_messages);
    });
    _saveMessages();
  }

  // Handle suggestion button tap
  void _handleSuggestionTap(String suggestion) {
    _textController.text = suggestion;
    _handleSendMessage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
            : Row(
                children: [
                  Text(
                    'Health Help', 
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Language dropdown
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: DropdownButton<String>(
                      value: _selectedLanguage,
                      icon: const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white),
                      underline: Container(), // Remove the default underline
                      dropdownColor: Color(0xFF1E6091),
                      items: _languages.map((String language) {
                        return DropdownMenuItem<String>(
                          value: language,
                          child: Row(
                            children: [
                              const Icon(Icons.language, size: 18, color: Colors.white), // Language icon
                              const SizedBox(width: 8), // Space between icon and text
                              Text(
                                language, 
                                style: const TextStyle(
                                  fontSize: 14, 
                                  color: Colors.white
                                )
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedLanguage = newValue;
                          });
                          _saveLanguagePreference(); // Save language preference
                          // Consider adding a message informing the user that the language has changed
                          if (_messages.isNotEmpty) {
                            setState(() {
                              _messages.insert(0, {
                                "isUser": false,
                                "text": "Language changed to $_selectedLanguage. I'll respond in $_selectedLanguage from now on.",
                                "time": _getCurrentTime()
                              });
                              _filteredMessages = List.from(_messages);
                            });
                            _saveMessages();
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
        backgroundColor: Color(0xFF1E6091),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
            color: Colors.white,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Container(
              color: Colors.white,
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
                          style: GoogleFonts.poppins(
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E6091)),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          '• Online',
                          style: GoogleFonts.poppins(
                            fontSize: 12.0,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Color(0xFF1E6091)),
                    tooltip: 'Clear Chat',
                    onPressed: _clearChat,
                  ),
                ],
              ),
            ),
          ),
          // Disclaimer container
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 8.0),
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Disclaimer:',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.0,
                      color: Color(0xFF1E6091),
                    ),
                  ),
                  SizedBox(height: 4.0),
                  Text(
                    'This chatbot is for informational purposes only and does not replace professional medical advice, diagnosis, or treatment. Always consult your doctor, midwife, or other qualified health provider with any questions you may have about your pregnancy or a medical condition.',
                    style: GoogleFonts.poppins(
                      fontSize: 12.0,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
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
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.camera_alt_outlined),
                  onPressed: _showImageSourceDialog,
                  color: Color(0xFF1E6091),
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
                        color: Colors.grey[100], // Input field background
                        borderRadius: BorderRadius.circular(25.0),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: _textController,
                        decoration: InputDecoration(
                          hintText: _isListening 
                              ? 'Listening...' 
                              : 'Type your message here...',
                          border: InputBorder.none,
                          hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
                        ),
                        style: GoogleFonts.poppins(),
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
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none_outlined,
                    color: _isListening ? Colors.red : Color(0xFF1E6091),
                  ),
                  onPressed: _startListening,
                ),
                IconButton(
                  icon: const Icon(Icons.send_outlined),
                  onPressed: _handleSendMessage, // Use the new handler
                  color: Color(0xFF1E6091),
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
    final bool showSuggestions = message['showSuggestions'] ?? false;
    final List<ChatAction>? actions = message['actions'] != null 
      ? (message['actions'] as List).map((a) => ChatAction.fromJson(a)).toList() 
      : null;

    if (message['isLoadingPlaceholder'] == true) {
      return const AnimatedLoadingIndicator();
    }

    final String text = message['text'] as String;
    final String time = message['time'] as String;
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
            Text(text, style: GoogleFonts.poppins()),
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
        messageContent = Text(text, style: GoogleFonts.poppins());
      }
    } else {
      // Bot message with potential suggestions and actions
      messageContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarkdownBody(
            data: text,
            selectable: true,
            onTapLink: (text, href, title) async {
              if (href != null) {
                if (await canLaunch(href)) {
                  await launch(href);
                }
              }
            },
            styleSheet: MarkdownStyleSheet(
              p: GoogleFonts.poppins(),
              h1: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              h2: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              h3: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              strong: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              em: GoogleFonts.poppins(fontStyle: FontStyle.italic),
            ),
          ),
          if (showSuggestions) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _initialSuggestions.map((suggestion) => ElevatedButton(
                onPressed: () => _handleSuggestionTap(suggestion),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1E6091),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(
                  suggestion,
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
              )).toList(),
            ),
          ],
          if (actions != null && actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions.map((action) => ElevatedButton.icon(
                onPressed: () => ChatActionHandler.handleAction(context, action),
                icon: Icon(action.icon ?? Icons.arrow_forward, size: 16),
                label: Text(
                  action.label,
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1E6091),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              )).toList(),
            ),
          ],
        ],
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: isUser ? Colors.lightBlue[100] : Color(0xFFEBF2FA),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15.0),
            topRight: const Radius.circular(15.0),
            bottomLeft: isUser ? const Radius.circular(15.0) : const Radius.circular(0),
            bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(15.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            messageContent,
            const SizedBox(height: 4.0),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: GoogleFonts.poppins(fontSize: 10.0, color: Colors.grey),
                ),
                if (isUser) ...[
                  const SizedBox(width: 3.0),
                  const Icon(Icons.done_all, size: 14.0, color: Color(0xFF1E6091))
                ],
                if (!isUser) ...[
                  IconButton(
                    icon: Icon(
                      _isSpeaking && _currentlyPlayingMessageId == messageId
                          ? Icons.pause
                          : Icons.volume_up,
                      size: 18.0,
                      color: Color(0xFF1E6091),
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
          color: Color(0xFFEBF2FA),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(15.0),
            topRight: Radius.circular(15.0),
            bottomLeft: Radius.circular(0),
            bottomRight: Radius.circular(15.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          '[$loadingTextContent]',
          style: GoogleFonts.poppins(
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
} 