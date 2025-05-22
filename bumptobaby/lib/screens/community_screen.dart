import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:bumptobaby/services/content_moderation_service.dart';
import 'package:bumptobaby/screens/event_details_screen.dart';
import 'package:bumptobaby/models/medical_info.dart';

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
          
          // Print debug info about the user
          print('DEBUG: User profile fetched:');
          print('DEBUG: User ID: ${currentUser.uid}');
          print('DEBUG: Display name from Firebase Auth: ${currentUser.displayName}');
          if (userDoc.data() != null) {
            final userData = userDoc.data() as Map<String, dynamic>;
            print('DEBUG: User data from Firestore:');
            userData.forEach((key, value) {
              print('DEBUG: $key: $value');
            });
          }
        } else {
          print('DEBUG: User document does not exist in Firestore');
        }
      } catch (e) {
        print('Error fetching user profile: $e');
      }
    } else {
      print('DEBUG: No current user');
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
      isMedicalMisinformation: false,
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
      isMedicalMisinformation: false,
    ),
    PostData(
      id: "sample3",
      userId: "user3",
      username: "Jessica Williams",
      content: "My little one is 6 months today! Time flies so fast. Here's a picture of her first time trying solid food. ",
      timestamp: Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 8))),
      likes: [],
      commentCount: 16,
      imageUrl: "https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?q=80&w=1520&auto=format&fit=crop",
      userProfileImage: "https://images.unsplash.com/photo-1554151228-14d9def656e4?q=80&w=1372&auto=format&fit=crop",
      isMedicalMisinformation: false,
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
      isMedicalMisinformation: false,
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
    return GestureDetector(
      onTap: () => _showCreatePostModal(context),
      child: Card(
        margin: EdgeInsets.all(16),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: _profileImageUrl.isNotEmpty
                    ? NetworkImage(_profileImageUrl) as ImageProvider
                    : AssetImage('lib/assets/images/BumpToBaby Logo.png'),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Share something with the community...',
                  style: GoogleFonts.poppins(
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostsFeed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Community Feed',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E6091),
            ),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('posts')
              .orderBy('timestamp', descending: true)
              .limit(20)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Something went wrong'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              // Show sample posts while we wait for real data
              return Column(
                children: _samplePosts.map((post) => _buildPostCard(post)).toList(),
              );
            }

            final posts = snapshot.data!.docs.map((doc) {
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              
              // Check for both field names to handle possible inconsistencies
              bool isMisinformation = false;
              
              // Check all possible field name variations
              if (data.containsKey('isMedicalMisinformation')) {
                isMisinformation = data['isMedicalMisinformation'] == true;
              } else if (data.containsKey('isMisinformation')) {
                isMisinformation = data['isMisinformation'] == true;
              }
              
              return PostData(
                id: doc.id,
                userId: data['userId'] ?? '',
                username: data['username'] ?? 'Anonymous',
                content: data['content'] ?? '',
                timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
                likes: List<String>.from(data['likes'] ?? []),
                commentCount: data['commentCount'] ?? 0,
                imageUrl: data['imageUrl'],
                userProfileImage: data['userProfileImage'] ?? '',
                isMedicalMisinformation: isMisinformation,
                factCheckId: data['factCheckId'],
              );
            }).toList();
            
            return Column(
              children: posts.map((post) => _buildPostCard(post)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPostCard(PostData post) {
    // Determine if the current user has liked this post
    bool isLiked = post.likes.contains(_auth.currentUser?.uid ?? '');
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post header with user info
          ListTile(
            leading: CircleAvatar(
              radius: 20,
              backgroundImage: post.userProfileImage.isNotEmpty
                  ? NetworkImage(post.userProfileImage) as ImageProvider
                  : AssetImage('lib/assets/images/BumpToBaby Logo.png'),
            ),
            title: Text(
              post.username,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              _formatTimestamp(post.timestamp),
              style: TextStyle(fontSize: 12),
            ),
            trailing: post.userId == _auth.currentUser?.uid
                ? PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert),
                    onSelected: (value) async {
                      if (value == 'edit') {
                        _editPost(post);
                      } else if (value == 'delete') {
                        await _deletePost(post);
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit', style: GoogleFonts.poppins()),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  )
                : IconButton(
                    icon: Icon(Icons.more_vert),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Report Post', style: GoogleFonts.poppins()),
                          content: Text('Do you want to report this post?', style: GoogleFonts.poppins()),
                          actions: [
                            TextButton(
                              child: Text('Cancel', style: GoogleFonts.poppins()),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            TextButton(
                              child: Text('Report', style: GoogleFonts.poppins(color: Colors.red)),
                              onPressed: () {
                                // Implement report functionality
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Post reported')),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          // Post content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              post.content,
              style: GoogleFonts.poppins(
                fontSize: 15,
              ),
            ),
          ),
          
          // Display misinformation warning if needed
          if (post.isMedicalMisinformation) _buildMisinformationWarning(post),
          
          // Post image if available
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
            Container(
              width: double.infinity,
              height: 200,
              margin: EdgeInsets.only(top: 8),
              child: Image.network(
                post.imageUrl!,
                fit: BoxFit.cover,
              ),
            ),
          
          // Post actions (like, comment)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Like button
                _buildActionButton(
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  label: "${post.likes.length} Likes",
                  color: isLiked ? Colors.red : Colors.grey,
                  onTap: () => _toggleLike(post),
                ),
                // Comment button
                _buildActionButton(
                  icon: Icons.comment_outlined,
                  label: "${post.commentCount} Comments",
                  onTap: () {
                    _showCommentsSheet(context, post);
                  },
                ),
                // Share button
                _buildActionButton(
                  icon: Icons.share_outlined,
                  label: "Share",
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
  
  // Build misinformation warning widget for posts
  Widget _buildMisinformationWarning(PostData post) {
    return Container(
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700),
              SizedBox(width: 8),
              Text(
                'Medical claim may be inaccurate',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            post.factCheckId != null 
                ? 'This post contains information that may contradict medical guidelines. Please consult healthcare professionals.'
                : 'This post contains information that may contradict medical guidelines. Please consult healthcare professionals.',
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          
          // If we have a factCheck ID, try to load the detailed information
          if (post.factCheckId != null)
            FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('fact_checks').doc(post.factCheckId).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done && !snapshot.hasError && snapshot.data != null) {
                  final factCheckData = snapshot.data!.data() as Map<String, dynamic>?;
                  if (factCheckData != null) {
                    final explanation = factCheckData['explanation'] ?? 
                        'This post contains medical information that conflicts with established medical consensus.';
                    final simplifiedExplanation = factCheckData['simplifiedExplanation'] ??
                        'This claim contradicts current medical guidelines. Please consult your healthcare provider.';
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 8),
                        Text(
                          simplifiedExplanation,
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              // Show more details
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Medical Fact Check', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                  content: SingleChildScrollView(
                                    child: Text(explanation, style: GoogleFonts.poppins()),
                                  ),
                                  actions: [
                                    TextButton(
                                      child: Text('Close', style: GoogleFonts.poppins()),
                                      onPressed: () => Navigator.of(context).pop(),
                                    ),
                                  ],
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: Colors.amber.shade300),
                              ),
                            ),
                            child: Text(
                              'Learn more',
                              style: GoogleFonts.poppins(
                                color: Colors.amber.shade900,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                }
                return SizedBox.shrink(); // Return empty widget if no fact check data is available yet
              },
            ),
        ],
      ),
    );
  }

  void _showCreatePostModal(BuildContext context, {int initialTab = 0}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Create Post',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      controller: _postController,
                      decoration: InputDecoration(
                        hintText: 'Share your thoughts...',
                        border: InputBorder.none,
                      ),
                      maxLines: 5,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Add media button
                        IconButton(
                          icon: Icon(Icons.image, color: Colors.green),
                          onPressed: () {
                            // Implement photo picker
                            _pickImage();
                          },
                        ),
                        // Spacer
                        Spacer(),
                        // Post button
                        if (_isLoading)
                          CircularProgressIndicator()
                        else
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF1E6091),
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            onPressed: () => _createPost(),
                            child: Text(
                              'Post',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _createPost() async {
    if (_postController.text.trim().isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Get user data
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      String username = user.displayName ?? 'Anonymous';
      String profileImageUrl = '';
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        username = userData['displayName'] ?? userData['name'] ?? userData['username'] ?? username;
        profileImageUrl = userData['profileImageUrl'] ?? userData['photoURL'] ?? userData['photoUrl'] ?? '';
      }

      // Prepare basic post data
      final String content = _postController.text;
      final Map<String, dynamic> postData = {
        'userId': user.uid,
        'username': username,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
        'commentCount': 0, 
        'userProfileImage': profileImageUrl,
        'isMedicalMisinformation': false,
        'isMisinformation': false,
      };
      
      // Check for misinformation
      String? factCheckId;
      bool shouldFlagMisinformation = false;
      
      // Test misinformation check
      bool forceMisinformation = content.toLowerCase().contains('test misinformation');
      
      if (forceMisinformation) {
        shouldFlagMisinformation = true;
        
        try {
          Map<String, dynamic> factCheckData = {
            'explanation': 'This is a test fact check for demonstrating the misinformation warning UI.',
            'simplifiedExplanation': 'This post was marked as containing misinformation for testing purposes.',
            'confidence': 0.95,
            'relatedSources': [],
            'isMisinformation': true,
            'timestamp': FieldValue.serverTimestamp(),
          };
          
          DocumentReference factCheckRef = await _firestore.collection('fact_checks').add(factCheckData);
          factCheckId = factCheckRef.id;
        } catch (e) {
          // Continue without factCheck but still flag as misinformation
        }
      } 
      // Regular misinformation check
      else {
        bool isMedicalContent = _isMedicalContent(content);
        
        if (isMedicalContent) {
          // First try our reliable offline check
          bool offlineMisinformationDetected = _checkForCommonMisinformation(content);
          
          if (offlineMisinformationDetected) {
            shouldFlagMisinformation = true;
            
            try {
              // Create a simple fact check
              Map<String, dynamic> factCheckData = {
                'explanation': 'This content contains common medical misinformation that contradicts established medical guidelines.',
                'simplifiedExplanation': 'This claim appears to contradict medical consensus. Please consult your healthcare provider.',
                'confidence': 0.9,
                'relatedSources': [],
                'isMisinformation': true,
                'timestamp': FieldValue.serverTimestamp(),
              };
              
              DocumentReference factCheckRef = await _firestore.collection('fact_checks').add(factCheckData);
              factCheckId = factCheckRef.id;
            } catch (e) {
              // Continue without factCheck
            }
          }
          // Only try the API if offline check didn't find anything
          else {
            try {
              final moderationService = ContentModerationService();
              
              // Skip processContent which shows dialogs - we just want to check without UI
              final moderationResult = await moderationService.checkContent(content);
              
              if (moderationResult.isMedicalMisinformation) {
                shouldFlagMisinformation = true;
                
                try {
                  // Store factCheck in Firestore if we have one
                  if (moderationResult.factCheck != null) {
                    Map<String, dynamic> factCheckJson = moderationResult.factCheck!.toJson();
                    DocumentReference factCheckRef = await _firestore.collection('fact_checks').add(factCheckJson);
                    factCheckId = factCheckRef.id;
                  }
                } catch (e) {
                  // Continue without factCheck
                }
              }
            } catch (apiError) {
              // Continue without API check
            }
          }
        }
      }

      // Update post data with misinformation flag if needed
      if (shouldFlagMisinformation || forceMisinformation) {
        postData['isMedicalMisinformation'] = true;
        postData['isMisinformation'] = true;
        
        // Add factCheckId if available
        if (factCheckId != null) {
          postData['factCheckId'] = factCheckId;
        }
      }
      
      // Create post in Firestore
      try {
        await _firestore.collection('posts').add(postData);
        
        // Clear the text field and close the modal
        _postController.clear();
        Navigator.pop(context);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Post created successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      } catch (firebaseError) {
        if (firebaseError.toString().contains('permission-denied')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Permission denied. Check Firebase security rules.'),
              duration: Duration(seconds: 4),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving post: $firebaseError'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating post. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Clean up the checkForCommonMisinformation function
  bool _checkForCommonMisinformation(String content) {
    // Convert to lowercase for case-insensitive matching
    final lowerContent = content.toLowerCase();
    
    // List of common misinformation patterns - expanded for better detection
    final misinformationPatterns = [
      // Vaccine misinformation
      'vaccines cause autism',
      'vaccine causes autism',
      'autism from vaccine',
      'vaccines are dangerous',
      'vaccine dangerous',
      'vaccine injury',
      'vaccines not safe',
      'vaccines not necessary',
      'skip vaccination',
      'avoid vaccine',
      
      // Pregnancy myths
      'baby gender prediction',
      'predict baby gender',
      'determine gender by',
      'morning sickness means',
      'heartburn means baby',
      'coffee during pregnancy',
      'alcohol safe during pregnancy',
      'alcohol pregnancy',
      'smoking pregnancy',
      'smoking during pregnancy is fine',
      'eating for two',
      
      // Unsafe sleep practices
      'co-sleeping is safe',
      'cosleeping safe',
      'baby can sleep on stomach',
      'baby needs pillows',
      'babies sleep better on their stomachs',
      'stomach sleeping',
      
      // General misinformation
      'breastfeeding unnecessary',
      'formula is better than breast milk',
      'breast milk has no benefits',
      'natural remedies instead of',
      'don\'t trust doctors',
      'medicine is harmful',
      'alternative medicine',
      'no medical intervention',
      'home birth safer',
      
      // Specific dangerous misinformation
      'amber necklace',
      'teething necklace',
      'no fever medicine',
      'avoid antibiotics',
      'chiropractor for baby',
      'treats colic',
      'vaccine shedding',
    ];
    
    // Enhanced matching - check for partial matches with word boundaries
    for (final pattern in misinformationPatterns) {
      if (lowerContent.contains(pattern)) {
        return true;
      }
    }
    
    // Check for generic vaccine skepticism
    if (lowerContent.contains('vaccine') && 
        (lowerContent.contains('dangerous') || 
         lowerContent.contains('harm') || 
         lowerContent.contains('avoid') || 
         lowerContent.contains('risk') || 
         lowerContent.contains('safe'))) {
      return true;
    }
    
    return false;
  }

  // Clean up medical content detection function
  bool _isMedicalContent(String content) {
    // List of medical keywords to check
    final List<String> medicalKeywords = [
      'pregnancy', 'pregnant', 'birth', 'labor', 'delivery', 'ultrasound', 'trimester',
      'medication', 'medicine', 'drug', 'supplement', 'vitamin', 'prenatal', 'postnatal',
      'epidural', 'c-section', 'cesarean', 'contractions', 'midwife', 'doctor', 'obgyn',
      'gynecologist', 'hospital', 'clinic', 'procedure', 'symptom', 'pain', 'bleeding',
      'vaccine', 'vaccination', 'immunization', 'health', 'medical', 'diagnosis', 'treatment',
      'breastfeeding', 'formula', 'womb', 'uterus', 'placenta', 'embryo', 'fetus', 'baby',
      'developmental', 'milestone', 'condition', 'syndrome', 'disorder', 'disease', 'infection'
    ];
    
    // Convert content to lowercase for case-insensitive matching
    final lowerContent = content.toLowerCase();
    
    // Check if any medical keyword is in the content
    for (String keyword in medicalKeywords) {
      if (lowerContent.contains(keyword)) {
        return true;
      }
    }
    
    return false;
  }

  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return DateFormat('MMM d, yyyy').format(dateTime);
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon, 
            size: 20, 
            color: color ?? (isActive ? Color(0xFF1E6091) : Colors.grey[700]),
          ),
          SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: isActive ? Color(0xFF1E6091) : Colors.grey[700],
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  void _toggleLike(PostData post) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You need to be logged in to like posts')),
        );
        return;
      }
      
      // Check if user already liked the post
      final bool isAlreadyLiked = post.likes.contains(user.uid);
      
      print('DEBUG: Toggling like for post ${post.id}');
      print('DEBUG: Current user: ${user.uid}');
      print('DEBUG: Post likes before: ${post.likes}');
      print('DEBUG: isAlreadyLiked: $isAlreadyLiked');
      
      // Reference to the post document
      final postRef = _firestore.collection('posts').doc(post.id);
      
      // Use transactions to safely update the likes array
      await _firestore.runTransaction((transaction) async {
        // Get the current document
        DocumentSnapshot postSnapshot = await transaction.get(postRef);
        
        if (!postSnapshot.exists) {
          throw Exception('Post does not exist');
        }
        
        // Get the current likes array
        List<dynamic> likes = (postSnapshot.data() as Map<String, dynamic>)['likes'] ?? [];
        
        // Update the likes array
        if (isAlreadyLiked) {
          likes.remove(user.uid);
        } else {
          likes.add(user.uid);
        }
        
        // Update the document with the new likes array
        transaction.update(postRef, {'likes': likes});
        
        return likes;
      });
      
      // Show a snackbar confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAlreadyLiked ? 'Like removed' : 'Post liked'),
          duration: Duration(seconds: 1),
        ),
      );
      
      // Force a refresh of the UI by calling setState
      setState(() {});
      
    } catch (e) {
      print('Error toggling like: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating like: $e'),
          backgroundColor: Colors.red,
        ),
      );
      
      // Special message for permission errors
      if (e.toString().contains('permission-denied')) {
        _showFirebaseSecurityRulesDialog(context);
      }
    }
  }

  // Add this function to edit posts
  void _editPost(PostData post) {
    final TextEditingController editController = TextEditingController(text: post.content);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Post', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: editController,
          decoration: InputDecoration(
            hintText: 'Edit your post...',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            child: Text('Cancel', style: GoogleFonts.poppins()),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text('Save', style: GoogleFonts.poppins(color: Color(0xFF1E6091))),
            onPressed: () async {
              if (editController.text.trim().isNotEmpty) {
                await _updatePost(post, editController.text.trim());
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  // Add this function to update a post in Firestore
  Future<void> _updatePost(PostData post, String newContent) async {
    try {
      await _firestore.collection('posts').doc(post.id).update({
        'content': newContent,
        'editedAt': FieldValue.serverTimestamp(),
      });
      
      print('DEBUG: Updated post ${post.id}');
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Post updated')),
      );
    } catch (e) {
      print('Error updating post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating post: $e')),
      );
    }
  }

  // Fix the delete post method to handle permission errors
  Future<void> _deletePost(PostData post) async {
    try {
      // First confirm deletion
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete Post', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to delete this post?', style: GoogleFonts.poppins()),
              SizedBox(height: 8),
              Text(
                'Note: If you get a permission error, you need to update your Firebase security rules.',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.red, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Cancel', style: GoogleFonts.poppins()),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );
      
      if (confirmed != true) return;
      
      print('DEBUG: Attempting to delete post ${post.id}');
      print('DEBUG: Current user ID: ${_auth.currentUser?.uid}');
      print('DEBUG: Post user ID: ${post.userId}');
      
      // Check if the user is the post owner
      if (post.userId != _auth.currentUser?.uid) {
        throw Exception('You can only delete your own posts');
      }
      
      // Try to delete the post directly first - if it fails, we'll show the security rules dialog
      try {
        await _firestore.collection('posts').doc(post.id).delete();
        print('DEBUG: Successfully deleted post ${post.id}');
        
        // Try to delete comments after successfully deleting the post
        final commentsSnapshot = await _firestore
            .collection('posts')
            .doc(post.id)
            .collection('comments')
            .get();
        
        print('DEBUG: Found ${commentsSnapshot.docs.length} comments to delete');
        
        for (final commentDoc in commentsSnapshot.docs) {
          try {
            await _firestore
                .collection('posts')
                .doc(post.id)
                .collection('comments')
                .doc(commentDoc.id)
                .delete();
            print('DEBUG: Deleted comment ${commentDoc.id}');
          } catch (e) {
            print('WARNING: Failed to delete comment ${commentDoc.id}: $e');
            // Continue with other comments even if one fails
          }
        }
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Post deleted')),
        );
      } catch (e) {
        print('Error deleting post: $e');
        if (e.toString().contains('permission-denied')) {
          _showFirebaseSecurityRulesDialog(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting post: $e')),
          );
        }
      }
    } catch (e) {
      print('Error in delete post flow: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // Add image picking functionality
  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      
      if (pickedFile != null) {
        // Here you would normally upload the image and add it to the post
        // For now, just show a confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image selected: ${pickedFile.name}')),
        );
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image')),
      );
    }
  }

  // Add this function to show comments in a bottom sheet
  void _showCommentsSheet(BuildContext context, PostData post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Comments',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Divider(),
                  Expanded(
                    child: _buildCommentsList(post),
                  ),
                  Divider(),
                  // Add comment form
                  _buildAddCommentForm(post),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  // Widget to build a single comment item
  Widget _buildCommentItem(CommentData comment) {
    final currentUserId = _auth.currentUser?.uid ?? '';
    final isCurrentUserComment = comment.userId == currentUserId;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User avatar
          CircleAvatar(
            radius: 16,
            backgroundImage: comment.userProfileImage.isNotEmpty
                ? NetworkImage(comment.userProfileImage) as ImageProvider
                : AssetImage('lib/assets/images/BumpToBaby Logo.png'),
          ),
          SizedBox(width: 8),
          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      comment.username,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      _formatTimestamp(comment.timestamp),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  comment.content,
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
              ],
            ),
          ),
          // Three dots menu for current user's comments
          if (isCurrentUserComment)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 18),
              padding: EdgeInsets.zero,
              onSelected: (value) async {
                if (value == 'edit') {
                  _editComment(comment);
                } else if (value == 'delete') {
                  await _deleteComment(comment);
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'edit',
                  height: 40,
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 16),
                      SizedBox(width: 8),
                      Text('Edit', style: GoogleFonts.poppins(fontSize: 13)),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  height: 40,
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: GoogleFonts.poppins(fontSize: 13, color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
  
  // Add this function to edit comments
  void _editComment(CommentData comment) {
    final TextEditingController editController = TextEditingController(text: comment.content);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Comment', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: editController,
          decoration: InputDecoration(
            hintText: 'Edit your comment...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            child: Text('Cancel', style: GoogleFonts.poppins()),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text('Save', style: GoogleFonts.poppins(color: Color(0xFF1E6091))),
            onPressed: () async {
              if (editController.text.trim().isNotEmpty) {
                await _updateComment(comment, editController.text.trim());
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }
  
  // Add this function to update a comment in Firestore
  Future<void> _updateComment(CommentData comment, String newContent) async {
    try {
      // Try to find the comment directly in the post where it was shown
      final commentParentSnapshot = await _firestore
          .collection('posts')
          .doc(comment.postId)  // We've added postId to the CommentData class
          .collection('comments')
          .doc(comment.id)
          .get();
      
      if (commentParentSnapshot.exists) {
        await _firestore
            .collection('posts')
            .doc(comment.postId)
            .collection('comments')
            .doc(comment.id)
            .update({
          'content': newContent,
          'editedAt': FieldValue.serverTimestamp(),
        });
        
        print('DEBUG: Updated comment ${comment.id} in post ${comment.postId}');
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Comment updated')),
        );
        return;
      }
      
      // Fallback to the old approach if postId is not available
      final querySnapshot = await _firestore
          .collection('posts')
          .where('commentCount', isGreaterThan: 0)
          .get();
      
      bool found = false;
      for (final doc in querySnapshot.docs) {
        try {
          await _firestore
              .collection('posts')
              .doc(doc.id)
              .collection('comments')
              .doc(comment.id)
              .update({
            'content': newContent,
            'editedAt': FieldValue.serverTimestamp(),
          });
          
          print('DEBUG: Updated comment ${comment.id} in post ${doc.id}');
          found = true;
          break;
        } catch (e) {
          continue;
        }
      }
      
      if (found) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Comment updated')),
        );
      } else {
        throw Exception('Comment not found');
      }
    } catch (e) {
      print('Error updating comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating comment: $e')),
      );
    }
  }
  
  // Add this function to delete a comment
  Future<void> _deleteComment(CommentData comment) async {
    try {
      // First confirm deletion
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete Comment', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete this comment?', style: GoogleFonts.poppins()),
          actions: [
            TextButton(
              child: Text('Cancel', style: GoogleFonts.poppins()),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );
      
      if (confirmed != true) return;
      
      // Try to find the comment directly in the post where it was shown
      if (comment.postId != null && comment.postId!.isNotEmpty) {
        await _firestore
            .collection('posts')
            .doc(comment.postId)
            .collection('comments')
            .doc(comment.id)
            .delete();
        
        // Decrement the comment count on the post
        await _firestore
            .collection('posts')
            .doc(comment.postId)
            .update({
          'commentCount': FieldValue.increment(-1),
        });
        
        print('DEBUG: Deleted comment ${comment.id} from post ${comment.postId}');
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Comment deleted')),
        );
        return;
      }
      
      // Fallback to the old approach if postId is not available
      final querySnapshot = await _firestore
          .collection('posts')
          .where('commentCount', isGreaterThan: 0)
          .get();
      
      bool found = false;
      for (final doc in querySnapshot.docs) {
        try {
          await _firestore
              .collection('posts')
              .doc(doc.id)
              .collection('comments')
              .doc(comment.id)
              .delete();
          
          // Decrement the comment count on the post
          await _firestore
              .collection('posts')
              .doc(doc.id)
              .update({
            'commentCount': FieldValue.increment(-1),
          });
          
          print('DEBUG: Deleted comment ${comment.id} from post ${doc.id}');
          found = true;
          break;
        } catch (e) {
          continue;
        }
      }
      
      if (found) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Comment deleted')),
        );
      } else {
        throw Exception('Comment not found');
      }
    } catch (e) {
      print('Error deleting comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting comment: $e')),
      );
    }
  }

  // Widget to add a new comment
  Widget _buildAddCommentForm(PostData post) {
    final TextEditingController commentController = TextEditingController();
    
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom),
      child: Row(
        children: [
          // User avatar
          CircleAvatar(
            radius: 16,
            backgroundImage: _profileImageUrl.isNotEmpty
                ? NetworkImage(_profileImageUrl) as ImageProvider
                : AssetImage('lib/assets/images/BumpToBaby Logo.png'),
          ),
          SizedBox(width: 8),
          // Comment input field
          Expanded(
            child: TextField(
              controller: commentController,
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                hintStyle: GoogleFonts.poppins(fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              style: GoogleFonts.poppins(fontSize: 13),
              maxLines: 1,
            ),
          ),
          SizedBox(width: 8),
          // Send button
          IconButton(
            icon: Icon(Icons.send, color: Color(0xFF1E6091)),
            onPressed: () {
              // Submit comment
              if (commentController.text.trim().isNotEmpty) {
                _submitComment(post, commentController.text);
                commentController.clear();
              }
            },
          ),
        ],
      ),
    );
  }
  
  // Function to submit a new comment
  Future<void> _submitComment(PostData post, String content) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      // Get user data
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      String username = user.displayName ?? 'Anonymous';  // First try Firebase Auth display name
      String profileImageUrl = '';
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        // Try various field names that might contain the username
        username = userData['displayName'] ?? userData['name'] ?? userData['username'] ?? username;
        profileImageUrl = userData['profileImageUrl'] ?? userData['photoURL'] ?? userData['photoUrl'] ?? '';
      }
      
      print('DEBUG: Adding comment with username: $username');
      print('DEBUG: Post ID: ${post.id}');
      
      // Add comment to firestore
      DocumentReference commentRef = await _firestore
          .collection('posts')
          .doc(post.id)
          .collection('comments')
          .add({
        'userId': user.uid,
        'username': username,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'userProfileImage': profileImageUrl,
      });
      
      print('DEBUG: Created comment with ID: ${commentRef.id}');
      
      // Update comment count on post
      await _firestore.collection('posts').doc(post.id).update({
        'commentCount': FieldValue.increment(1),
      });
      
    } catch (e) {
      print('Error adding comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding comment: $e')),
      );
    }
  }

  // Modify comment stream to add postId to each CommentData
  Widget _buildCommentsList(PostData post) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('posts')
          .doc(post.id)
          .collection('comments')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading comments'));
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No comments yet. Be the first to comment!',
              style: GoogleFonts.poppins(color: Colors.grey),
            )
          );
        }
        
        // Build list of comments
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            final comment = CommentData(
              id: doc.id,
              userId: data['userId'] ?? '',
              username: data['username'] ?? 'Anonymous',
              content: data['content'] ?? '',
              timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
              userProfileImage: data['userProfileImage'] ?? '',
              postId: post.id,  // Add the post ID
            );
            
            return _buildCommentItem(comment);
          },
        );
      },
    );
  }

  // Add a function to show Firebase security rules information
  void _showFirebaseSecurityRulesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Firebase Security Rules', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You need to update your Firebase security rules to allow users to create, read, update, and delete their own posts and comments.',
                style: GoogleFonts.poppins(),
              ),
              SizedBox(height: 16),
              Text('Here are the rules you need to add:', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
'''
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow users to read all posts
    match /posts/{postId} {
      allow read: if true;
      // Only allow create/update/delete if user is authenticated and it's their post
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null && request.auth.uid == resource.data.userId;
      
      // Allow access to comments subcollection
      match /comments/{commentId} {
        allow read: if true;
        allow create: if request.auth != null;
        allow update, delete: if request.auth != null && request.auth.uid == resource.data.userId;
      }
    }
    
    // Allow access to fact_checks collection
    match /fact_checks/{factCheckId} {
      allow read: if true;
      allow create: if request.auth != null;
    }
    
    // Allow users to read/write their own data
    match /users/{userId} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Allow access to medical_info collection
    match /medical_info/{infoId} {
      allow read: if true;
    }
  }
}
''',
                  style: GoogleFonts.sourceCodePro(fontSize: 12),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'How to update your rules:',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '1. Go to the Firebase Console (console.firebase.google.com)',
                style: GoogleFonts.poppins(),
              ),
              Text(
                '2. Select your project',
                style: GoogleFonts.poppins(),
              ),
              Text(
                '3. Click on "Firestore Database" in the left sidebar',
                style: GoogleFonts.poppins(),
              ),
              Text(
                '4. Click on the "Rules" tab',
                style: GoogleFonts.poppins(),
              ),
              Text(
                '5. Replace the current rules with the ones above',
                style: GoogleFonts.poppins(),
              ),
              Text(
                '6. Click "Publish"',
                style: GoogleFonts.poppins(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('Close', style: GoogleFonts.poppins()),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
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
  final bool isMedicalMisinformation;
  final String? factCheckId;

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
    required this.isMedicalMisinformation,
    this.factCheckId,
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
      isMedicalMisinformation: data['isMedicalMisinformation'] ?? false,
      factCheckId: data['factCheckId'],
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
  final String? postId;  // Add postId field

  CommentData({
    required this.id,
    required this.userId,
    required this.username,
    required this.content,
    required this.timestamp,
    required this.userProfileImage,
    this.postId,  // Make it optional
  });

  factory CommentData.fromFirestore(DocumentSnapshot doc, {String? postId}) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CommentData(
      id: doc.id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? 'Anonymous',
      content: data['content'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      userProfileImage: data['userProfileImage'] ?? '',
      postId: postId,  // Pass postId to the constructor
    );
  }
} 