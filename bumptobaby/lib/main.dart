import 'package:bumptobaby/screens/health_help_page.dart';
import 'package:bumptobaby/screens/health_survey_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'firebase_options.dart';
import 'package:bumptobaby/screens/signup_screen.dart';
import 'package:bumptobaby/screens/login_screen.dart';
import 'package:bumptobaby/screens/home_screen.dart';
import 'package:bumptobaby/screens/family_planning_screen.dart';
import 'package:bumptobaby/screens/growth_development_screen.dart';
import 'package:bumptobaby/screens/nutrition_meals_screen.dart';
import 'package:bumptobaby/screens/smart_health_tracker_screen.dart';
import 'package:bumptobaby/screens/nearest_clinic_screen.dart';
import 'package:bumptobaby/screens/community_screen.dart';
import 'package:bumptobaby/screens/audio_visual_learning_screen.dart';
void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    developer.log('Loading environment variables', name: 'App.main');
    await dotenv.load();
    
    developer.log('Initializing Firebase', name: 'App.main');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Verify Firebase initialization
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;
    
    developer.log('Firebase initialized successfully. Auth instance: ${auth.app.name}, Firestore instance: ${firestore.app.name}', name: 'App.main');
    
    // Enable Firestore logging in debug mode
    FirebaseFirestore.instance.settings = Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    
    developer.log('Firestore settings configured', name: 'App.main');
    
    // Log current user state
    if (auth.currentUser != null) {
      developer.log('Current user logged in: ${auth.currentUser!.uid}', name: 'App.main');
      
      // Print the user ID and data path for debugging Firebase rules
      print('====== FIREBASE DEBUG INFO ======');
      print('User ID: ${auth.currentUser!.uid}');
      print('User document path: users/${auth.currentUser!.uid}');
      print('Baby profiles path: users/${auth.currentUser!.uid}/babyProfiles');
      print('Diary entries path example: users/${auth.currentUser!.uid}/babyProfiles/{profileId}/diaryEntries');
      print('================================');
    } else {
      developer.log('No user currently logged in', name: 'App.main');
    }
    
    runApp(MyApp());
  } catch (e, stackTrace) {
    developer.log('Error initializing app: $e', name: 'App.main', error: e, stackTrace: stackTrace);
    // Still attempt to run the app even if there was an error
    runApp(MyApp());
  }
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;
      
      setState(() {
        _isFirstLaunch = isFirstLaunch;
        _isLoading = false;
      });
      
      if (isFirstLaunch) {
        await prefs.setBool('is_first_launch', false);
      }
      
      // Log the launch state
      developer.log('App launch state: ${isFirstLaunch ? "First Launch" : "Returning User"}', name: 'MyApp');
    } catch (e) {
      developer.log('Error checking first launch: $e', name: 'MyApp');
      setState(() {
        _isLoading = false;
      });
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
        '/family_planning': (context) => FamilyPlanningScreen(),
        '/growth_development_screen': (context) => GrowthDevelopmentScreen(),
        '/nutrition_meals': (context) => NutritionMealsScreen(),
        '/smart_health_tracker': (context) => SmartHealthTrackerScreen(),
        '/nearest_clinic': (context) => NearestClinicMapScreen(),
        '/community': (context) => CommunityScreen(),
        '/learning_resources': (context) => AudioVisualLearningScreen(),
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

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0; // Track the selected index for the bottom navigation bar

  // List of pages to navigate to
  final List<Widget> _pages = [
    MyHomePage(title: 'Home'), // Assuming this is your home page
    MySchedulePage(), // Placeholder for My Schedule page
    BabyTrackerPage(), // Placeholder for Baby Tracker page
    const HealthHelpPage(), // Health Help page - Ensure this is the imported one
    CommunityPage(), // Placeholder for Community page
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find Nearest Clinic')),
      body: Center(
        child: _pages[_selectedIndex], // Display the selected page
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'My Schedule',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.child_care),
            label: 'Baby Tracker',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.health_and_safety),
            label: 'Health Help',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Community',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.pink[400],
        unselectedItemColor: Colors.grey[600],
        onTap: _onItemTapped,
      ),
    );
  }
}

// Placeholder for My Schedule Page
class MySchedulePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const HealthSurveyScreen(); // Use our health survey screen here
  }
}

// Placeholder for Baby Tracker Page
class BabyTrackerPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GrowthDevelopmentScreen(); // Use Growth & Development screen for Baby Tracker
  }
}

// Placeholder for Community Page
class CommunityPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Community Page')); // Placeholder content
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20), // Add some spacing
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}


