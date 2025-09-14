import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:pod_player/pod_player.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soyo/models/subtitle_model.dart';
import 'package:url_launcher/url_launcher.dart';

class SimpleStreamPlayer extends StatefulWidget {
  final String streamUrl;
  final String movieTitle;
  final Duration? startPosition;
  final Function(Duration)? onPositionChanged;
  final List<String>? subtitleUrls;
  final bool isLocalFile;
  final bool isTvShow;
  final int? currentEpisode;
  final int? totalEpisodes;
  final Function()? onNextEpisode;
  final Function()? onPreviousEpisode;

  const SimpleStreamPlayer({
    Key? key,
    required this.streamUrl,
    required this.movieTitle,
    this.startPosition,
    this.onPositionChanged,
    this.subtitleUrls,
    this.isLocalFile = false,
    this.isTvShow = false,
    this.currentEpisode,
    this.totalEpisodes,
    this.onNextEpisode,
    this.onPreviousEpisode,
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
  // bool _isFullscreen = false;
  // bool _showControls = true;
  bool _isControlsLocked = false;
  double _currentScale = 2.0;
  Offset _focalPoint = Offset.zero;
  double _currentBrightness = 0.5;
  double _currentVolume = 0.5;
  bool _isDragging = false;
  String? _overlayText;
  Timer? _overlayTimer;
  double _previousScale = 1.0;
  // Subtitle-related fields
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

      // Choose the appropriate controller based on file type
      if (widget.isLocalFile) {
        // For local files
        _videoController = VideoPlayerController.file(File(widget.streamUrl));
      } else {
        // For network streams
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
      }

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
    return Row(
      children: [
        // Subtitle selector
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: DropdownButton<int>(
            value: _selectedSubtitleIndex,
            dropdownColor: Color(0xFF1F1F1F),
            underline: SizedBox.shrink(),
            iconEnabledColor: Colors.white,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
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
                  setState(() {
                    _showSubtitles = false;
                    _subtitles.clear();
                  });
                  _subtitleTimer?.cancel();
                } else {
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
        // Subtitle toggle button
        _buildControlButton(
          icon: Icons.subtitles_rounded,
          onTap: () {
            setState(() {
              _showSubtitles = !_showSubtitles;
            });
          },
          isActive: _showSubtitles,
        ),
      ],
    );
  }

  Widget _buildTopControls() {
    return Container(
      padding: EdgeInsets.only(
        top: widget.isTvShow ? 80 : MediaQuery.of(context).padding.top + 80,
        left: 20,
        right: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and external player button
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.movieTitle,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.isTvShow && widget.currentEpisode != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Episode ${widget.currentEpisode}',
                          style: GoogleFonts.inter(
                            color: Color(0xFF6366F1),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _buildControlButton(
                icon: Icons.open_in_new_rounded,
                onTap: _showExternalPlayerDialog,
              ),
            ],
          ),
          // Subtitle controls
          if (_availableSubtitles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: _buildSubtitleControls(),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomOverlayControls() {
    if (!_showCustomControls || _isControlsLocked) return SizedBox.shrink();

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
            stops: [0.0, 0.25, 0.75, 1.0],
          ),
        ),
        child: Column(
          children: [
            // Top section with title and subtitle controls
            _buildTopControls(),
            Spacer(),
            // Bottom section with playback controls
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitleDisplay() {
    if (!_showSubtitles ||
        _currentSubtitle == null ||
        _currentSubtitle!.isEmpty) {
      return SizedBox.shrink();
    }

    return Positioned(
      bottom: 120,
      left: 24,
      right: 24,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Text(
          _currentSubtitle!,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.4,
            shadows: [
              Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodeButton({
    required IconData icon,
    VoidCallback? onTap,
    required bool enabled,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: enabled
            ? Color(0xFF6366F1).withOpacity(0.9)
            : Colors.grey[800]?.withOpacity(0.6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: enabled
              ? Color(0xFF6366F1).withOpacity(0.3)
              : Colors.grey[700]!.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: enabled ? onTap : null,
          child: Center(
            child: Icon(
              icon,
              color: enabled ? Colors.white : Colors.grey[500],
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodeNavigation() {
    if (!widget.isTvShow ||
        widget.currentEpisode == null ||
        widget.totalEpisodes == null) {
      return SizedBox.shrink();
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      left: 80,
      right: 20,
      child: Row(
        children: [
          // Episode info
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tv_rounded, color: Color(0xFF6366F1), size: 18),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'EP ${widget.currentEpisode}/${widget.totalEpisodes}',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 12),
          // Previous episode button
          _buildEpisodeButton(
            icon: Icons.skip_previous_rounded,
            onTap: widget.onPreviousEpisode,
            enabled: widget.currentEpisode! > 1,
          ),
          SizedBox(width: 8),
          // Next episode button
          _buildEpisodeButton(
            icon: Icons.skip_next_rounded,
            onTap: widget.onNextEpisode,
            enabled: widget.currentEpisode! < widget.totalEpisodes!,
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      left: 20,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => Navigator.of(context).pop(),
            child: Center(
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
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
    if (widget.isLocalFile) {
      _showError('External players not supported for local files');
      return;
    }
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          // Add scrolling for overflow protection
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            // Constrain maximum width
            constraints: const BoxConstraints(maxWidth: 400),
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
                      child: const Icon(
                        Icons.open_in_new_rounded,
                        color: Color(0xFFE50914),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      // Prevent text overflow
                      child: Text(
                        'Open with External Player',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2, // Allow text to wrap
                        overflow: TextOverflow.ellipsis,
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
                        maxLines: 3, // Limit URL text lines
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
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
                    maxLines: 1, // Prevent text overflow
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.nunito(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                    maxLines: 1, // Prevent text overflow
                    overflow: TextOverflow.ellipsis,
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
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          // Main video content
          _buildBody(),

          // Overlay for brightness/volume feedback
          if (_overlayText != null) _buildControlsOverlay(),
        ],
      ),
    );
  }

  // Updated _buildBody method to integrate back button and custom controls
  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_error != null) {
      return _buildErrorScreen();
    }

    if (_chewieController != null) {
      return Stack(
        children: [
          // Video player with gestures
          _buildVideoPlayer(),
          // Back button
          _buildBackButton(),
          // Episode navigation (TV Shows only)
          if (widget.isTvShow) _buildEpisodeNavigation(),
          // Subtitle display
          _buildSubtitleDisplay(),
          // Custom overlay controls
          _buildCustomOverlayControls(),
          // Brightness/Volume gesture areas
          _buildGestureControls(),
          // Lock button
          _buildLockButton(),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildControlsOverlay() {
    return Center(
      child: FadeTransition(
        opacity: _overlayAnimation,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                spreadRadius: 0,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            _overlayText!,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // Helper methods for gesture handling
  void _handleBrightnessPanStart(DragStartDetails details) {
    if (_isControlsLocked) return;
    setState(() {
      _isDragging = true;
    });
  }

  void _handleBrightnessPanUpdate(DragUpdateDetails details) {
    if (_isControlsLocked || !_isDragging) return;
    final deltaY = details.delta.dy;
    _adjustBrightness(-deltaY / MediaQuery.of(context).size.height);
  }

  void _handleBrightnessPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
    _hideOverlay();
  }

  void _handleVolumePanStart(DragStartDetails details) {
    if (_isControlsLocked) return;
    setState(() {
      _isDragging = true;
    });
  }

  void _handleVolumePanUpdate(DragUpdateDetails details) {
    if (_isControlsLocked || !_isDragging) return;
    final deltaY = details.delta.dy;
    _adjustVolume(-deltaY / MediaQuery.of(context).size.height);
  }

  void _handleVolumePanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
    _hideOverlay();
  }

  Widget _buildLockButton() {
    return Positioned(
      bottom: 24,
      right: 24,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: _isControlsLocked
              ? Color(0xFFEF4444).withOpacity(0.9)
              : Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: _isControlsLocked
                ? Color(0xFFEF4444).withOpacity(0.3)
                : Colors.white.withOpacity(0.2),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (_isControlsLocked ? Color(0xFFEF4444) : Colors.black)
                  .withOpacity(0.3),
              spreadRadius: 0,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: _toggleLock,
            child: Center(
              child: Icon(
                _isControlsLocked
                    ? Icons.lock_rounded
                    : Icons.lock_open_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGestureControls() {
    if (_isControlsLocked) return SizedBox.shrink();

    return Positioned.fill(
      child: Row(
        children: [
          // Left side - brightness control
          Expanded(
            flex: 3,
            child: GestureDetector(
              onPanStart: _handleBrightnessPanStart,
              onPanUpdate: _handleBrightnessPanUpdate,
              onPanEnd: _handleBrightnessPanEnd,
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: _isDragging && _overlayText?.contains('🔆') == true
                      ? _buildGestureIndicator('🔆', _overlayText!)
                      : null,
                ),
              ),
            ),
          ),
          // Middle - video content (no gestures)
          Expanded(flex: 4, child: Container()),
          // Right side - volume control
          Expanded(
            flex: 3,
            child: GestureDetector(
              onPanStart: _handleVolumePanStart,
              onPanUpdate: _handleVolumePanUpdate,
              onPanEnd: _handleVolumePanEnd,
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: _isDragging && _overlayText?.contains('🔊') == true
                      ? _buildGestureIndicator('🔊', _overlayText!)
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGestureIndicator(String icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: TextStyle(fontSize: 32)),
          SizedBox(height: 8),
          Text(
            text.replaceAll(icon, '').trim(),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          // Playback controls
          Row(
            children: [
              // Play/Pause button
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF6366F1).withOpacity(0.3),
                      spreadRadius: 0,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: () {
                      setState(() {
                        if (_videoController.value.isPlaying) {
                          _videoController.pause();
                          _isPlaying = false;
                        } else {
                          _videoController.play();
                          _isPlaying = true;
                        }
                      });
                    },
                    child: Center(
                      child: Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 20),
              // Time display
              Text(
                _formatDuration(_videoController.value.position),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Spacer(),
              Text(
                _formatDuration(_videoController.value.duration),
                style: GoogleFonts.inter(
                  color: Colors.grey[400],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          // Enhanced seek bar
          _buildCustomSeekBar(),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isActive
            ? Color(0xFF6366F1).withOpacity(0.9)
            : Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isActive
              ? Color(0xFF6366F1).withOpacity(0.3)
              : Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Center(child: Icon(icon, color: Colors.white, size: 20)),
        ),
      ),
    );
  }

  // Add duration formatter method
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Updated _buildCustomSeekBar method with proper tap handling
  Widget _buildCustomSeekBar() {
    if (!_videoController.value.isInitialized) {
      return Container(
        height: 4,
        margin: EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[600],
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }

    final position = _videoController.value.position;
    final duration = _videoController.value.duration;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      height: 20, // Increased height for better touch target
      child: GestureDetector(
        onTapDown: (details) {
          if (!_videoController.value.isInitialized) return;

          final RenderBox box = context.findRenderObject() as RenderBox;
          final localPosition = details.localPosition;
          final width = box.size.width - 32; // Account for horizontal margin
          final tapX = localPosition.dx - 16; // Account for left margin

          if (tapX >= 0 && tapX <= width) {
            final percentage = (tapX / width).clamp(0.0, 1.0);
            final newPosition = Duration(
              milliseconds: (duration.inMilliseconds * percentage).round(),
            );

            _videoController.seekTo(newPosition);

            // Show seek feedback
            final minutes = newPosition.inMinutes;
            final seconds = newPosition.inSeconds % 60;
            _showOverlay(
              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            );
          }
        },
        child: Container(
          height: 4,
          margin: EdgeInsets.symmetric(
            vertical: 8,
          ), // Center the seek bar vertically
          decoration: BoxDecoration(
            color: Colors.grey[600],
            borderRadius: BorderRadius.circular(2),
          ),
          child: Stack(
            children: [
              // Background track
              Container(
                width: double.infinity,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400]?.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Buffered progress (if available)
              if (_videoController.value.buffered.isNotEmpty)
                Container(
                  width:
                      MediaQuery.of(context).size.width *
                      (_videoController.value.buffered.last.end.inMilliseconds /
                              duration.inMilliseconds)
                          .clamp(0.0, 1.0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400]?.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              // Progress track
              Container(
                width:
                    (MediaQuery.of(context).size.width - 32) *
                    progress.clamp(0.0, 1.0),
                height: 4,
                decoration: BoxDecoration(
                  color: Color(0xFFE50914),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Seek handle
              Positioned(
                left:
                    ((MediaQuery.of(context).size.width - 32) *
                        progress.clamp(0.0, 1.0)) -
                    8,
                top: -6,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Color(0xFFE50914),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showControlsTemporarily() {
    setState(() {
      _showCustomControls = true;
    });

    _controlsHideTimer?.cancel();
    _controlsHideTimer = Timer(Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showCustomControls = false;
        });
      }
    });
  }

  Widget _buildVideoPlayer() {
    return GestureDetector(
      onTap: () {
        if (!_isControlsLocked) {
          _showControlsTemporarily();
        }
      },
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
    );
  }

  Widget _buildErrorScreen() {
    return Container(
      color: const Color(0xFF000000),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFEF4444).withOpacity(0.1),
              border: Border.all(
                color: Color(0xFFEF4444).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFEF4444),
              size: 48,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Playback Error',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[900]?.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[800]!, width: 1),
            ),
            child: Text(
              _error!,
              style: GoogleFonts.inter(
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
                child: _buildActionButton(
                  onPressed: () {
                    _videoController.dispose();
                    _chewieController?.dispose();
                    _initializePlayer();
                  },
                  icon: Icons.refresh_rounded,
                  label: 'Retry',
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionButton(
                  onPressed: _showExternalPlayerDialog,
                  icon: Icons.open_in_new_rounded,
                  label: 'External',
                  isPrimary: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      color: const Color(0xFF000000),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated loading circle
          Container(
            width: 100,
            height: 100,
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF6366F1).withOpacity(0.3),
                        Color(0xFF8B5CF6).withOpacity(0.3),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF6366F1),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Loading Video',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.movieTitle,
            style: GoogleFonts.inter(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.isTvShow && widget.currentEpisode != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Episode ${widget.currentEpisode}',
                style: GoogleFonts.inter(
                  color: Color(0xFF6366F1),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required bool isPrimary,
  }) {
    return Container(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? Color(0xFF6366F1) : Colors.grey[800],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  void _resetToPortraitMode() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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

    // Reset to portrait mode when exiting
    _resetToPortraitMode();

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
