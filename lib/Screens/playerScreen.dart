import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soyo/models/subtitle_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:lottie/lottie.dart';

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
  bool _isLoading = true;
  String? _error;
  bool _showControls = true;
  Timer? _controlsTimer;
  bool _showEpisodeSelector = false;
  Timer? _autoNextTimer;
  int _autoNextCountdown = 10; // seconds
  bool _isAutoNextActive = false;
  bool _isControlsLocked = false;
  double _currentScale = 1.0; // Changed to 2.0x as requested
  Offset _focalPoint = Offset.zero;
  double _currentBrightness = 0.5;
  double _currentVolume = 0.5;
  bool _isDragging = false;
  String? _overlayText;
  Timer? _overlayTimer;
  double _previousScale = 1.0; // Changed to match initial scale

  // Subtitle-related fields
  List<SubtitleEntry> _subtitles = [];
  String? _currentSubtitle;
  bool _showSubtitles = true;
  int _selectedSubtitleIndex = 0;
  List<String> _availableSubtitles = [];
  Timer? _subtitleTimer;
  bool _isVerticalSwipe = false;
  double _initialPanY = 0.0;
  static const double _minSwipeDistance = 10.0;

  // Subtitle customization - loaded from SharedPreferences
  Color _subtitleBackgroundColor = Colors.black.withOpacity(0.7);
  Color _subtitleTextColor = Colors.yellow;
  double _subtitleFontSize = 16.0;
  String _subtitleFontFamily = 'Cinzel';
  bool _subtitleOutline = true;
  double _subtitleSpeed = 1.0;

  late AnimationController _overlayController;
  late Animation<double> _overlayAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Controls visibility tracking
  bool _controlsVisible = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _setLandscapeMode();
    _initBrightnessAndVolume();
    _loadSubtitleSettings();
    _loadSubtitles();
    _initializePlayer();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _overlayController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _overlayAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _overlayController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadSubtitleSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _subtitleBackgroundColor = Color(
        prefs.getInt('subtitle_bg_color') ??
            Colors.black.withOpacity(0.7).value,
      );
      _subtitleTextColor = Color(
        prefs.getInt('subtitle_text_color') ?? Colors.yellow.value,
      );
      _subtitleFontSize = prefs.getDouble('subtitle_font_size') ?? 16.0;
      _subtitleFontFamily = prefs.getString('subtitle_font_family') ?? 'Cinzel';
      _subtitleOutline = prefs.getBool('subtitle_outline') ?? true;
      _subtitleSpeed = prefs.getDouble('subtitle_speed') ?? 1.0;
    });
  }

  void _startAutoNextEpisode() {
    if (!widget.isTvShow || widget.onNextEpisode == null) return;

    setState(() {
      _isAutoNextActive = true;
      _autoNextCountdown = 10;
    });

    _autoNextTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _autoNextCountdown--;
      });

      if (_autoNextCountdown <= 0) {
        timer.cancel();
        setState(() {
          _isAutoNextActive = false;
        });
        widget.onNextEpisode!();
      }
    });
  }

  void _cancelAutoNext() {
    _autoNextTimer?.cancel();
    setState(() {
      _isAutoNextActive = false;
      _autoNextCountdown = 10;
    });
  }

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
                .replaceAll(RegExp(r'<[^>]*>'), '');

            subtitles.add(
              SubtitleEntry(startTime: startTime, endTime: endTime, text: text),
            );
          }
        } catch (e) {
          continue;
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
    _subtitleTimer = Timer.periodic(
      Duration(milliseconds: (100 / _subtitleSpeed).round()),
      (timer) {
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
      },
    );
  }

  void _setLandscapeMode() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    ); // Changed to immersiveSticky to prevent navigation bar interference
  }

  void _initBrightnessAndVolume() async {
    try {
      _currentBrightness = await ScreenBrightness().current;
    } catch (e) {
      _currentBrightness = 0.5;
    }
    _currentVolume = 0.7;
  }

  // 1. Update the _initializePlayer method to set showControls based on lock state
  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      if (widget.isLocalFile) {
        _videoController = VideoPlayerController.file(File(widget.streamUrl));
      } else {
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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _currentScale = _calculateOptimalZoom();
        });
      });

      await _loadSavedPosition();
      _videoController.addListener(_onPositionChanged);

      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        showControls:
            !_isControlsLocked, // Fixed: Hide Chewie controls when locked
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color.fromARGB(255, 189, 229, 9),
          handleColor: const Color.fromARGB(255, 9, 229, 27),
          backgroundColor: Colors.white.withOpacity(0.2),
          bufferedColor: Colors.white.withOpacity(0.4),
        ),
        placeholder: Container(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
          ),
        ),
        autoInitialize: true,
      );

      // Initialize controls to be visible
      _showControlsTemporarily();

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

  void _onChewieControlsChanged() {
    // This will track when Chewie controls are shown/hidden
    setState(() {
      _controlsVisible = _chewieController?.isFullScreen ?? true;
    });
  }

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

  void _onPositionChanged() {
    if (_videoController.value.isInitialized) {
      final position = _videoController.value.position;
      final duration = _videoController.value.duration;

      if (widget.onPositionChanged != null) {
        widget.onPositionChanged!(position);
      }
      if (position.inSeconds % 10 == 0) {
        _savePosition(position);
      }

      // Auto-next feature for TV shows
      if (widget.isTvShow &&
          widget.onNextEpisode != null &&
          duration.inSeconds > 0 &&
          !_isAutoNextActive) {
        final remainingSeconds = duration.inSeconds - position.inSeconds;
        if (remainingSeconds <= 30 && remainingSeconds > 0) {
          _startAutoNextEpisode();
        }
      }
    }
  }

  Widget _buildEpisodeSelector() {
    if (!widget.isTvShow || !_showEpisodeSelector) return SizedBox.shrink();

    return Positioned(
      top: MediaQuery.of(context).padding.top + 70,
      left: 16,
      right: 16,
      child: AnimatedOpacity(
        opacity: _showEpisodeSelector ? 1.0 : 0.0,
        duration: Duration(milliseconds: 300),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Episode Navigation',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _showEpisodeSelector = false),
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              if (widget.currentEpisode != null && widget.totalEpisodes != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Color(0xFF6366F1).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tv_rounded,
                        color: Color(0xFF6366F1),
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Episode ${widget.currentEpisode} of ${widget.totalEpisodes}',
                        style: GoogleFonts.inter(
                          color: Color(0xFF6366F1),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 16),
              Row(
                children: [
                  if (widget.onPreviousEpisode != null)
                    Expanded(
                      child: Container(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: widget.onPreviousEpisode,
                          icon: Icon(Icons.skip_previous_rounded, size: 20),
                          label: Text(
                            'Previous',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[800],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                  if (widget.onPreviousEpisode != null &&
                      widget.onNextEpisode != null)
                    SizedBox(width: 12),
                  if (widget.onNextEpisode != null)
                    Expanded(
                      child: Container(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: widget.onNextEpisode,
                          icon: Icon(Icons.skip_next_rounded, size: 20),
                          label: Text(
                            'Next',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
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
    );
  }

  Widget _buildAutoNextOverlay() {
    if (!_isAutoNextActive) return SizedBox.shrink();

    return Positioned(
      bottom: 120,
      right: 16,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Color(0xFF6366F1).withOpacity(0.5),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Next Episode in',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(0xFF6366F1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _autoNextCountdown.toString(),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
            GestureDetector(
              onTap: _cancelAutoNext,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.5)),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleBrightnessPanStart(DragStartDetails details) {
    if (_isControlsLocked) return;
    _initialPanY = details.localPosition.dy;
    _isVerticalSwipe = false;
  }

  void _handleBrightnessPanUpdate(DragUpdateDetails details) {
    if (_isControlsLocked) return;

    final deltaY = details.delta.dy;
    final deltaX = details.delta.dx;
    final totalDeltaY = (details.localPosition.dy - _initialPanY).abs();

    if (!_isVerticalSwipe && totalDeltaY > _minSwipeDistance) {
      if (deltaY.abs() > deltaX.abs() * 2) {
        _isVerticalSwipe = true;
        setState(() {
          _isDragging = true;
        });
      }
    }

    if (_isVerticalSwipe && _isDragging) {
      _adjustBrightness(-deltaY / MediaQuery.of(context).size.height);
    }
  }

  void _handleBrightnessPanEnd(DragEndDetails details) {
    if (_isVerticalSwipe && _isDragging) {
      setState(() {
        _isDragging = false;
      });
      _hideOverlay();
    }
    _isVerticalSwipe = false;
  }

  void _handleVolumePanStart(DragStartDetails details) {
    if (_isControlsLocked) return;
    _initialPanY = details.localPosition.dy;
    _isVerticalSwipe = false;
  }

  void _handleVolumePanUpdate(DragUpdateDetails details) {
    if (_isControlsLocked) return;

    final deltaY = details.delta.dy;
    final deltaX = details.delta.dx;
    final totalDeltaY = (details.localPosition.dy - _initialPanY).abs();

    if (!_isVerticalSwipe && totalDeltaY > _minSwipeDistance) {
      if (deltaY.abs() > deltaX.abs() * 2) {
        _isVerticalSwipe = true;
        setState(() {
          _isDragging = true;
        });
      }
    }

    if (_isVerticalSwipe && _isDragging) {
      _adjustVolume(-deltaY / MediaQuery.of(context).size.height);
    }
  }

  void _handleVolumePanEnd(DragEndDetails details) {
    if (_isVerticalSwipe && _isDragging) {
      setState(() {
        _isDragging = false;
      });
      _hideOverlay();
    }
    _isVerticalSwipe = false;
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

  void _handleScaleStart(ScaleStartDetails details) {
    if (_isControlsLocked) return;
    _focalPoint = details.focalPoint;
    _previousScale = _currentScale;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_isControlsLocked) return;
    double newScale = _previousScale * details.scale;
    newScale = newScale.clamp(0.5, 4.0);
    setState(() {
      _currentScale = newScale;
    });
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    if (_currentScale > 2.5) {
      setState(() {
        _currentScale = 4.0;
      });
    } else if (_currentScale > 1.5) {
      setState(() {
        _currentScale = 2.0;
      });
    } else if (_currentScale < 0.75) {
      setState(() {
        _currentScale = 0.5;
      });
    } else if (_currentScale < 1.25) {
      setState(() {
        _currentScale = 1.0;
      });
    }
    _showOverlay('Zoom: ${_currentScale.toStringAsFixed(1)}x');
  }

  // Update the _toggleLock method
  void _toggleLock() {
    setState(() {
      _isControlsLocked = !_isControlsLocked;
    });

    // Update Chewie controller to show/hide controls based on lock state
    if (_chewieController != null) {
      _chewieController!.dispose();
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        showControls:
            !_isControlsLocked, // Fixed: Hide Chewie controls when locked
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color.fromARGB(255, 181, 229, 9),
          handleColor: const Color.fromARGB(255, 170, 229, 9),
          backgroundColor: Colors.white.withOpacity(0.2),
          bufferedColor: Colors.white.withOpacity(0.4),
        ),
        placeholder: Container(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
          ),
        ),
        autoInitialize: true,
      );
    }

    // Show overlay with proper text
    final lockText = _isControlsLocked
        ? '🔒 Controls Locked'
        : '🔓 Controls Unlocked';
    _showOverlay(lockText);

    // If unlocking, show controls temporarily
    if (!_isControlsLocked) {
      _showControlsTemporarily();
    }
  }

  // Add this new method to handle controls visibility
  void _showControlsTemporarily() {
    setState(() {
      _showControls = true;
    });

    _controlsTimer?.cancel();
    _controlsTimer = Timer(Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  Widget _buildSubtitleDisplay() {
    if (!_showSubtitles ||
        _currentSubtitle == null ||
        _currentSubtitle!.isEmpty) {
      return SizedBox.shrink();
    }

    return Positioned(
      bottom: 100,
      left: 16,
      right: 16,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: _subtitleBackgroundColor != Colors.transparent
            ? BoxDecoration(
                color: _subtitleBackgroundColor,
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Text(
          _currentSubtitle!,
          textAlign: TextAlign.center,
          style: GoogleFonts.getFont(
            _subtitleFontFamily,
            color: _subtitleTextColor,
            fontSize: _subtitleFontSize,
            fontWeight: FontWeight.w500,
            height: 1.4,
            shadows: _subtitleOutline
                ? [
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 2,
                      color: Colors.black,
                    ),
                    Shadow(
                      offset: Offset(-1, -1),
                      blurRadius: 2,
                      color: Colors.black,
                    ),
                    Shadow(
                      offset: Offset(1, -1),
                      blurRadius: 2,
                      color: Colors.black,
                    ),
                    Shadow(
                      offset: Offset(-1, 1),
                      blurRadius: 2,
                      color: Colors.black,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return AnimatedOpacity(
      opacity: _controlsVisible ? 1.0 : 0.0,
      duration: Duration(milliseconds: 300),
      child: Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () {
                    _resetToPortraitMode();
                    Navigator.of(context).pop();
                  },
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
            if (widget.isTvShow) ...[
              SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => setState(
                      () => _showEpisodeSelector = !_showEpisodeSelector,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.playlist_play_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitleControls() {
    if (_availableSubtitles.isEmpty) return SizedBox.shrink();

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: AnimatedOpacity(
        opacity: (_showControls || !_isControlsLocked)
            ? 1.0
            : 0.3, // Changed from 0.0 to 0.3
        duration: Duration(milliseconds: 300),
        child: IgnorePointer(
          ignoring: false, // Always allow interaction
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: DropdownButton<int>(
                  value: _selectedSubtitleIndex,
                  dropdownColor: Color(0xFF1F1F1F),
                  underline: SizedBox.shrink(),
                  iconEnabledColor: Colors.white,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
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
                        await _loadSubtitleTrack(
                          widget.subtitleUrls![value - 1],
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockButton() {
    return Positioned(
      bottom: 24,
      right: 24,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color:
              _isControlsLocked // Fixed: Show red when locked
              ? Color(0xFFEF4444).withOpacity(0.9)
              : Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color:
                _isControlsLocked // Fixed: Show red border when locked
                ? Color(0xFFEF4444).withOpacity(0.3)
                : Colors.white.withOpacity(0.2),
            width: 2,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: _toggleLock,
            child: Center(
              child: Icon(
                _isControlsLocked // Fixed: Show locked icon when locked
                    ? Icons.lock_rounded
                    : Icons.lock_open_rounded,
                color: Colors.white,
                size: 20,
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
          Expanded(
            flex: 3,
            child: GestureDetector(
              onPanStart: _handleBrightnessPanStart,
              onPanUpdate: _handleBrightnessPanUpdate,
              onPanEnd: _handleBrightnessPanEnd,
              child: Container(color: Colors.transparent),
            ),
          ),
          Expanded(flex: 4, child: Container()),
          Expanded(
            flex: 3,
            child: GestureDetector(
              onPanStart: _handleVolumePanStart,
              onPanUpdate: _handleVolumePanUpdate,
              onPanEnd: _handleVolumePanEnd,
              child: Container(color: Colors.transparent),
            ),
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          _buildBody(),
          if (_overlayText != null) _buildControlsOverlay(),
        ],
      ),
    );
  }

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
          _buildVideoPlayer(),
          _buildBackButton(),
          _buildSubtitleControls(),
          _buildSubtitleDisplay(),
          _buildEpisodeSelector(), // Add this line
          _buildGestureControls(),
          _buildLockButton(),
          _buildAutoNextOverlay(),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildVideoPlayer() {
    return GestureDetector(
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
            child: Chewie(controller: _chewieController!),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      color: const Color(0xFF000000),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 150,
              height: 150,
              child: Lottie.asset(
                'assets/animations/loading.json', // Add your Lottie file here
                width: 150,
                height: 150,
                fit: BoxFit.contain,
                repeat: true,
                animate: true,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to CircularProgressIndicator if Lottie fails
                  return CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF6366F1),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Buffering...',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Container(
      color: const Color(0xFF000000),
      padding: const EdgeInsets.all(24),
      child: Center(
        // Fixed: Properly centered now
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFEF4444),
              size: 64,
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
            ElevatedButton.icon(
              onPressed: () {
                _videoController.dispose();
                _chewieController?.dispose();
                _initializePlayer();
              },
              icon: Icon(Icons.refresh_rounded),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateOptimalZoom() {
    if (!_videoController.value.isInitialized)
      return 2.0; // Changed default to 2.0

    final screenSize = MediaQuery.of(context).size;
    final videoSize = _videoController.value.size;

    if (videoSize.width == 0 || videoSize.height == 0) return 2.0;

    final scaleX = screenSize.width / videoSize.width;
    final scaleY = screenSize.height / videoSize.height;
    final optimalScale =
        math.min(scaleX, scaleY) * 2.0; // Start at 2x the optimal

    return optimalScale.clamp(0.5, 4.0);
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
    if (_videoController.value.isInitialized) {
      _savePosition(_videoController.value.position);
    }

    _videoController.removeListener(_onPositionChanged);
    _videoController.dispose();
    _chewieController?.dispose();
    _fadeController.dispose();
    _overlayController.dispose();
    _overlayTimer?.cancel();
    _subtitleTimer?.cancel();
    _controlsTimer?.cancel();
    _autoNextTimer?.cancel(); // Add this line

    _resetToPortraitMode();
    super.dispose();
  }
}
