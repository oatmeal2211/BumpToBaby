import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import './audio_visual_learning_screen.dart'; // Assuming MediaCarouselItem is in this file

class PlayerScreen extends StatefulWidget {
  final MediaCarouselItem mediaItem;

  const PlayerScreen({Key? key, required this.mediaItem}) : super(key: key);

  @override
  _PlayerScreenState createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _isPlaying = false;
  double _progressValue = 0.3;

  IconData _getMediaIcon() {
    if (widget.mediaItem.type.toLowerCase().contains('video')) {
      return Icons.play_circle_fill_rounded;
    } else if (widget.mediaItem.type.toLowerCase().contains('audiobook') || 
               widget.mediaItem.type.toLowerCase().contains('podcast')) {
      return Icons.mic_rounded;
    } else if (widget.mediaItem.type.toLowerCase().contains('music')) {
      return Icons.music_note_rounded;
    }
    return Icons.play_arrow_rounded; // Default icon
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.mediaItem.title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF005792),
          ),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.white,
        elevation: 2.0,
        iconTheme: const IconThemeData(color: Color(0xFF005792)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Media Placeholder
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: Colors.grey.shade300)
                ),
                child: Center(
                  child: Icon(
                    _getMediaIcon(), 
                    size: 100, 
                    color: widget.mediaItem.iconColor.withOpacity(0.8)
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24.0),

            // Title and Description
            Text(
              widget.mediaItem.title,
              style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (widget.mediaItem.description != null && widget.mediaItem.description!.isNotEmpty) ...[
              const SizedBox(height: 8.0),
              Text(
                widget.mediaItem.description!,
                style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[700]),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 24.0),

            // Dummy Seek Bar
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: widget.mediaItem.iconColor,
                inactiveTrackColor: widget.mediaItem.iconColor.withOpacity(0.3),
                trackHeight: 8.0,
                thumbColor: widget.mediaItem.iconColor,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
                overlayColor: widget.mediaItem.iconColor.withAlpha(0x29),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
              ),
              child: Slider(
                value: _progressValue,
                min: 0,
                max: 1,
                onChanged: (value) {
                  setState(() {
                    _progressValue = value;
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('1:20', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                  Text('5:00', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            const SizedBox(height: 16.0),

            // Dummy Playback Controls
            IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                size: 64.0,
                color: widget.mediaItem.iconColor,
              ),
              onPressed: () {
                setState(() {
                  _isPlaying = !_isPlaying;
                });
              },
            ),
            const Spacer(), // Pushes controls to the bottom if space allows
          ],
        ),
      ),
    );
  }
} 