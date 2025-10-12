import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soyo/Screens/playerScreen.dart';
import 'package:soyo/Services/javScrapper.dart';
import 'package:soyo/models/javData.dart';

class JAVDetailScreen extends StatefulWidget {
  final JAVVideo video;

  const JAVDetailScreen({Key? key, required this.video}) : super(key: key);

  @override
  _JAVDetailScreenState createState() => _JAVDetailScreenState();
}

class _JAVDetailScreenState extends State<JAVDetailScreen>
    with TickerProviderStateMixin {
  final JAVScraper _scraper = JAVScraper();
  bool _isFetchingStream = false;
  String? _m3u8Url;
  String? _errorMessage;
  String _currentStatus = '';

  Duration? _lastWatchedPosition;
  bool _hasWatchProgress = false;
  bool autoPlay = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideAnimationController;
  late Animation<Offset> _slideAnimation;
  late AnimationController _scaleAnimationController;
  late Animation<double> _scaleAnimation;
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _slideAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleAnimationController,
        curve: Curves.easeOutBack,
      ),
    );

    _animationController.forward();
    _slideAnimationController.forward();
    _scaleAnimationController.forward();

    _loadWatchProgress();
    _loadAutoPlaySetting();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _slideAnimationController.dispose();
    _scaleAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadAutoPlaySetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      autoPlay = prefs.getBool('auto_play') ?? true;
    });
  }

  Future<void> _loadWatchProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final positionMs = prefs.getInt('jav_${widget.video.id}_position');
    if (positionMs != null && positionMs > 0) {
      setState(() {
        _lastWatchedPosition = Duration(milliseconds: positionMs);
        _hasWatchProgress = true;
      });
    }
  }

  Future<void> _saveWatchProgress(Duration position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'jav_${widget.video.id}_position',
      position.inMilliseconds,
    );
  }

  void _fetchStream() async {
    setState(() {
      _isFetchingStream = true;
      _errorMessage = null;
      _currentStatus = 'Initializing...';
    });

    try {
      final streamResponse = await _scraper.getVideoStream(
        widget.video.pageUrl,
        onStatusUpdate: (status) {
          if (mounted) {
            setState(() {
              _currentStatus = _formatStatus(status);
            });
          }
        },
      );

      if (streamResponse.success && streamResponse.m3u8Url != null) {
        setState(() {
          _m3u8Url = streamResponse.m3u8Url;
          _isFetchingStream = false;
          _currentStatus = 'Stream ready!';
        });

        // Auto-play if enabled
        if (autoPlay) {
          _playVideo();
        }
      } else {
        setState(() {
          _errorMessage = streamResponse.message;
          _isFetchingStream = false;
        });
        _showErrorSnackBar(streamResponse.message);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to fetch stream: $e';
        _isFetchingStream = false;
      });
      _showErrorSnackBar('Failed to fetch stream: $e');
    }
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'stream_ready':
        return 'Stream found!';
      case 'completed':
        return 'Ready to play';
      case 'error':
        return 'Error occurred';
      default:
        return status.replaceAll('_', ' ').replaceAll('...', '…');
    }
  }

  void _playVideo() async {
    if (_m3u8Url == null) {
      _showErrorSnackBar('No stream URL available');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final resumeFromLastPosition =
        prefs.getBool('resume_from_last_position') ?? false;

    // _m3u8Url is already proxied from JAVScraper
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SimpleStreamPlayer(
          streamUrl: _m3u8Url!, // Already proxied
          movieTitle: '${widget.video.code} - ${widget.video.title}',
          startPosition: _lastWatchedPosition,
          onPositionChanged: _saveWatchProgress,
          autoPlay: autoPlay,
          resumeFromLastPosition: resumeFromLastPosition,
          isTvShow: false,
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.nunito(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildVideoDetails(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF0A0A0A),
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: widget.video.posterUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[900],
                child: Center(
                  child: CircularProgressIndicator(
                    color: const Color.fromARGB(255, 73, 54, 244),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[900],
                child: Icon(Icons.error, color: Colors.red),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    const Color(0xFF0A0A0A).withOpacity(0.7),
                    const Color(0xFF0A0A0A),
                  ],
                  stops: const [0.0, 0.5, 0.8, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoDetails() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitleSection(),
          const SizedBox(height: 20),
          _buildMetaInfo(),
          const SizedBox(height: 24),
          _buildPlayButton(),
          const SizedBox(height: 32),
          _buildDescriptionSection(),
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color.fromARGB(255, 73, 54, 244).withOpacity(0.1),
                    Colors.purple.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color.fromARGB(
                    255,
                    73,
                    54,
                    244,
                  ).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 73, 54, 244),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.video.code,
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.video.title,
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaInfo() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (widget.video.duration.isNotEmpty)
          _buildMetaChip(
            icon: Icons.schedule_rounded,
            text: widget.video.duration,
            color: Colors.blue,
          ),
        if (widget.video.uploadDate.isNotEmpty)
          _buildMetaChip(
            icon: Icons.calendar_today_rounded,
            text: widget.video.uploadDate,
            color: Colors.green,
          ),
        _buildMetaChip(
          icon: Icons.hd_rounded,
          text: 'HD',
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: color.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayButton() {
    return SlideTransition(
      position: _slideAnimation,
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 500),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: _m3u8Url != null
                          ? [const Color(0xFF059200), const Color(0xFF07B600)]
                          : _hasWatchProgress
                          ? [const Color(0xFF059200), const Color(0xFF07B600)]
                          : [
                              const Color.fromARGB(255, 73, 54, 244),
                              const Color.fromARGB(255, 100, 85, 255),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (_m3u8Url != null
                                    ? const Color(0xFF059200)
                                    : const Color.fromARGB(255, 73, 54, 244))
                                .withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isFetchingStream
                        ? null
                        : _m3u8Url != null
                        ? _playVideo
                        : _fetchStream,
                    icon: _isFetchingStream
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Icon(
                            _m3u8Url != null
                                ? Icons.play_circle_filled
                                : _hasWatchProgress
                                ? Icons.play_circle_filled
                                : Icons.play_arrow_rounded,
                            size: 28,
                          ),
                    label: Text(
                      _isFetchingStream
                          ? _currentStatus
                          : _m3u8Url != null
                          ? 'Play Video'
                          : _hasWatchProgress
                          ? 'Continue Watching'
                          : 'Get Stream',
                      style: GoogleFonts.nunito(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                    ),
                  ),
                ),
              );
            },
          ),
          if (_isFetchingStream && _currentStatus.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _currentStatus,
              style: GoogleFonts.nunito(
                color: Colors.grey[400],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return SlideTransition(
      position: _slideAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color.fromARGB(255, 73, 54, 244),
                      Colors.purple,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Video Information',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.grey[900]!.withOpacity(0.6),
                  Colors.grey[900]!.withOpacity(0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.grey[800]!.withOpacity(0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Code', widget.video.code),
                const SizedBox(height: 12),
                _buildInfoRow('Duration', widget.video.duration),
                const SizedBox(height: 12),
                _buildInfoRow('Upload Date', widget.video.uploadDate),
                const SizedBox(height: 16),
                Text(
                  widget.video.title,
                  style: GoogleFonts.nunito(
                    color: Colors.grey[300],
                    fontSize: 15,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: GoogleFonts.nunito(
              color: Colors.grey[500],
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
