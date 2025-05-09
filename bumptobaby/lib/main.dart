import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'package:bumptobaby/screens/signup_screen.dart';
import 'package:bumptobaby/screens/login_screen.dart';
import 'package:bumptobaby/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isFirstLaunch = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;
    
    setState(() {
      _isFirstLaunch = isFirstLaunch;
      _isLoading = false;
    });
    
    if (isFirstLaunch) {
      await prefs.setBool('is_first_launch', false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BumpToBaby',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Color(0xFFF5F5F5),
      ),
      home: _isLoading
          ? _buildLoadingScreen()
          : _isFirstLaunch
              ? SignUpScreen()
              : LoginScreen(),
      routes: {
        '/login': (context) => LoginScreen(),
        '/signup': (context) => SignUpScreen(),
        '/home': (context) => HomeScreen(username: 'User'),
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'lib/assets/images/BumpToBaby Logo.png',
              height: 150,
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

// AuthService to handle user state management
class AuthService {
  static String? username;
  
  static void setUsername(String name) {
    username = name;
  }
  
  static String getUserName() {
    return username ?? 'User';
  }
}