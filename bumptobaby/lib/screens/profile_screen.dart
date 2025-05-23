import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:bumptobaby/screens/health_survey_screen.dart';
import 'package:bumptobaby/screens/login_screen.dart';
import 'package:bumptobaby/screens/community_screen.dart'; // For PostData model
import 'package:intl/intl.dart'; // For date formatting
import 'package:bumptobaby/screens/health_help_page.dart'; // Added for HealthHelpPage

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  TextEditingController _nameController = TextEditingController();
  TextEditingController _emailController = TextEditingController();
  TextEditingController _phoneController = TextEditingController();

  String _profileImageUrl = '';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingImage = false;

  TabController? _tabController;
  List<PostData> _userPosts = [];
  List<CommentData> _userComments = []; // You might need a way to link comments to their original posts

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // 2 tabs: Posts, Comments
    _loadUserData();
    _loadUserActivity();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Set email from auth
        _emailController.text = currentUser.email ?? '';

        // Get additional user data from Firestore
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          
          setState(() {
            _nameController.text = userData['name'] ?? '';
            _phoneController.text = userData['phoneNumber'] ?? '';
            _profileImageUrl = userData['profileImageUrl'] ?? '';
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading user data: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserActivity() async {
    setState(() {
      _isLoading = true;
    });

    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // Load user posts - handle case where index isn't ready
      try {
        QuerySnapshot postsSnapshot = await _firestore
            .collection('posts')
            .where('userId', isEqualTo: currentUser.uid)
            .orderBy('timestamp', descending: true)
            .get();
          
        _userPosts = postsSnapshot.docs.map((doc) => PostData.fromFirestore(doc)).toList();
        
        print("DEBUG: Found ${_userPosts.length} posts for user");
      } catch (e) {
        if (e.toString().contains('requires an index')) {
          // Fall back to a simpler query without sorting if index isn't ready
          print("DEBUG: Index not ready, using fallback query");
          QuerySnapshot postsSnapshot = await _firestore
              .collection('posts')
              .where('userId', isEqualTo: currentUser.uid)
              .get();
              
          _userPosts = postsSnapshot.docs.map((doc) => PostData.fromFirestore(doc)).toList();
          
          // Sort manually client-side
          _userPosts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        } else {
          print("DEBUG: Error loading posts: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading posts: ${e.toString().split("]").last}')),
          );
        }
      }

      // Load user comments using a simplified approach
      // This approach is more resilient but may have performance issues with large datasets
      List<CommentData> allComments = [];
      
      try {
        // Get all posts - we'll filter for user comments client-side
        QuerySnapshot allPostsSnapshot = await _firestore.collection('posts').get();
        
        for (var postDoc in allPostsSnapshot.docs) {
          QuerySnapshot commentsSnapshot = await _firestore
              .collection('posts')
              .doc(postDoc.id)
              .collection('comments')
              .where('userId', isEqualTo: currentUser.uid)
              .get();
              
          if (commentsSnapshot.docs.isNotEmpty) {
            allComments.addAll(commentsSnapshot.docs.map((doc) {
              CommentData comment = CommentData.fromFirestore(doc);
              return comment;
            }).toList());
          }
        }
        
        // Sort comments by timestamp manually
        allComments.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _userComments = allComments;
        
        print("DEBUG: Found ${_userComments.length} comments");
      } catch (e) {
        print("DEBUG: Error loading comments: $e");
      }
    } catch (e) {
      print("DEBUG: Error loading user activity: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading activity: ${e.toString().split("]").last}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateUserData() async {
    setState(() {
      _isSaving = true;
    });

    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _firestore.collection('users').doc(currentUser.uid).update({
          'name': _nameController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
        });

        // Update email if changed and not empty
        if (_emailController.text.trim() != currentUser.email &&
            _emailController.text.trim().isNotEmpty) {
          await currentUser.updateEmail(_emailController.text.trim());
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _uploadProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _isUploadingImage = true;
      });

      try {
        User? currentUser = _auth.currentUser;
        if (currentUser != null) {
          File imageFile = File(pickedFile.path);
          
          // Create a reference to the storage location
          Reference storageRef = _storage.ref().child('profile_images/${currentUser.uid}');
          
          // Upload the file to Firebase Storage
          TaskSnapshot uploadTask = await storageRef.putFile(imageFile);
          
          // Get the download URL
          String downloadUrl = await uploadTask.ref.getDownloadURL();
          
          // Update the user document with the profile image URL
          await _firestore.collection('users').doc(currentUser.uid).update({
            'profileImageUrl': downloadUrl,
          });
          
          setState(() {
            _profileImageUrl = downloadUrl;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Profile image updated')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      } finally {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white
          ),
        ),
        backgroundColor: Color(0xFF1E6091),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildProfileHeader(),
                TabBar(
                  controller: _tabController,
                  labelColor: Color(0xFF1E6091),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Color(0xFF1E6091),
                  tabs: [
                    Tab(text: 'My Posts'),
                    Tab(text: 'My Comments'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUserPostsList(),
                      _buildUserCommentsList(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      color: Color(0xFF1E6091), // Match AppBar color
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: 10),
          GestureDetector(
            onTap: _uploadProfileImage,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Hero(
                  tag: 'profileAvatar',
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Color(0xFF1E6091).withOpacity(0.2),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 50, // Larger radius for profile screen
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 48,
                        backgroundImage: _profileImageUrl.isNotEmpty
                            ? NetworkImage(_profileImageUrl)
                            : AssetImage('lib/assets/images/BumpToBaby Logo.png') as ImageProvider,
                      ),
                    ),
                  ),
                ),
                if (_isUploadingImage)
                  CircularProgressIndicator()
                else
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white, // Changed for better visibility against dark bg
                      shape: BoxShape.circle,
                      border: Border.all(color: Color(0xFF1E6091), width: 2)
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: Color(0xFF1E6091),
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 10),
          Text(
            _nameController.text, 
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4),
          Text(
            _emailController.text,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
               ElevatedButton.icon(
                icon: Icon(Icons.edit, size: 16),
                label: Text('Edit Profile'),
                onPressed: _showEditProfileModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Color(0xFF1E6091),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
              ElevatedButton.icon(
                icon: Icon(Icons.assignment_turned_in, size: 16),
                label: Text('Health Survey'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => HealthSurveyScreen()),
                  );
                },
                 style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Color(0xFF1E6091),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ]
          ),
           SizedBox(height: 16),
           ElevatedButton.icon(
              icon: Icon(Icons.logout, size: 16, color: Colors.white),
              label: Text('Sign Out', style: TextStyle(color: Colors.white)),
              onPressed: _signOut,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              ),
            ),
          SizedBox(height: 10),
        ],
      ),
    );
  }

  void _showEditProfileModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16, right: 16, top: 20
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Edit Profile', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 20),
              _buildTextField(label: 'Name', controller: _nameController, icon: Icons.person),
              SizedBox(height: 16),
              _buildTextField(label: 'Email', controller: _emailController, icon: Icons.email, keyboardType: TextInputType.emailAddress),
              SizedBox(height: 16),
              _buildTextField(label: 'Phone Number', controller: _phoneController, icon: Icons.phone, keyboardType: TextInputType.phone),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isSaving ? null : () async {
                  await _updateUserData();
                  Navigator.pop(context); // Close modal after saving
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 14),
                  backgroundColor: Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                ),
                child: _isSaving ? CircularProgressIndicator(color: Colors.white) : Text(
                  'Save Changes',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      }
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Color(0xFF1E6091)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Color(0xFF1E6091)),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildUserPostsList() {
    if (_userPosts.isEmpty) {
      return Center(child: Text('You have not made any posts yet.', style: GoogleFonts.poppins()));
    }
    return ListView.builder(
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        final post = _userPosts[index];
        // Using a simplified card for user's own posts list
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: post.imageUrl != null && post.imageUrl!.isNotEmpty 
                ? Image.network(post.imageUrl!, width: 50, height: 50, fit: BoxFit.cover)
                : Icon(Icons.article, size: 40, color: Color(0xFF1E6091)),
            title: Text(post.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            subtitle: Text('${DateFormat.yMMMd().add_jm().format(post.timestamp.toDate())} - ${post.likes.length} Likes, ${post.commentCount} Comments', style: GoogleFonts.poppins(fontSize: 12)),
            onTap: () {
              // Optional: Navigate to the full post view if you implement one
            },
          ),
        );
      },
    );
  }

  Widget _buildUserCommentsList() {
    if (_userComments.isEmpty) {
      return Center(child: Text('You have not made any comments yet.', style: GoogleFonts.poppins()));
    }
    return ListView.builder(
      itemCount: _userComments.length,
      itemBuilder: (context, index) {
        final comment = _userComments[index];
        // Displaying comment content and timestamp
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: Icon(Icons.comment, size: 40, color: Color(0xFFF8AFAF)),
            title: Text(comment.content, maxLines: 3, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins()),
            subtitle: Text('Commented on ${DateFormat.yMMMd().add_jm().format(comment.timestamp.toDate())}', style: GoogleFonts.poppins(fontSize: 12)),
            // You might want to add functionality to tap and see the original post
            onTap: () {
              // Optional: Navigate to the post containing this comment
            },
          ),
        );
      },
    );
  }

  Future<void> _signOut() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Clear chat history before signing out
      await HealthHelpPage.clearChatHistory();
      
      await _auth.signOut();
      
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }
} 