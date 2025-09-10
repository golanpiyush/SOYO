import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:screen_brightness/screen_brightness.dart';
import 'package:soyo/models/subtitle_model.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volume_controller/volume_controller.dart';

// Required dependencies in pubspec.yaml:
/*
dependencies:
  video_player: ^2.8.1
  chewie: ^1.7.4
  url_launcher: ^6.2.1
  google_fonts: ^6.1.0
  shared_preferences: ^2.2.2
*/

class SimpleStreamPlayer extends StatefulWidget {
  final String streamUrl;
  final String movieTitle;
  final Duration? startPosition;
  final Function(Duration)? onPositionChanged;
  final List<String>? subtitleUrls; // Add this parameter

  const SimpleStreamPlayer({
    Key? key,
    required this.streamUrl,
    required this.movieTitle,
    this.startPosition,
    this.onPositionChanged,
    this.subtitleUrls, // Add this parameter
  }) : super(key: key);

  @override
  State<SimpleStreamPlayer> createState() => _SimpleStreamPlayerState();
}

class _SimpleStreamPlayerState extends State<SimpleStreamPlayer>
    with TickerProviderStateMixin {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _showCustomControls = false;
  Timer? _controlsHideTimer;
  bool _isPlaying = true;
  bool _isLoading = true;
  String? _error;
  bool _isFullscreen = false;
  bool _showControls = true;
  bool _isControlsLocked = false;
  double _currentScale = 1.0;
  Offset _focalPoint = Offset.zero;
  double _currentBrightness = 0.5;
  double _currentVolume = 0.5;
  bool _isDragging = false;
  String? _overlayText;
  Timer? _overlayTimer;
  double _previousScale = 1.0;
  // Add subtitle-related fields
  List<SubtitleEntry> _subtitles = [];
  String? _currentSubtitle;
  bool _showSubtitles = true;
  int _selectedSubtitleIndex = 0;
  List<String> _availableSubtitles = [];
  Timer? _subtitleTimer;
  late AnimationController _overlayController;
  late Animation<double> _overlayAnimation;
  late AnimationController _fadeController;
  late AnimationController _loadingController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initializePlayer();
    _setLandscapeMode();
    _initBrightnessAndVolume();
    _loadSubtitles(); // Add this line

    // Initialize play state
    _isPlaying = true;

    // Show controls initially
    _showControlsTemporarily();
  }

  // Add this method to download and parse subtitles
  Future<void> _loadSubtitles() async {
    if (widget.subtitleUrls == null || widget.subtitleUrls!.isEmpty) return;

    _availableSubtitles = [
      'None',
      ...List.generate(
        widget.subtitleUrls!.length,
        (index) => 'Subtitle ${index + 1}',
      ),
    ];

    try {
      // Load first subtitle by default
      if (widget.subtitleUrls!.isNotEmpty) {
        await _loadSubtitleTrack(widget.subtitleUrls![0]);
      }
    } catch (e) {
      print('Error loading subtitles: $e');
    }
  }

  Future<void> _loadSubtitleTrack(String subtitleUrl) async {
    try {
      final response = await http.get(Uri.parse(subtitleUrl));
      if (response.statusCode == 200) {
        _subtitles = _parseSRT(response.body);
        _startSubtitleTimer();
      }
    } catch (e) {
      print('Error loading subtitle track: $e');
    }
  }

  List<SubtitleEntry> _parseSRT(String srtContent) {
    final List<SubtitleEntry> subtitles = [];
    final blocks = srtContent.split('\n\n');

    for (final block in blocks) {
      final lines = block.trim().split('\n');
      if (lines.length >= 3) {
        try {
          final timecodeLine = lines[1];
          final textLines = lines.sublist(2);

          final times = timecodeLine.split(' --> ');
          if (times.length == 2) {
            final startTime = _parseTimeCode(times[0]);
            final endTime = _parseTimeCode(times[1]);
            final text = textLines
                .join('\n')
                .replaceAll(RegExp(r'<[^>]*>'), ''); // Remove HTML tags

            subtitles.add(
              SubtitleEntry(startTime: startTime, endTime: endTime, text: text),
            );
          }
        } catch (e) {
          continue; // Skip malformed entries
        }
      }
    }

    return subtitles;
  }

  Duration _parseTimeCode(String timeCode) {
    final parts = timeCode.trim().split(':');
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    final secondsAndMs = parts[2].split(',');
    final seconds = int.parse(secondsAndMs[0]);
    final milliseconds = int.parse(secondsAndMs[1]);

    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: milliseconds,
    );
  }

  void _startSubtitleTimer() {
    _subtitleTimer?.cancel();
    _subtitleTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (_videoController.value.isInitialized &&
          _showSubtitles &&
          _subtitles.isNotEmpty) {
        final currentPosition = _videoController.value.position;
        String? newSubtitle;

        for (final subtitle in _subtitles) {
          if (currentPosition >= subtitle.startTime &&
              currentPosition <= subtitle.endTime) {
            newSubtitle = subtitle.text;
            break;
          }
        }

        if (newSubtitle != _currentSubtitle) {
          setState(() {
            _currentSubtitle = newSubtitle;
          });
        }
      }
    });
  }

  // New initialization methods
  void _setLandscapeMode() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  void _initBrightnessAndVolume() async {
    try {
      _currentBrightness = await ScreenBrightness().current;
    } catch (e) {
      _currentBrightness = 0.5;
    }

    _currentVolume = 0.7;
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _overlayController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.linear),
    );
    _overlayAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _overlayController, curve: Curves.easeInOut),
    );

    _loadingController.repeat();
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.streamUrl),
        httpHeaders: {
          'User-Agent':
              'ExoPlayer/2.18.0 (Linux; Android 11) ExoPlayerLib/2.18.0',
          'Accept': '*/*',
          'Accept-Encoding': 'identity',
          'Connection': 'keep-alive',
        },
      );

      await _videoController.initialize();

      // Calculate and set optimal zoom after initialization
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _currentScale = _calculateOptimalZoom();
        });
      });

      // Load saved position
      await _loadSavedPosition();

      _videoController.addListener(_onPositionChanged);

      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        allowFullScreen: false,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        showControls: false, // We'll create custom controls
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFFE50914),
          handleColor: const Color(0xFFE50914),
          backgroundColor: Colors.white.withOpacity(0.2),
          bufferedColor: Colors.white.withOpacity(0.4),
        ),
        // ... rest of the controller setup
      );

      setState(() {
        _isLoading = false;
      });

      _fadeController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  // Position saving/loading methods
  Future<void> _loadSavedPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPosition = prefs.getInt('${widget.movieTitle}_position') ?? 0;
    if (savedPosition > 0) {
      await _videoController.seekTo(Duration(milliseconds: savedPosition));
    }
  }

  Future<void> _savePosition(Duration position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      '${widget.movieTitle}_position',
      position.inMilliseconds,
    );
  }

  // Updated _onPositionChanged method
  void _onPositionChanged() {
    if (_videoController.value.isInitialized) {
      final position = _videoController.value.position;
      if (widget.onPositionChanged != null) {
        widget.onPositionChanged!(position);
      }
      // Save position every 10 seconds
      if (position.inSeconds % 10 == 0) {
        _savePosition(position);
      }
    }
  }

  // Gesture handling methods
  void _handlePanStart(DragStartDetails details) {
    if (_isControlsLocked) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final tapX = details.localPosition.dx;

    setState(() {
      _isDragging = true;
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_isControlsLocked || !_isDragging) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final tapX = details.localPosition.dx;
    final deltaY = details.delta.dy;

    if (tapX < screenWidth * 0.4) {
      // Left side - brightness control
      _adjustBrightness(-deltaY / screenHeight);
    } else if (tapX > screenWidth * 0.6) {
      // Right side - volume control
      _adjustVolume(-deltaY / screenHeight);
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
    _hideOverlay();
  }

  void _adjustBrightness(double delta) async {
    _currentBrightness = (_currentBrightness + delta).clamp(0.0, 1.0);
    try {
      await ScreenBrightness().setScreenBrightness(_currentBrightness);
    } catch (e) {
      // Handle error silently
    }

    _showOverlay('🔆 ${(_currentBrightness * 100).round()}%');
  }

  void _adjustVolume(double delta) async {
    _currentVolume = (_currentVolume + delta).clamp(0.0, 1.0);

    if (_videoController.value.isInitialized) {
      await _videoController.setVolume(_currentVolume);
    }

    _showOverlay('🔊 ${(_currentVolume * 100).round()}%');
  }

  void _showOverlay(String text) {
    setState(() {
      _overlayText = text;
    });

    _overlayController.forward();

    _overlayTimer?.cancel();
    _overlayTimer = Timer(Duration(milliseconds: 1000), () {
      _hideOverlay();
    });
  }

  void _hideOverlay() {
    _overlayController.reverse().then((_) {
      setState(() {
        _overlayText = null;
      });
    });
  }

  // Scale/zoom handling
  void _handleScaleStart(ScaleStartDetails details) {
    if (_isControlsLocked) return;
    _focalPoint = details.focalPoint;
    _previousScale = _currentScale;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_isControlsLocked) return;

    // Calculate new scale with limits
    double newScale = _previousScale * details.scale;

    // Apply scale limits (0.5x to 4x)
    newScale = newScale.clamp(0.5, 4.0);

    setState(() {
      _currentScale = newScale;
    });
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    // Snap to common zoom levels when pinch ends
    if (_currentScale > 2.5) {
      setState(() {
        _currentScale = 4.0; // Max zoom
      });
    } else if (_currentScale > 1.5) {
      setState(() {
        _currentScale = 2.0; // 2x zoom
      });
    } else if (_currentScale < 0.75) {
      setState(() {
        _currentScale = 0.5; // Min zoom
      });
    } else if (_currentScale < 1.25) {
      setState(() {
        _currentScale = 1.0; // Normal zoom
      });
    }

    _showOverlay('Zoom: ${_currentScale.toStringAsFixed(1)}x');
  }

  // Lock toggle
  void _toggleLock() {
    setState(() {
      _isControlsLocked = !_isControlsLocked;
    });

    // Recreate chewie controller with updated showControls setting
    if (_chewieController != null) {
      final oldController = _chewieController!;
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: oldController.isPlaying,
        looping: false,
        allowFullScreen: false,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        showControls: !_isControlsLocked,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFFE50914),
          handleColor: const Color(0xFFFF6B6B),
          backgroundColor: Colors.grey[800]!,
          bufferedColor: Colors.grey[600]!,
        ),
        placeholder: oldController.placeholder,
        errorBuilder: oldController.errorBuilder,
      );
      oldController.dispose();
    }

    _showOverlay(_isControlsLocked ? '🔒 Locked' : '🔓 Unlocked');
  }

  Widget _buildSubtitleControls() {
    if (_availableSubtitles.isEmpty) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: DropdownButton<int>(
              value: _selectedSubtitleIndex,
              dropdownColor: Colors.black87,
              underline: SizedBox.shrink(),
              style: GoogleFonts.nunito(color: Colors.white, fontSize: 14),
              items: _availableSubtitles.asMap().entries.map((entry) {
                return DropdownMenuItem<int>(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (value) async {
                if (value != null) {
                  setState(() {
                    _selectedSubtitleIndex = value;
                    _currentSubtitle = null;
                  });

                  if (value == 0) {
                    // None selected
                    setState(() {
                      _showSubtitles = false;
                      _subtitles.clear();
                    });
                    _subtitleTimer?.cancel();
                  } else {
                    // Load selected subtitle
                    setState(() {
                      _showSubtitles = true;
                    });
                    await _loadSubtitleTrack(widget.subtitleUrls![value - 1]);
                  }
                }
              },
            ),
          ),
          SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              setState(() {
                _showSubtitles = !_showSubtitles;
              });
            },
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _showSubtitles ? Color(0xFFE50914) : Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.subtitles, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // Add subtitle display widget
  // Add subtitle display widget
  Widget _buildSubtitleDisplay() {
    if (!_showSubtitles ||
        _currentSubtitle == null ||
        _currentSubtitle!.isEmpty) {
      return SizedBox.shrink();
    }

    return Positioned(
      bottom: 30,
      left: 20,
      right: 20,
      child: Text(
        _currentSubtitle!,
        textAlign: TextAlign.center,
        style: GoogleFonts.nunito(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.3,
          shadows: [
            Shadow(
              offset: Offset(1.0, 1.0),
              blurRadius: 3.0,
              color: Colors.black,
            ),
            Shadow(
              offset: Offset(-1.0, -1.0),
              blurRadius: 3.0,
              color: Colors.black,
            ),
            Shadow(
              offset: Offset(1.0, -1.0),
              blurRadius: 3.0,
              color: Colors.black,
            ),
            Shadow(
              offset: Offset(-1.0, 1.0),
              blurRadius: 3.0,
              color: Colors.black,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyledButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),
    );
  }

  void _openInExternalPlayer() async {
    try {
      // Try VLC first
      final vlcUrl = 'vlc://${widget.streamUrl}';
      if (await canLaunchUrl(Uri.parse(vlcUrl))) {
        await launchUrl(Uri.parse(vlcUrl));
      } else {
        // Fallback to Android intent
        final intentUrl =
            'intent:${widget.streamUrl}#Intent;package=org.videolan.vlc;end';
        await launchUrl(Uri.parse(intentUrl));
      }
    } catch (e) {
      _showExternalPlayerDialog();
    }
  }

  void _showExternalPlayerDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.open_in_new_rounded,
                      color: const Color(0xFFE50914),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Open with External Player',
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildPlayerOption(
                icon: Icons.play_circle_rounded,
                title: 'VLC Media Player',
                subtitle: 'Recommended for streaming',
                color: const Color(0xFFFF6B00),
                onTap: () {
                  Navigator.pop(context);
                  _launchVLC();
                },
              ),
              const SizedBox(height: 12),
              _buildPlayerOption(
                icon: Icons.video_library_rounded,
                title: 'MX Player',
                subtitle: 'Popular video player',
                color: const Color(0xFF2196F3),
                onTap: () {
                  Navigator.pop(context);
                  _launchMXPlayer();
                },
              ),
              const SizedBox(height: 12),
              _buildPlayerOption(
                icon: Icons.language_rounded,
                title: 'Browser',
                subtitle: 'Open in web browser',
                color: const Color(0xFF4CAF50),
                onTap: () {
                  Navigator.pop(context);
                  _launchBrowser();
                },
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900]?.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'Stream URL:',
                      style: GoogleFonts.nunito(
                        color: Colors.grey[400],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      widget.streamUrl,
                      style: GoogleFonts.nunito(
                        color: Colors.grey[300],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Close',
                        style: GoogleFonts.nunito(
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: widget.streamUrl),
                        );
                        Navigator.pop(context);
                        _showSuccessSnackBar('URL copied to clipboard');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE50914),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Copy URL',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.nunito(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.grey[600],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _launchVLC() async {
    try {
      final vlcIntent =
          'intent:${widget.streamUrl}#Intent;package=org.videolan.vlc;end';
      await launchUrl(Uri.parse(vlcIntent));
    } catch (e) {
      _showError('VLC not installed');
    }
  }

  void _launchMXPlayer() async {
    try {
      final mxIntent =
          'intent:${widget.streamUrl}#Intent;package=com.mxtech.videoplayer.ad;end';
      await launchUrl(Uri.parse(mxIntent));
    } catch (e) {
      try {
        final mxProIntent =
            'intent:${widget.streamUrl}#Intent;package=com.mxtech.videoplayer.pro;end';
        await launchUrl(Uri.parse(mxProIntent));
      } catch (e2) {
        _showError('MX Player not installed');
      }
    }
  }

  void _launchBrowser() async {
    try {
      await launchUrl(Uri.parse(widget.streamUrl));
    } catch (e) {
      _showError('Cannot open in browser');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Text(message, style: GoogleFonts.nunito(color: Colors.white)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Text(message, style: GoogleFonts.nunito(color: Colors.white)),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: GestureDetector(
        onTap: () {
          if (_isControlsLocked) return;
          // _showControlsTemporarily();
        },
        child: Stack(
          children: [
            // Video player (NO controls here)
            _buildBody(),

            // Custom overlay controls (ONLY HERE)
            // _buildCustomOverlayControls(),

            // Lock button
            if (!_showCustomControls)
              Positioned(
                bottom: 20,
                right: 20,
                child: GestureDetector(
                  onTap: _toggleLock,
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: _isControlsLocked ? Colors.red : Colors.white54,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      _isControlsLocked ? Icons.lock : Icons.lock_open,
                      color: _isControlsLocked ? Colors.red : Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),

            // Overlay for brightness/volume feedback
            if (_overlayText != null)
              Center(
                child: FadeTransition(
                  opacity: _overlayAnimation,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Text(
                      _overlayText!,
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Container(
        color: const Color(0xFF0A0A0A),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RotationTransition(
              turns: _rotationAnimation,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE50914), Color(0xFFFF6B6B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE50914).withOpacity(0.3),
                      spreadRadius: 0,
                      blurRadius: 20,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_circle_filled,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Loading ${widget.movieTitle}',
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Initializing M3U8 stream...',
              style: GoogleFonts.nunito(
                color: Colors.grey[400],
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 200,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(2),
              ),
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFFE50914),
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Container(
        color: const Color(0xFF0A0A0A),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: Colors.red,
                size: 80,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Cannot Play Stream',
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[900]?.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: GoogleFonts.nunito(
                  color: Colors.grey[300],
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _buildStyledButton(
                    onPressed: () {
                      _videoController.dispose();
                      _chewieController?.dispose();
                      _initializePlayer();
                    },
                    icon: Icons.refresh_rounded,
                    label: 'Retry',
                    color: const Color(0xFFE50914),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStyledButton(
                    onPressed: _showExternalPlayerDialog,
                    icon: Icons.open_in_new_rounded,
                    label: 'External Player',
                    color: const Color(0xFFFF6B00),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_chewieController != null) {
      return GestureDetector(
        onTap: () {
          if (!_isControlsLocked) {
            _showControlsTemporarily();
          }
        },
        child: Stack(
          children: [
            // Video player with pinch-to-zoom only
            GestureDetector(
              onScaleStart: !_isControlsLocked ? _handleScaleStart : null,
              onScaleUpdate: !_isControlsLocked ? _handleScaleUpdate : null,
              onScaleEnd: !_isControlsLocked ? _handleScaleEnd : null,
              child: Transform.scale(
                scale: _currentScale,
                alignment: Alignment.center,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: _videoController.value.size.width,
                          height: _videoController.value.size.height,
                          child: Chewie(controller: _chewieController!),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _buildSubtitleDisplay(),
            if (_showCustomControls && !_isControlsLocked)
              Positioned(
                top: 60,
                left: 0,
                right: 0,
                child: _buildSubtitleControls(),
              ),
            // Brightness/Volume control gestures (only on sides of screen)
            if (!_isControlsLocked)
              Positioned.fill(
                child: Row(
                  children: [
                    // Left side - brightness control
                    Expanded(
                      flex: 2,
                      child: Listener(
                        onPointerDown: (details) => _isDragging = true,
                        onPointerUp: (details) => _isDragging = false,
                        onPointerMove: (details) {
                          if (_isDragging) {
                            _adjustBrightness(
                              -details.delta.dy /
                                  MediaQuery.of(context).size.height,
                            );
                          }
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                    // Middle - video content (no gestures)
                    Expanded(flex: 6, child: Container()),

                    // Right side - volume control
                    Expanded(
                      flex: 2,
                      child: Listener(
                        onPointerDown: (details) => _isDragging = true,
                        onPointerUp: (details) => _isDragging = false,
                        onPointerMove: (details) {
                          if (_isDragging) {
                            _adjustVolume(
                              -details.delta.dy /
                                  MediaQuery.of(context).size.height,
                            );
                          }
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ],
                ),
              ),

            // Custom overlay controls
            // _buildCustomOverlayControls(),

            // Lock button
            Positioned(
              bottom: 20,
              right: 20,
              child: GestureDetector(
                onTap: _toggleLock,
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: _isControlsLocked ? Colors.red : Colors.white54,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _isControlsLocked ? Icons.lock : Icons.lock_open,
                    color: _isControlsLocked ? Colors.red : Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),

            // Overlay for brightness/volume/zoom feedback
            if (_overlayText != null)
              Center(
                child: FadeTransition(
                  opacity: _overlayAnimation,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Text(
                      _overlayText!,
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCustomSeekBar() {
    final position = _videoController.value.position;
    final duration = _videoController.value.duration;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTapDown: (details) {
                final box = context.findRenderObject() as RenderBox;
                final x = details.localPosition.dx;
                final width = box.size.width;
                final newPosition = (x / width) * duration.inMilliseconds;
                _videoController.seekTo(
                  Duration(milliseconds: newPosition.round()),
                );
              },
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400]?.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width * progress,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Color(0xFFE50914),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Positioned(
                      left: MediaQuery.of(context).size.width * progress - 8,
                      top: -6,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Color(0xFFE50914),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showControlsTemporarily() {
    setState(() {
      _showCustomControls = true;
    });

    _controlsHideTimer?.cancel();
    _controlsHideTimer = Timer(Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showCustomControls = false;
        });
      }
    });
  }

  @override
  void dispose() {
    // Save final position before disposing
    if (_videoController.value.isInitialized) {
      _savePosition(_videoController.value.position);
    }

    _videoController.removeListener(_onPositionChanged);
    _videoController.dispose();
    _chewieController?.dispose();
    _fadeController.dispose();
    _loadingController.dispose();
    _overlayController.dispose();
    _overlayTimer?.cancel();
    _controlsHideTimer?.cancel();
    _subtitleTimer?.cancel();
    // Keep landscape mode (don't reset to portrait)
    // SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // Add this method to calculate optimal zoom scale
  double _calculateOptimalZoom() {
    if (!_videoController.value.isInitialized) return 1.0;

    final screenSize = MediaQuery.of(context).size;
    final videoSize = _videoController.value.size;

    if (videoSize.width == 0 || videoSize.height == 0) return 1.0;

    // Calculate scale factors for width and height
    final scaleX = screenSize.width / videoSize.width;
    final scaleY = screenSize.height / videoSize.height;

    // Use the smaller scale to ensure video fits completely
    final optimalScale = math.min(scaleX, scaleY);

    // Clamp between reasonable bounds
    return optimalScale.clamp(0.5, 4.0);
  }
}
