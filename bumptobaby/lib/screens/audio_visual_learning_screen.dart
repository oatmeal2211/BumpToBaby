import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import './player_screen.dart'; // Import the new player screen

// Data model for carousel items
class MediaCarouselItem {
  final String title;
  final String type; // e.g., "Video - 12 mins", "Audiobook - Chapter 1"
  final IconData iconData;
  final Color iconColor;
  final String? description;

  const MediaCarouselItem({
    required this.title,
    required this.type,
    required this.iconData,
    required this.iconColor,
    this.description,
  });
}

class AudioVisualLearningScreen extends StatelessWidget {
  const AudioVisualLearningScreen({Key? key}) : super(key: key);

  // Mock data for carousels
  static const List<MediaCarouselItem> _videoItems = [
    MediaCarouselItem(title: 'Prenatal Yoga', type: 'Video - 12 mins', iconData: Icons.ondemand_video, iconColor: Colors.redAccent, description: 'Gentle yoga poses for comfort.'),
    MediaCarouselItem(title: 'Nutrition Tips', type: 'Video - 15 mins', iconData: Icons.ondemand_video, iconColor: Colors.greenAccent, description: 'Healthy eating during pregnancy.'),
    MediaCarouselItem(title: 'Labor Preparation', type: 'Video - 20 mins', iconData: Icons.ondemand_video, iconColor: Colors.blueAccent, description: 'Understanding the stages of labor.'),
    MediaCarouselItem(title: 'Postpartum Care Basics', type: 'Video - 10 mins', iconData: Icons.ondemand_video, iconColor: Colors.pinkAccent, description: 'Essential tips for new mothers.'),
    MediaCarouselItem(title: 'Breastfeeding Techniques', type: 'Video - 18 mins', iconData: Icons.ondemand_video, iconColor: Colors.orangeAccent, description: 'Learn effective breastfeeding techniques.'),
    MediaCarouselItem(title: 'Baby Massage', type: 'Video - 14 mins', iconData: Icons.ondemand_video, iconColor: Colors.purpleAccent, description: 'How to massage your baby for relaxation.'),
    MediaCarouselItem(title: 'Postnatal Exercise', type: 'Video - 25 mins', iconData: Icons.ondemand_video, iconColor: Colors.tealAccent, description: 'Exercises for new mothers.'),
    MediaCarouselItem(title: 'Infant CPR', type: 'Video - 30 mins', iconData: Icons.ondemand_video, iconColor: Colors.amberAccent, description: 'Learn infant CPR techniques.'),
    MediaCarouselItem(title: 'Baby Sleep Training', type: 'Video - 22 mins', iconData: Icons.ondemand_video, iconColor: Colors.lightBlueAccent, description: 'Tips for better sleep for your baby.'),
    MediaCarouselItem(title: 'Healthy Meal Prep', type: 'Video - 28 mins', iconData: Icons.ondemand_video, iconColor: Colors.cyanAccent, description: 'Meal prep ideas for busy parents.'),
  ];

  static const List<MediaCarouselItem> _audiobookItems = [
    MediaCarouselItem(title: 'The Mindful Pregnancy', type: 'Audiobook - Ch 1', iconData: Icons.headset, iconColor: Colors.purpleAccent, description: 'Meditation and mindfulness.'),
    MediaCarouselItem(title: 'Pregnancy Health Companion', type: 'Audiobook - Part 1', iconData: Icons.headset, iconColor: Colors.orangeAccent, description: 'Expert advice for a healthy term.'),
    MediaCarouselItem(title: 'Baby Names & Meanings', type: 'Audiobook - Intro', iconData: Icons.headset, iconColor: Colors.amberAccent, description: 'Find the perfect name.'),
    MediaCarouselItem(title: 'Preparing for Birth', type: 'Audiobook - Ch 2', iconData: Icons.headset, iconColor: Colors.tealAccent, description: 'What to expect during labor.'),
    MediaCarouselItem(title: 'Postpartum Recovery', type: 'Audiobook - Part 2', iconData: Icons.headset, iconColor: Colors.blueAccent, description: 'Guidance for recovery after childbirth.'),
    MediaCarouselItem(title: 'Mindful Parenting', type: 'Audiobook - Ch 3', iconData: Icons.headset, iconColor: Colors.greenAccent, description: 'Parenting with mindfulness.'),
    MediaCarouselItem(title: 'Baby Care Basics', type: 'Audiobook - Intro', iconData: Icons.headset, iconColor: Colors.redAccent, description: 'Essential tips for new parents.'),
    MediaCarouselItem(title: 'Understanding Your Baby', type: 'Audiobook - Ch 4', iconData: Icons.headset, iconColor: Colors.purpleAccent, description: 'Insights into baby behavior.'),
    MediaCarouselItem(title: 'Nutrition for New Moms', type: 'Audiobook - Part 3', iconData: Icons.headset, iconColor: Colors.orangeAccent, description: 'Healthy eating after childbirth.'),
    MediaCarouselItem(title: 'Bonding with Your Baby', type: 'Audiobook - Ch 5', iconData: Icons.headset, iconColor: Colors.tealAccent, description: 'Building a strong bond with your newborn.'),
  ];

  static const List<MediaCarouselItem> _podcastItems = [
    MediaCarouselItem(title: 'New Mom Talks', type: 'Podcast - Ep 5', iconData: Icons.mic, iconColor: Colors.tealAccent, description: 'Real stories and practical tips.'),
    MediaCarouselItem(title: 'Dad\'s Guide to Pregnancy', type: 'Podcast - Ep 3', iconData: Icons.mic, iconColor: Colors.lightBlueAccent, description: 'For expecting fathers.'),
    MediaCarouselItem(title: 'Birth Stories Unfiltered', type: 'Podcast - Ep 10', iconData: Icons.mic, iconColor: Colors.cyanAccent, description: 'Inspiring and honest experiences.'),
    MediaCarouselItem(title: 'Healthy Pregnancy Podcast', type: 'Podcast - Ep 2', iconData: Icons.mic, iconColor: Colors.greenAccent, description: 'Tips for a healthy pregnancy journey.'),
    MediaCarouselItem(title: 'Parenting After Birth', type: 'Podcast - Ep 4', iconData: Icons.mic, iconColor: Colors.redAccent, description: 'Navigating the first few months with a newborn.'),
    MediaCarouselItem(title: 'Pregnancy Myths Debunked', type: 'Podcast - Ep 6', iconData: Icons.mic, iconColor: Colors.purpleAccent, description: 'Separating fact from fiction.'),
    MediaCarouselItem(title: 'The Fourth Trimester', type: 'Podcast - Ep 7', iconData: Icons.mic, iconColor: Colors.orangeAccent, description: 'Understanding the postpartum period.'),
    MediaCarouselItem(title: 'Breastfeeding Basics', type: 'Podcast - Ep 8', iconData: Icons.mic, iconColor: Colors.tealAccent, description: 'Tips for successful breastfeeding.'),
    MediaCarouselItem(title: 'Navigating Parenthood', type: 'Podcast - Ep 9', iconData: Icons.mic, iconColor: Colors.lightBlueAccent, description: 'Advice for new parents.'),
    MediaCarouselItem(title: 'Mental Health for Moms', type: 'Podcast - Ep 11', iconData: Icons.mic, iconColor: Colors.cyanAccent, description: 'Caring for your mental health.'),
  ];

  static const List<MediaCarouselItem> _relaxingMusicItems = [
    MediaCarouselItem(title: 'Calm Piano Music', type: 'Music - 30 mins', iconData: Icons.music_note, iconColor: Colors.blueAccent, description: 'Relaxing piano melodies for stress relief.'),
    MediaCarouselItem(title: 'Nature Sounds', type: 'Music - 45 mins', iconData: Icons.music_note, iconColor: Colors.greenAccent, description: 'Soothing sounds of nature to help you unwind.'),
    MediaCarouselItem(title: 'Meditation Music', type: 'Music - 60 mins', iconData: Icons.music_note, iconColor: Colors.purpleAccent, description: 'Guided meditation with calming background music.'),
    MediaCarouselItem(title: 'Lullabies for Relaxation', type: 'Music - 25 mins', iconData: Icons.music_note, iconColor: Colors.pinkAccent, description: 'Gentle lullabies to help you relax and sleep.'),
    MediaCarouselItem(title: 'Ocean Waves', type: 'Music - 50 mins', iconData: Icons.music_note, iconColor: Colors.tealAccent, description: 'Relaxing ocean wave sounds for a peaceful atmosphere.'),
    MediaCarouselItem(title: 'Chill Out Music', type: 'Music - 40 mins', iconData: Icons.music_note, iconColor: Colors.amberAccent, description: 'Chill music for relaxation.'),
    MediaCarouselItem(title: 'Rain Sounds', type: 'Music - 35 mins', iconData: Icons.music_note, iconColor: Colors.lightBlueAccent, description: 'Soothing rain sounds for sleep.'),
    MediaCarouselItem(title: 'Guided Relaxation', type: 'Music - 55 mins', iconData: Icons.music_note, iconColor: Colors.cyanAccent, description: 'Guided relaxation techniques.'),
    MediaCarouselItem(title: 'Meditative Flute', type: 'Music - 45 mins', iconData: Icons.music_note, iconColor: Colors.greenAccent, description: 'Flute music for meditation.'),
    MediaCarouselItem(title: 'Soft Guitar Melodies', type: 'Music - 30 mins', iconData: Icons.music_note, iconColor: Colors.purpleAccent, description: 'Gentle guitar melodies for relaxation.'),
  ];

  // Helper function to create a section title
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 24.0, bottom: 8.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF005792), // Theme color
        ),
      ),
    );
  }

  // Helper function to create a carousel item card
  Widget _buildCarouselItemCard(BuildContext context, MediaCarouselItem item) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerScreen(mediaItem: item),
          ),
        );
      },
      child: SizedBox(
        width: 170, // Width of each card in the carousel
        child: Card(
          elevation: 3.0,
          margin: const EdgeInsets.symmetric(vertical: 8.0), // Margin around card (vertical only, horizontal handled by ListView padding)
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          clipBehavior: Clip.antiAlias, // Ensures content respects rounded corners
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container( // Placeholder for thumbnail
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: item.iconColor.withOpacity(0.25),
                ),
                child: Center(
                  child: Icon(item.iconData, size: 45, color: item.iconColor),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      item.type,
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.description != null && item.description!.isNotEmpty) ...[
                      const SizedBox(height: 4.0),
                      Text(
                        item.description!,
                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper function to build a horizontal carousel
  Widget _buildHorizontalCarousel({
    required BuildContext context,
    required List<MediaCarouselItem> items,
  }) {
    return Container(
      height: 220, // Adjust height to fit the new card design + padding
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        padding: const EdgeInsets.symmetric(horizontal: 16.0), // Padding for the whole carousel
        itemBuilder: (carouselContext, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 12.0), // Space between cards
            child: _buildCarouselItemCard(context, items[index]),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Audio/Visual Learning',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF005792)
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 2.0,
        iconTheme: const IconThemeData(color: Color(0xFF005792)),
      ),
      body: ListView(
        children: [
          _buildSectionTitle(context, 'Featured Videos'),
          _buildHorizontalCarousel(context: context, items: _videoItems),

          _buildSectionTitle(context, 'Helpful Audiobooks'),
          _buildHorizontalCarousel(context: context, items: _audiobookItems),

          _buildSectionTitle(context, 'Informative Podcasts'),
          _buildHorizontalCarousel(context: context, items: _podcastItems),

          _buildSectionTitle(context, 'Relaxing Music'),
          _buildHorizontalCarousel(context: context, items: _relaxingMusicItems),

          const SizedBox(height: 24), // Add some padding at the bottom
        ],
      ),
    );
  }
} 