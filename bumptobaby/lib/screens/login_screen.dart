import 'package:flutter/material.dart';
import 'signup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bumptobaby/screens/home_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: ListView(
          children: [
            const SizedBox(height: 50),

            // 👶 Centered Icon
            Center(
              child: Image.asset(
                'lib/assets/images/BumpToBaby Logo.png', // Replace with your asset path
                height: 150,
              ),
            ),

            const SizedBox(height: 20),

            // 🌈 Gradient Text
            Center(
              child: Text(
                'Welcome to\nBumpToBaby!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  foreground: Paint()
                    ..shader = LinearGradient(
                      colors: <Color>[Colors.lightBlue, Colors.pinkAccent],
                    ).createShader(Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
                ),
              ),
            ),
            const SizedBox(height: 10),

            Center(
              child: Text(
                'Sign in to your account',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 30),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildTextField('Email', controller: emailController, keyboardType: TextInputType.emailAddress),
                  _buildTextField('Password', controller: passwordController, obscureText: true),
                ],
              ),
            ),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  // TODO: Add password reset logic if needed
                },
                child: Text("Forgot your password?"),
              ),
            ),
            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlue[100],
                elevation: 4,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text("Sign in", style: TextStyle(fontSize: 16)),
            ),

            const SizedBox(height: 20),

            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => SignUpScreen()),
                  );
                },
                child: Text.rich(
                  TextSpan(
                    text: "Don't have an account? ",
                    children: [
                      TextSpan(
                        text: 'Sign Up',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String hint,
      {TextEditingController? controller, bool obscureText = false, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: (value) {
          if (value == null || value.isEmpty) return 'Please enter $hint';
          if (hint == 'Email' && !value.contains('@')) return 'Enter a valid email';
          return null;
        },
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);
    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();
      
      // Check if inputs are valid
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Please enter both email and password');
      }
      
      // Instead of using Firebase Auth directly, query Firestore to find the user
      final QuerySnapshot userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (userQuery.docs.isEmpty) {
        throw Exception('No user found with this email');
      }
      
      // Get user data
      final userData = userQuery.docs.first.data() as Map<String, dynamic>;
      final String username = userData['name'] ?? 'User';
      
      // In a real app, you would verify the password here
      // But for now, we'll just simulate a successful login
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login successful"))
      );
      
      // Navigate to home screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(username: username)),
      );
      
    } catch (e) {
      print("Login error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login failed: ${e.toString().split(":").last.trim()}"))
      );
    } finally {
      setState(() => isLoading = false);
    }
  }
}

