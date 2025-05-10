import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EventData {
  final String title;
  final DateTime date;
  final String description;
  final String imageUrl;
  final Color color;
  final String location;
  final String organizer;
  final List<String> agenda;
  final int participantsCount;

  const EventData({
    required this.title,
    required this.date,
    required this.description,
    required this.imageUrl,
    required this.color,
    this.location = '',
    this.organizer = '',
    this.agenda = const [],
    this.participantsCount = 0,
  });
}

class EventDetailsScreen extends StatefulWidget {
  final EventData event;

  const EventDetailsScreen({Key? key, required this.event}) : super(key: key);

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  bool _isJoined = false;
  bool _isLoading = false;
  int _participantsCount = 0;

  @override
  void initState() {
    super.initState();
    _participantsCount = widget.event.participantsCount;
    _checkIfJoined();
  }

  Future<void> _checkIfJoined() async {
    setState(() {
      _isLoading = true;
    });

    // Simulating a network request to check if user has joined
    await Future.delayed(Duration(milliseconds: 800));
    
    // This is just a simulation - in a real app, you'd check Firestore
    // For demo purposes, we'll randomly decide if user is joined or not
    setState(() {
      _isJoined = widget.event.title.length % 2 == 0; // Just a random way to decide
      _isLoading = false;
    });
  }

  Future<void> _toggleJoinStatus() async {
    setState(() {
      _isLoading = true;
    });

    // Simulating a network request
    await Future.delayed(Duration(milliseconds: 1500));
    
    setState(() {
      _isJoined = !_isJoined;
      _participantsCount = _isJoined 
          ? _participantsCount + 1 
          : _participantsCount - 1;
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isJoined 
            ? 'You have joined this event!' 
            : 'You have left this event'),
        backgroundColor: _isJoined ? Colors.green : Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEventHeader(),
                  const SizedBox(height: 24),
                  _buildInfoRow(Icons.location_on, 'Location', widget.event.location.isNotEmpty 
                      ? widget.event.location 
                      : '${widget.event.title} Center'),
                  const Divider(),
                  _buildInfoRow(Icons.person_outline, 'Organizer', widget.event.organizer.isNotEmpty 
                      ? widget.event.organizer 
                      : 'BumpToBaby Association'),
                  const Divider(),
                  _buildInfoRow(Icons.people_outline, 'Participants', '$_participantsCount people joined'),
                  const SizedBox(height: 24),
                  _buildDescription(),
                  const SizedBox(height: 24),
                  _buildAgendaSection(),
                  const SizedBox(height: 80), // Space for the button
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: _isLoading 
            ? Center(child: CircularProgressIndicator())
            : ElevatedButton(
                onPressed: _toggleJoinStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isJoined ? Colors.redAccent : Color(0xFF1E6091),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  _isJoined ? 'Leave Event' : 'Join Event',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200.0,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              widget.event.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: widget.event.color);
              },
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
            ),
          ],
        ),
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            widget.event.title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
      ),
    );
  }

  Widget _buildEventHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.event.color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: widget.event.color),
          ),
          child: Text(
            DateFormat('MMM d, yyyy • h:mm a').format(widget.event.date),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        const Spacer(),
        Icon(Icons.calendar_today, size: 18, color: Colors.grey[700]),
        const SizedBox(width: 4),
        Text(
          'Add to Calendar',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Color(0xFF1E6091)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About this Event',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.event.description + "\n\n" +
          "This event is designed for expectant mothers, new parents, and healthcare professionals. Join us for a day of learning, sharing experiences, and connecting with others in your community. We'll be covering a range of topics relevant to maternal health, child development, and family wellbeing.",
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: Colors.black87,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildAgendaSection() {
    // Default agenda if none is provided
    final agenda = widget.event.agenda.isNotEmpty
        ? widget.event.agenda
        : [
            "9:00 AM - Welcome and Registration",
            "10:00 AM - Keynote Speaker: Advancements in Maternal Health",
            "11:30 AM - Interactive Workshop Session",
            "1:00 PM - Lunch Break & Networking",
            "2:00 PM - Panel Discussion: Expert Q&A",
            "4:00 PM - Closing Remarks & Future Plans"
          ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Event Agenda',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...agenda.map((item) => _buildAgendaItem(item)).toList(),
      ],
    );
  }

  Widget _buildAgendaItem(String item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 12, color: widget.event.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 