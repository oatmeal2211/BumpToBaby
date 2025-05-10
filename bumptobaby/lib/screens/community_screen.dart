import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:bumptobaby/services/perspective_api_service.dart';
import 'package:bumptobaby/screens/event_details_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({Key? key}) : super(key: key);

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TextEditingController _postController = TextEditingController();
  bool _isLoading = false;
  String _profileImageUrl = '';
  
  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }
  
  Future<void> _fetchUserProfile() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();
        
        if (userDoc.exists) {
          setState(() {
            _profileImageUrl = userDoc.get('profileImageUrl') ?? '';
          });
        }
      } catch (e) {
        print('Error fetching user profile: $e');
      }
    }
  }
  
  // Sample events data - in a real app, this would come from Firestore
  final List<EventData> _events = [
    EventData(
      title: "World Breastfeeding Week",
      date: DateTime(2023, 8, 1),
      description: "Annual celebration to raise awareness about breastfeeding benefits.",
      imageUrl: "https://images.unsplash.com/photo-1519689680058-324335c77eba?q=80&w=1470&auto=format&fit=crop",
      color: Color(0xFFFFB6C1),
      location: "Community Health Center",
      organizer: "WHO & UNICEF",
      participantsCount: 158,
    ),
    EventData(
      title: "Maternal Mental Health Day",
      date: DateTime(2023, 5, 5),
      description: "Raising awareness about mental health issues affecting mothers.",
      imageUrl: "https://images.unsplash.com/photo-1531983412531-1f49a365ffed?q=80&w=1470&auto=format&fit=crop",
      color: Color(0xFFADD8E6),
      location: "BumpToBaby Medical Center",
      participantsCount: 67,
    ),
    EventData(
      title: "Baby Development Workshop",
      date: DateTime(2023, 9, 15),
      description: "Learn about key milestones in your baby's first year.",
      imageUrl: "https://images.unsplash.com/photo-1566004100631-35d015d6a99b?q=80&w=1470&auto=format&fit=crop",
      color: Color(0xFFFFDAB9),
      participantsCount: 42,
      agenda: [
        "10:00 AM - Baby Cognitive Development",
        "11:30 AM - Motor Skills Workshop",
        "1:00 PM - Nutrition for Infants",
        "2:30 PM - Q&A with Pediatricians"
      ],
    ),
    EventData(
      title: "Pregnancy Nutrition Seminar",
      date: DateTime(2023, 10, 10),
      description: "Expert advice on nutrition during pregnancy.",
      imageUrl: "https://images.unsplash.com/photo-1490818387583-1baba5e638af?q=80&w=1332&auto=format&fit=crop",
      color: Color(0xFFE6E6FA),
      organizer: "BumpToBaby Nutrition Team",
      participantsCount: 93,
    ),
    EventData(
      title: "Women's Health Conference",
      date: DateTime(2023, 11, 20),
      description: "Annual conference focusing on women's health issues.",
      imageUrl: "https://images.unsplash.com/photo-1515377905703-c4788e51af15?q=80&w=1470&auto=format&fit=crop",
      color: Color(0xFFD8BFD8),
      location: "Grand Convention Center",
      organizer: "Women's Health Initiative",
      participantsCount: 211,
    ),
  ];

  // Sample posts data - in a real app, this would come from Firestore
  final List<PostData> _samplePosts = [
    PostData(
      id: "sample1",
      userId: "user1",
      username: "Sarah Johnson",
      content: "Just felt my baby kick for the first time! Such an amazing feeling! ��",
      timestamp: Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 2))),
      likes: [],
      commentCount: 8,
      userProfileImage: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?q=80&w=1470&auto=format&fit=crop",
    ),
    PostData(
      id: "sample2",
      userId: "user2",
      username: "Emily Davis",
      content: "Anyone else experiencing extreme fatigue in their third trimester? Any tips for boosting energy levels naturally?",
      timestamp: Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 5))),
      likes: [],
      commentCount: 12,
      userProfileImage: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?q=80&w=1376&auto=format&fit=crop",
    ),
    PostData(
      id: "sample3",
      userId: "user3",
      username: "Jessica Williams",
      content: "My little one is 6 months today! Time flies so fast. Here's a picture of her first time trying solid food. ��",
      timestamp: Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 8))),
      likes: [],
      commentCount: 16,
      imageUrl: "https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?q=80&w=1520&auto=format&fit=crop",
      userProfileImage: "https://images.unsplash.com/photo-1554151228-14d9def656e4?q=80&w=1372&auto=format&fit=crop",
    ),
    PostData(
      id: "sample4",
      userId: "user4",
      username: "Amanda Brown",
      content: "Just had my 20-week scan and found out we're having a girl! Any recommendations for must-have baby items?",
      timestamp: Timestamp.fromDate(DateTime.now().subtract(Duration(days: 1))),
      likes: [],
      commentCount: 24,
      userProfileImage: "https://images.unsplash.com/photo-1491349174775-aaafddd81942?q=80&w=1374&auto=format&fit=crop",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF9F2F2),
      appBar: AppBar(
        title: Text(
          'Community',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF1E6091),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              // Implement search functionality
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshPosts,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Events section
                    _buildEventsSection(),
                    
                    // Create post section
                    _buildCreatePostSection(),
                    
                    // Posts feed
                    _buildPostsFeed(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFF1E6091),
        child: Icon(Icons.add, color: Colors.white),
        onPressed: () {
          _showCreatePostModal(context);
        },
      ),
    );
  }

  Future<void> _refreshPosts() async {
    setState(() {
      // Trigger a rebuild to fetch new posts
    });
  }

  Widget _buildEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Upcoming Events',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E6091),
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 8),
            itemCount: _events.length,
            itemBuilder: (context, index) {
              return _buildEventCard(_events[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(EventData event) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => EventDetailsScreen(event: event),
          ),
        );
      },
      child: Container(
        width: 280,
        height: 180, // Fixed height to avoid overflow
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: event.color,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            children: [
              // Semi-transparent image as background
              Positioned.fill(
                child: Opacity(
                  opacity: 0.3,
                  child: Image.network(
                    event.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(color: event.color);
                    },
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMM d, yyyy').format(event.date),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      event.title,
                      style: GoogleFonts.poppins(
                        fontSize: 16, // Smaller font size
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        event.description,
                        style: GoogleFonts.poppins(
                          fontSize: 13, // Smaller font size
                          color: Colors.black87,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Tap to learn more indicator
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        'Tap to learn more',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.black87.withOpacity(0.7),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreatePostSection() {
    User? currentUser = _auth.currentUser;
    String? profileImageUrl = currentUser?.photoURL;

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: profileImageUrl != null
                ? NetworkImage(profileImageUrl)
                : AssetImage('lib/assets/images/BumpToBaby Logo.png') as ImageProvider,
          ),
          SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                _showCreatePostModal(context);
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'Share something with the community...',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsFeed() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('posts').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        // Handle errors
        if (snapshot.hasError) {
          return Center(child: Text('Error loading posts.'));
        }

        // Get posts from Firebase if available
        List<PostData> allPosts = [];
        
        // Add Firestore posts if they exist
        if (snapshot.hasData) {
          allPosts = snapshot.data!.docs.map((doc) {
            return PostData.fromFirestore(doc);
          }).toList();
        }
        
        // Add sample posts for testing or when Firestore is empty
        if (allPosts.isEmpty) {
          allPosts = _samplePosts;
        } else {
          // Optionally, you can mix sample and real posts
          // Uncomment this if you want to see both:
          allPosts.addAll(_samplePosts);
          allPosts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        }
        
        // If we have no posts at all
        if (allPosts.isEmpty) {
          return Center(child: Text('No posts yet. Be the first to share!'));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: allPosts.length,
          itemBuilder: (context, index) {
            return _buildPostCard(allPosts[index]);
          },
        );
      },
    );
  }

  Widget _buildPostCard(PostData post) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post header with user info
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: post.userProfileImage.isNotEmpty 
                                     ? NetworkImage(post.userProfileImage)
                                     : AssetImage('lib/assets/images/BumpToBaby Logo.png') as ImageProvider,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.username,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _getTimeAgo(post.timestamp.toDate()),
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_auth.currentUser?.uid == post.userId)
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _deletePost(post.id),
                  ),
              ],
            ),
          ),
          
          // Post content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              post.content,
              style: GoogleFonts.poppins(fontSize: 16),
            ),
          ),
          
          // Post image if available
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Image.network(
                post.imageUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return SizedBox.shrink(); // Hide if image fails to load
                },
              ),
            ),
          
          // Post actions (like, comment, share)
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildActionButton(
                  icon: post.likes.contains(_auth.currentUser?.uid) ? Icons.thumb_up : Icons.thumb_up_outlined,
                  label: '${post.likes.length}',
                  onTap: () => _likePost(post.id),
                  isActive: post.likes.contains(_auth.currentUser?.uid),
                ),
                _buildActionButton(
                  icon: Icons.comment_outlined,
                  label: '${post.commentCount}', // Assuming you add commentCount to PostData
                  onTap: () {
                    _showCommentsSheet(context, post);
                  },
                ),
                _buildActionButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: () {
                    // Share post
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Post deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting post: $e')),
      );
    }
  }
  
  Future<void> _likePost(String postId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    DocumentReference postRef = _firestore.collection('posts').doc(postId);

    _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(postRef);
      if (!snapshot.exists) {
        throw Exception("Post does not exist!");
      }

      List<String> likes = List<String>.from(snapshot.get('likes') ?? []);
      if (likes.contains(currentUser.uid)) {
        likes.remove(currentUser.uid);
      } else {
        likes.add(currentUser.uid);
      }
      transaction.update(postRef, {'likes': likes});
    });
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: isActive ? Color(0xFF1E6091) : Colors.grey[700]),
          SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: isActive ? Color(0xFF1E6091) : Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreatePostModal(BuildContext context) {
    File? _imageFile;
    final ImagePicker _picker = ImagePicker();
    bool _isUploading = false;

    Future<void> _pickImage() async {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        // Need to use a stateful builder or similar to update the modal's state
        // For simplicity, we'll just store it here, but the UI won't update
        // until we implement a more complex state management for the modal.
        _imageFile = File(pickedFile.path); 
        // Ideally, call setState on a StatefulWidget that wraps the modal content.
      }
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) { // Use modalContext to avoid confusion with the main build context
        return StatefulBuilder( // Use StatefulBuilder to manage state within the modal
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Create Post',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () {
                            Navigator.pop(modalContext);
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                     if (_imageFile != null) 
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Image.file(_imageFile!, height: 100, fit: BoxFit.cover),
                      ),
                    Expanded(
                      child: TextField(
                        controller: _postController,
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: 'What\'s on your mind?',
                          border: InputBorder.none,
                          hintStyle: GoogleFonts.poppins(),
                        ),
                      ),
                    ),
                    Divider(),
                    Row(
                      children: [
                        TextButton.icon(
                          icon: Icon(Icons.photo, color: Colors.green),
                          label: Text('Photo', style: GoogleFonts.poppins()),
                          onPressed: () async {
                            final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                            if (pickedFile != null) {
                              setModalState(() {
                                _imageFile = File(pickedFile.path);
                              });
                            }
                          },
                        ),
                        // Video button can be added similarly
                      ],
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF1E6091),
                          padding: EdgeInsets.symmetric(vertical: 12),
                          textStyle: GoogleFonts.poppins(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 3,
                        ),
                        onPressed: _isUploading ? null : () async {
                          if (_postController.text.trim().isNotEmpty || _imageFile != null) {
                            setModalState(() {
                              _isUploading = true;
                            });
                            await _submitPost(_postController.text.trim(), _imageFile);
                            setModalState(() {
                              _isUploading = false;
                            });
                            Navigator.pop(modalContext);
                            _postController.clear();
                             setModalState(() {
                                _imageFile = null;
                              });
                          }
                        },
                        child: _isUploading 
                               ? CircularProgressIndicator(color: Colors.white) 
                               : Text(
                                   'POST',
                                   style: GoogleFonts.poppins(
                                     fontSize: 18,
                                     fontWeight: FontWeight.bold,
                                     color: Colors.white,
                                   ),
                                 ),
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  Future<void> _submitPost(String content, File? imageFile) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You must be logged in to post.')),
      );
      return;
    }

    // Check content with Perspective API
    if (content.isNotEmpty) {
      bool approved = await PerspectiveApiService.confirmPostContent(context, content);
      if (!approved) {
        return; // User chose to edit the content
      }
    }

    setState(() {
      _isLoading = true; // For the main page loader, if needed
    });

    try {
      String? imageUrl;
      if (imageFile != null) {
        String fileName = 'post_images/${currentUser.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        Reference storageRef = _storage.ref().child(fileName);
        UploadTask uploadTask = storageRef.putFile(imageFile);
        TaskSnapshot snapshot = await uploadTask;
        imageUrl = await snapshot.ref.getDownloadURL();
      }

      DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      String username = userDoc.get('name') ?? 'Anonymous User';
      String userProfileImage = userDoc.get('profileImageUrl') ?? '';


      await _firestore.collection('posts').add({
        'userId': currentUser.uid,
        'username': username,
        'userProfileImage': userProfileImage,
        'content': content,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
        'commentCount': 0, 
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Post created successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating post: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showCommentsSheet(BuildContext context, PostData post) {
    final TextEditingController commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Comments',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () {
                        Navigator.pop(modalContext);
                      },
                    ),
                  ],
                ),
                Divider(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('posts')
                        .doc(post.id)
                        .collection('comments')
                        .orderBy('timestamp', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error loading comments.'));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(child: Text('No comments yet.'));
                      }

                      final comments = snapshot.data!.docs.map((doc) {
                        return CommentData.fromFirestore(doc);
                      }).toList();

                      return ListView.builder(
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                   backgroundImage: comment.userProfileImage.isNotEmpty 
                                     ? NetworkImage(comment.userProfileImage)
                                     : AssetImage('lib/assets/images/BumpToBaby Logo.png') as ImageProvider,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            comment.username,
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            _getTimeAgo(comment.timestamp.toDate()),
                                            style: GoogleFonts.poppins(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        comment.content,
                                        style: GoogleFonts.poppins(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                 if (_auth.currentUser?.uid == comment.userId)
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    onPressed: () => _deleteComment(post.id, comment.id),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                       CircleAvatar(
                        radius: 16,
                        backgroundImage: _auth.currentUser?.photoURL != null && _auth.currentUser!.photoURL!.isNotEmpty
                            ? NetworkImage(_auth.currentUser!.photoURL!)
                            : _profileImageUrl.isNotEmpty
                                ? NetworkImage(_profileImageUrl)
                                : AssetImage('lib/assets/images/BumpToBaby Logo.png') as ImageProvider,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: commentController,
                          decoration: InputDecoration(
                            hintText: 'Write a comment...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[200],
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.send, color: Color(0xFF1E6091)),
                        onPressed: () async {
                          if (commentController.text.trim().isNotEmpty) {
                            await _submitComment(post.id, commentController.text.trim());
                            commentController.clear();
                            // Optionally close modal or just let user add more
                            // Navigator.pop(modalContext); 
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitComment(String postId, String commentContent) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Check comment content with Perspective API
    bool approved = await PerspectiveApiService.confirmPostContent(context, commentContent);
    if (!approved) {
      return; // User chose to edit the content
    }

    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      String username = userDoc.get('name') ?? 'Anonymous User';
      String userProfileImage = userDoc.get('profileImageUrl') ?? '';

      await _firestore.collection('posts').doc(postId).collection('comments').add({
        'userId': currentUser.uid,
        'username': username,
        'userProfileImage': userProfileImage,
        'content': commentContent,
        'timestamp': FieldValue.serverTimestamp(),
      });
      // Increment comment count on the post
      await _firestore.collection('posts').doc(postId).update({'commentCount': FieldValue.increment(1)});
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comment added!')),
      );
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding comment: $e')),
      );
    }
  }

  Future<void> _deleteComment(String postId, String commentId) async {
    try {
      await _firestore.collection('posts').doc(postId).collection('comments').doc(commentId).delete();
      await _firestore.collection('posts').doc(postId).update({'commentCount': FieldValue.increment(-1)});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comment deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting comment: $e')),
      );
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return DateFormat('MMM d, yyyy').format(dateTime); // Show full date for older posts
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class PostData {
  final String id;
  final String userId;
  final String username;
  final String content;
  final Timestamp timestamp;
  final List<String> likes;
  final int commentCount;
  final String? imageUrl;
  final String userProfileImage;

  PostData({
    required this.id,
    required this.userId,
    required this.username,
    required this.content,
    required this.timestamp,
    required this.likes,
    required this.commentCount,
    this.imageUrl,
    required this.userProfileImage,
  });

  factory PostData.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return PostData(
      id: doc.id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? 'Anonymous',
      content: data['content'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      likes: List<String>.from(data['likes'] ?? []),
      commentCount: data['commentCount'] ?? 0,
      imageUrl: data['imageUrl'],
      userProfileImage: data['userProfileImage'] ?? '',
    );
  }
}

class CommentData {
  final String id;
  final String userId;
  final String username;
  final String content;
  final Timestamp timestamp;
  final String userProfileImage;

  CommentData({
    required this.id,
    required this.userId,
    required this.username,
    required this.content,
    required this.timestamp,
    required this.userProfileImage,
  });

  factory CommentData.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CommentData(
      id: doc.id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? 'Anonymous',
      content: data['content'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      userProfileImage: data['userProfileImage'] ?? '',
    );
  }
} 