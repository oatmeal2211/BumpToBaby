import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bumptobaby/screens/home_screen.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: ListView(
          children: [
            const SizedBox(height: 60),
            Center(
              child: Text(
                'Create Account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.lightBlue),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Just a few steps away from your\nall-in-one tracker',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 30),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildTextField('Name', controller: nameController),
                  _buildTextField('Email', controller: emailController, keyboardType: TextInputType.emailAddress),
                  _buildTextField('Phone Number', controller: phoneController, keyboardType: TextInputType.phone),
                  _buildTextField('Password', controller: passwordController, obscureText: true),
                  _buildTextField('Re-enter password', controller: confirmPasswordController, obscureText: true),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                text: 'By signing up, you agree to our ',
                children: [
                  TextSpan(
                    text: 'Terms & Privacy Policy',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : _handleSignUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlue[100],
                elevation: 4,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text("Sign Up", style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (_) => LoginScreen()));
                },
                child: Text.rich(
                  TextSpan(
                    text: 'Already have an account? ',
                    children: [
                      TextSpan(
                        text: 'Sign In',
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

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Passwords don't match")));
      return;
    }

    setState(() => isLoading = true);
    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final String name = nameController.text.trim();
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'name': name,
            'phoneNumber': phoneController.text.trim(),
            'email': emailController.text.trim(),
          });
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Account created successfully")));
      
      // Navigate directly to home screen
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (_) => HomeScreen(username: name))
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Sign up failed')));
    } finally {
      setState(() => isLoading = false);
    }
  }
}
