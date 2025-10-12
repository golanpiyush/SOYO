import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soyo/Services/downloadManager.dart';
import 'package:soyo/Services/exploreapi.dart';
import 'package:soyo/Services/m3u8api.dart';
import 'package:soyo/Screens/playerScreen.dart';
import 'package:soyo/Services/streams_cacher.dart';
import 'package:soyo/models/moviemodel.dart';
import 'package:soyo/models/savedmoviesmodel.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class MovieDetailScreen extends StatefulWidget {
  final Movie movie;

  const MovieDetailScreen({Key? key, required this.movie}) : super(key: key);

  @override
  _MovieDetailScreenState createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen>
    with TickerProviderStateMixin {
  final M3U8Api _api = M3U8Api();
  bool _isFetching = false;
  Map<String, dynamic>? _streamResult;
  Duration? _lastWatchedPosition;
  bool _hasWatchProgress = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Map<String, dynamic>? _movieDetails;
  bool _isLoadingDetails = false;
  bool autoPlay = true; // Add this line

  bool _isUsingCache = false;

  bool _isSaved = false;
  late AnimationController _saveAnimationController;
  late Animation<double> _saveAnimation;
  final YoutubeExplode _yt = YoutubeExplode();

  // Trailer-related variables
  late VideoPlayerController _trailerController;
  bool _isTrailerPlaying = false;
  bool _isTrailerMuted = true;
  bool _showTrailerControls = false;
  bool _hasTrailer = false;
  String? _trailerUrl;
  Timer? _trailerTimer;
  bool _isTrailerBuffered = false;
  double _bufferedPercentage = 0.0;

  final DownloadManager _downloadManager = DownloadManager();
  bool _isDownloading = false;
  bool _isDownloaded = false;
  String? _downloadId;

  late AnimationController _slideAnimationController;
  late Animation<Offset> _slideAnimation;
  late AnimationController _scaleAnimationController;
  late Animation<double> _scaleAnimation;
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;
  late AnimationController _shimmerAnimationController;
  late Animation<double> _shimmerAnimation;

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

    // Shimmer animation for cards
    _shimmerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _shimmerAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    // Existing animation controller...
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // ADD THESE NEW ANIMATION CONTROLLERS
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

    // Rest of your existing initState code...
    _saveAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _loadWatchProgress();
    _loadMovieDetails();
    _loadAutoPlaySetting();
    _checkDownloadStatus();

    _saveAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _saveAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _saveAnimationController,
        curve: Curves.elasticOut,
      ),
    );
    _checkIfSaved();
    // Initialize trailer controller with a dummy URL
    _trailerController = VideoPlayerController.network(
      'https://example.com/dummy.mp4',
    );
    StreamCacheService.clearExpiredCache();
  }

  Future<void> _loadAutoPlaySetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      autoPlay = prefs.getBool('auto_play') ?? true;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _slideAnimationController.dispose(); // ADD THIS
    _scaleAnimationController.dispose(); // ADD THIS
    _trailerController.dispose();
    _trailerTimer?.cancel();
    _saveAnimationController.dispose();
    _yt.close();
    super.dispose();
  }

  // Add this method to check download status
  void _checkDownloadStatus() {
    final downloadItem = _downloadManager.getDownloadForMovie(
      widget.movie.title,
    );
    if (downloadItem != null) {
      setState(() {
        _downloadId = downloadItem.id;
        _isDownloaded = downloadItem.status == DownloadStatus.completed;
        _isDownloading =
            downloadItem.status == DownloadStatus.downloading ||
            downloadItem.status == DownloadStatus.pending;
      });
    }
  }

  Future<void> _checkIfSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMoviesJson = prefs.getStringList('saved_movies') ?? [];

      final isAlreadySaved = savedMoviesJson.any((json) {
        final movie = jsonDecode(json);
        return movie['id'] == widget.movie.id.toString();
      });

      setState(() {
        _isSaved = isAlreadySaved;
      });
    } catch (e) {
      print('Error checking saved status: $e');
    }
  }

  Future<void> _toggleSaveMovie() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMoviesJson = prefs.getStringList('saved_movies') ?? [];

      if (_isSaved) {
        // Remove from saved
        savedMoviesJson.removeWhere((json) {
          final movie = jsonDecode(json);
          return movie['id'] == widget.movie.id.toString();
        });

        await prefs.setStringList('saved_movies', savedMoviesJson);

        setState(() {
          _isSaved = false;
        });

        _showSuccessSnackBar('Movie removed from saved list');
      } else {
        // Add to saved
        final savedMovie = _createSavedMovie();
        savedMoviesJson.add(jsonEncode(savedMovie.toJson()));

        await prefs.setStringList('saved_movies', savedMoviesJson);

        setState(() {
          _isSaved = true;
        });

        // Play save animation
        _saveAnimationController.forward().then((_) {
          _saveAnimationController.reverse();
        });

        _showSuccessSnackBar('Movie saved successfully!');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to save movie: $e');
    }
  }

  SavedMovie _createSavedMovie() {
    // Extract cast names from movie details
    List<String> castNames = [];
    if (_movieDetails != null && _movieDetails!['credits'] != null) {
      final cast = List<Map<String, dynamic>>.from(
        _movieDetails!['credits']['cast'] ?? [],
      );
      castNames = cast
          .take(10)
          .map((person) => person['name'] as String? ?? '')
          .toList(); // ✅ Now it's List<String>
    }

    // Extract crew info from movie details
    Map<String, List<String>> crewInfo = {};
    if (_movieDetails != null && _movieDetails!['credits'] != null) {
      final crew = List<Map<String, dynamic>>.from(
        _movieDetails!['credits']['crew'] ?? [],
      );

      for (final person in crew) {
        final job = person['job'] ?? 'Unknown';
        final name = person['name'] ?? '';
        if (name.isNotEmpty) {
          if (!crewInfo.containsKey(job)) {
            crewInfo[job] = [];
          }
          crewInfo[job]!.add(name);
        }
      }
    }

    return SavedMovie(
      id: widget.movie.id.toString(),
      title: widget.movie.title,
      overview: widget.movie.overview,
      posterUrl: widget.movie.posterUrl,
      backdropUrl: widget.movie.backdropUrlLarge,
      releaseDate: widget.movie.releaseDate,
      voteAverage: widget.movie.voteAverage,
      cast: castNames,
      crew: crewInfo,
      savedAt: DateTime.now(),
    );
  }

  // Add this method to fetch stream for download
  Future<void> _fetchStreamForDownload() async {
    setState(() {
      _isFetching = true;
      _isUsingCache = false;
    });

    try {
      // Try to get cached result first
      final cachedResult = await StreamCacheService.getCachedStreamResult(
        widget.movie.title,
      );

      if (cachedResult != null) {
        setState(() {
          _streamResult = cachedResult;
          _isFetching = false;
          _isUsingCache = true;
        });
        return;
      }

      // If no cache, fetch from server
      final result = await _api.searchMovie(
        movieName: widget.movie.title,
        quality: '1080',
        fetchSubs: true,
      );

      // Cache the result
      await StreamCacheService.cacheStreamResult(widget.movie.title, result);

      setState(() {
        _streamResult = result;
        _isFetching = false;
        _isUsingCache = false;
      });
    } catch (e) {
      setState(() {
        _isFetching = false;
        _isUsingCache = false;
      });
      throw e;
    }
  }

  // Add this method for success snackbar
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.nunito(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _loadWatchProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final positionMs = prefs.getInt('movie_${widget.movie.id}_position');
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
      'movie_${widget.movie.id}_position',
      position.inMilliseconds,
    );
  }

  void _fetchStream() async {
    setState(() {
      _isFetching = true;
      _isUsingCache = false;
    });

    try {
      // Try to get cached result first
      final cachedResult = await StreamCacheService.getCachedStreamResult(
        widget.movie.title,
      );

      Map<String, dynamic> result;

      if (cachedResult != null) {
        result = cachedResult;
        setState(() {
          _streamResult = result;
          _isFetching = false;
          _isUsingCache = true;
        });

        // Show cache indicator
        _showCacheSnackBar('Using cached stream link ⚡');
      } else {
        // If no cache, fetch from server
        result = await _api.searchMovie(
          movieName: widget.movie.title,
          quality: '1080',
          fetchSubs: true,
        );

        // Cache the result
        await StreamCacheService.cacheStreamResult(widget.movie.title, result);

        setState(() {
          _streamResult = result;
          _isFetching = false;
          _isUsingCache = false;
        });
      }

      _playMovie(result);
    } catch (e) {
      setState(() {
        _isFetching = false;
        _isUsingCache = false;
      });

      _showErrorSnackBar('Failed to fetch stream: $e');
    }
  }

  void _showCacheSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.flash_on, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.nunito(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _playMovie(Map<String, dynamic> result) async {
    if (result['m3u8_link'] != null) {
      final prefs = await SharedPreferences.getInstance();
      final resumeFromLastPosition =
          prefs.getBool('resume_from_last_position') ?? false;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SimpleStreamPlayer(
            streamUrl: result['m3u8_link'],
            movieTitle: widget.movie.title,
            startPosition: _lastWatchedPosition,
            onPositionChanged: _saveWatchProgress,
            subtitleUrls: result['subtitles'] != null
                ? List<String>.from(result['subtitles'])
                : null,
            isTvShow: false,
            autoPlay: autoPlay,
            resumeFromLastPosition: resumeFromLastPosition,
            customHeaders: {
              'Referer': 'https://111movies.com/',
              'Origin': 'https://111movies.com',
            }, // Pass the setting here
          ),
        ),
      );
    }
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    return "${hours}h ${minutes}m";
  }

  Future<void> _loadMovieDetails() async {
    setState(() {
      _isLoadingDetails = true;
    });

    try {
      final details = await ExploreApi.getMovieDetails(widget.movie.id);
      setState(() {
        _movieDetails = details;
        _isLoadingDetails = false;
      });

      // Check if there's a trailer available
      final videos = _movieDetails!['videos'];
      if (videos != null && videos['results'] != null) {
        final videoResults = List<Map<String, dynamic>>.from(videos['results']);
        final trailer = videoResults.firstWhere(
          (video) => video['type'] == 'Trailer' && video['site'] == 'YouTube',
          orElse: () => {},
        );

        if (trailer.isNotEmpty) {
          final trailerKey = trailer['key'];
          if (trailerKey != null) {
            setState(() {
              _trailerUrl = 'https://www.youtube.com/watch?v=$trailerKey';
              _hasTrailer = true;
            });

            // Start the timer to play trailer after 3 seconds (reduced from 5)
            _startTrailerTimer();
          }
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingDetails = false;
      });
      print('Failed to load movie details: $e');
    }
  }

  void _startTrailerTimer() {
    _trailerTimer?.cancel();
    _trailerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _hasTrailer && !_isTrailerPlaying) {
        _playTrailer();
      }
    });
  }

  void _playTrailer() async {
    try {
      if (_trailerUrl == null) return;

      // Extract video ID from YouTube URL
      final videoId = VideoId(_trailerUrl!);

      // Get stream manifest
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);

      // Get the best quality stream (prefer mp4)
      final streamInfo = manifest.muxed
          .where((stream) => stream.container.name == 'mp4')
          .withHighestBitrate();

      if (streamInfo == null) {
        print('No suitable stream found for trailer');
        return;
      }

      // Dispose previous controller if it exists
      await _trailerController?.dispose();

      final newController =
          VideoPlayerController.network(streamInfo.url.toString())
            ..setLooping(true)
            ..setVolume(0);

      setState(() {
        _trailerController = newController;
        _trailerController?.addListener(_checkBufferingProgress);
      });

      await _trailerController?.initialize();

      setState(() {
        _isTrailerPlaying = true;
        _isTrailerMuted = true;
      });

      _trailerController?.play();
    } catch (e) {
      print('Failed to play trailer: $e');
      // Fallback: try to show poster image
      setState(() {
        _hasTrailer = false;
        _isTrailerPlaying = false;
      });
    }
  }

  void _checkBufferingProgress() {
    if (_trailerController?.value.isInitialized == true) {
      final buffered = _trailerController!.value.buffered;
      final duration = _trailerController!.value.duration;

      if (duration.inMilliseconds > 0 && buffered.isNotEmpty) {
        // Get the most recent buffered range
        final latestBuffered = buffered.last;
        final percentage =
            latestBuffered.end.inMilliseconds / duration.inMilliseconds;

        setState(() {
          _bufferedPercentage = percentage;
        });

        // Reduce threshold to 1% for faster trailer display
        if (percentage >= 0.01 && !_isTrailerBuffered) {
          setState(() {
            _isTrailerBuffered = true;
          });
        }
      }
    }
  }

  void _stopTrailer() {
    _trailerTimer?.cancel();
    if (_isTrailerPlaying) {
      _trailerController.pause();
      setState(() {
        _isTrailerPlaying = false;
        _isTrailerBuffered = false;
      });
    }
  }

  void _toggleTrailerMute() {
    if (_isTrailerPlaying) {
      setState(() {
        _isTrailerMuted = !_isTrailerMuted;
      });
      _trailerController.setVolume(_isTrailerMuted ? 0 : 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: GestureDetector(
        onTap: () {
          if (_isTrailerPlaying) {
            setState(() {
              _showTrailerControls = !_showTrailerControls;
            });

            // Hide controls after 3 seconds
            if (_showTrailerControls) {
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted && _showTrailerControls) {
                  setState(() {
                    _showTrailerControls = false;
                  });
                }
              });
            }
          }
        },
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildMovieDetails(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 400,
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
          onPressed: () {
            _stopTrailer();
            Navigator.pop(context);
          },
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Show poster until trailer has buffered at least 2%
            if (!_isTrailerBuffered || !_isTrailerPlaying)
              Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: CachedNetworkImageProvider(
                      widget.movie.backdropUrlLarge,
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            // Trailer player (only show when buffered)
            if (_isTrailerPlaying && _isTrailerBuffered)
              AspectRatio(
                aspectRatio: _trailerController.value.aspectRatio,
                child: VideoPlayer(_trailerController),
              ),

            // Gradient overlay
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

            // Mute/unmute button for trailer
            if (_isTrailerPlaying && _isTrailerBuffered)
              Positioned(
                right: 16,
                bottom: 16,
                child: AnimatedOpacity(
                  opacity: _showTrailerControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isTrailerMuted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: _toggleTrailerMute,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovieDetails() {
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
          const SizedBox(height: 20),
          _buildSubtitleInfo(),
          const SizedBox(height: 32),
          _buildOverviewSection(),
          const SizedBox(height: 32),
          _buildCrewSection(),
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
                  Text(
                    widget.movie.title,
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (widget.movie.originalTitle != widget.movie.title) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.movie.originalTitle ?? '',
                      style: GoogleFonts.nunito(
                        color: Colors.grey[400],
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
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
      spacing: 20,
      runSpacing: 12,
      children: [
        _buildMetaChip(
          icon: Icons.star_rounded,
          text: widget.movie.voteAverage.toStringAsFixed(1),
          color: Colors.amber,
        ),
        _buildMetaChip(
          icon: Icons.calendar_today_rounded,
          text: widget.movie.releaseDate?.split('-')[0] ?? '',
          color: Colors.blue,
        ),
        if (widget.movie.runtime != null && widget.movie.runtime! > 0)
          _buildMetaChip(
            icon: Icons.schedule_rounded,
            text: _formatDuration(Duration(minutes: widget.movie.runtime!)),
            color: Colors.green,
          ),
        _buildMetaChip(
          icon: Icons.language_rounded,
          text: widget.movie.originalLanguage?.toUpperCase() ?? '',
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
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 500),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: _hasWatchProgress
                                ? [
                                    const Color(0xFF059200),
                                    const Color(0xFF07B600),
                                  ]
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
                                  (_hasWatchProgress
                                          ? const Color(0xFF059200)
                                          : const Color.fromARGB(
                                              255,
                                              73,
                                              54,
                                              244,
                                            ))
                                      .withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _isFetching ? null : _fetchStream,
                          icon: _isFetching
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
                                  _hasWatchProgress
                                      ? Icons.play_circle_filled
                                      : Icons.play_arrow_rounded,
                                  size: 28,
                                ),
                          label: Text(
                            _isFetching
                                ? 'Finding Streams...'
                                : _hasWatchProgress
                                ? 'Continue Watching'
                                : 'Play Movie',
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
              ),
              const SizedBox(width: 12),
              ScaleTransition(
                scale: _saveAnimation,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 500),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isSaved
                                ? [
                                    Colors.red.withOpacity(0.2),
                                    Colors.red.withOpacity(0.1),
                                  ]
                                : [
                                    Colors.grey.withOpacity(0.2),
                                    Colors.grey.withOpacity(0.1),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isSaved
                                ? Colors.red.withOpacity(0.5)
                                : Colors.grey.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: _isSaved
                              ? [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.3),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ]
                              : [],
                        ),
                        child: IconButton(
                          onPressed: _toggleSaveMovie,
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) {
                              return ScaleTransition(
                                scale: animation,
                                child: child,
                              );
                            },
                            child: Icon(
                              _isSaved ? Icons.bookmark : Icons.bookmark_border,
                              key: ValueKey(_isSaved),
                              color: _isSaved ? Colors.red : Colors.grey[400],
                              size: 28,
                            ),
                          ),
                          tooltip: _isSaved
                              ? 'Remove from saved'
                              : 'Save movie',
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Add these methods
  void _playDownloadedMovie() {
    final downloadItem = _downloadManager.getDownloadForMovie(
      widget.movie.title,
    );
    if (downloadItem != null &&
        downloadItem.status == DownloadStatus.completed) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SimpleStreamPlayer(
            streamUrl: 'file://${downloadItem.outputPath}',
            movieTitle: widget.movie.title,
            startPosition: _lastWatchedPosition,
            onPositionChanged: _saveWatchProgress,
            // isLocalFile: true,
          ),
        ),
      );
    }
  }

  Future<void> _cancelDownload() async {
    if (_downloadId != null) {
      await _downloadManager.cancelDownload(_downloadId!);
      setState(() {
        _isDownloading = false;
        _downloadId = null;
      });
      _showSuccessSnackBar('Download cancelled');
    }
  }

  Widget _buildSubtitleInfo() {
    if (_streamResult != null &&
        _streamResult!['subtitles'] != null &&
        (_streamResult!['subtitles'] as List).isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.subtitles_rounded, color: Colors.green),
            const SizedBox(width: 12),
            Text(
              'Subtitles Available',
              style: GoogleFonts.nunito(
                color: Colors.green,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildOverviewSection() {
    if (widget.movie.overview?.isEmpty ?? true) return const SizedBox.shrink();

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
                'Overview',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 26,
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
            child: Text(
              widget.movie.overview!,
              style: GoogleFonts.nunito(
                color: Colors.grey[200],
                fontSize: 16,
                height: 1.7,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrewSection() {
    if (_isLoadingDetails) {
      return Center(child: CircularProgressIndicator());
    }

    if (_movieDetails == null) {
      return SizedBox.shrink();
    }

    final credits = _movieDetails!['credits'];
    final cast = credits != null
        ? List<Map<String, dynamic>>.from(credits['cast'] ?? [])
        : [];
    final crew = credits != null
        ? List<Map<String, dynamic>>.from(credits['crew'] ?? [])
        : [];

    // Get top 4 cast members
    final topCast = cast.take(4).toList();

    // Get key crew members and group by job
    final keyCrew = crew
        .where(
          (person) => [
            'Director',
            'Producer',
            'Screenplay',
            'Writer',
            'Story',
            'Executive Producer',
            'Co-Producer',
            'Associate Producer',
          ].contains(person['job']),
        )
        .toList();

    // Group crew by job
    final Map<String, List<Map<String, dynamic>>> crewByJob = {};
    for (final person in keyCrew) {
      final job = person['job'] ?? 'Unknown';
      if (!crewByJob.containsKey(job)) {
        crewByJob[job] = [];
      }
      crewByJob[job]!.add(person);
    }

    // Define the order of jobs to display
    const jobOrder = [
      'Director',
      'Producer',
      'Executive Producer',
      'Co-Producer',
      'Associate Producer',
      'Screenplay',
      'Writer',
      'Story',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (topCast.isNotEmpty) ...[
          Text(
            'Cast',
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: topCast.length,
              itemBuilder: (context, index) {
                final person = topCast[index];
                final profilePath = person['profile_path'];
                final profileUrl = _getProfileUrlHQ(profilePath);

                return Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 16),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: CachedNetworkImageProvider(profileUrl),
                        backgroundColor: Colors.grey[800],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        person['name'] ?? 'Unknown',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        person['character'] ?? '',
                        style: GoogleFonts.nunito(
                          color: Colors.grey[400],
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (crewByJob.isNotEmpty) ...[
          Text(
            'Crew',
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display each job category in order
              for (final job in jobOrder)
                if (crewByJob.containsKey(job)) ...[
                  Text(
                    job,
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      for (final person in crewByJob[job]!)
                        Text(
                          person['name'] ?? 'Unknown',
                          style: GoogleFonts.nunito(
                            color: Colors.grey[400],
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              // Display any other jobs not in the predefined order
              for (final job in crewByJob.keys)
                if (!jobOrder.contains(job)) ...[
                  Text(
                    job,
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      for (final person in crewByJob[job]!)
                        Text(
                          person['name'] ?? 'Unknown',
                          style: GoogleFonts.nunito(
                            color: Colors.grey[400],
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
            ],
          ),
        ],
      ],
    );
  }

  // Helper method to generate profile URL
  String _getProfileUrlHQ(String? profilePath) {
    return profilePath != null
        ? 'https://image.tmdb.org/t/p/h632$profilePath'
        : 'https://via.placeholder.com/632x632/333/fff?text=No+Image';
  }
}
