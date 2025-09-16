import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soyo/Services/m3u8api.dart';
import 'package:soyo/Screens/playerScreen.dart';
import 'package:soyo/Services/streams_cacher.dart';
import 'package:soyo/models/anime_model.dart';
import 'package:soyo/models/savedanimesmodel.dart';

class SingleAnimeDetailScreen extends StatefulWidget {
  final Anime anime;

  const SingleAnimeDetailScreen({Key? key, required this.anime})
    : super(key: key);

  @override
  _SingleAnimeDetailScreenState createState() =>
      _SingleAnimeDetailScreenState();
}

class _SingleAnimeDetailScreenState extends State<SingleAnimeDetailScreen>
    with TickerProviderStateMixin {
  final M3U8Api _api = M3U8Api();
  bool _isFetching = false;
  Map<String, dynamic>? _streamResult;
  Duration? _lastWatchedPosition;
  bool _hasWatchProgress = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Map<String, dynamic>? _animeDetails;
  bool _isLoadingDetails = false;

  bool _isUsingCache = false;

  bool _isSaved = false;
  late AnimationController _saveAnimationController;
  late Animation<double> _saveAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _loadWatchProgress();
    _loadAnimeDetails();

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
    StreamCacheService.clearExpiredCache();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _saveAnimationController.dispose();
    super.dispose();
  }

  Future<void> _checkIfSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAnimesJson = prefs.getStringList('saved_animes') ?? [];

      final isAlreadySaved = savedAnimesJson.any((json) {
        final anime = jsonDecode(json);
        return anime['id'] == widget.anime.id.toString();
      });

      setState(() {
        _isSaved = isAlreadySaved;
      });
    } catch (e) {
      print('Error checking saved status: $e');
    }
  }

  Future<void> _toggleSaveAnime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAnimesJson = prefs.getStringList('saved_animes') ?? [];

      if (_isSaved) {
        // Remove from saved
        savedAnimesJson.removeWhere((json) {
          final anime = jsonDecode(json);
          return anime['id'] == widget.anime.id.toString();
        });

        await prefs.setStringList('saved_animes', savedAnimesJson);

        setState(() {
          _isSaved = false;
        });

        _showSuccessSnackBar('Anime removed from saved list');
      } else {
        // Add to saved
        final savedAnime = _createSavedAnime();
        savedAnimesJson.add(jsonEncode(savedAnime.toJson()));

        await prefs.setStringList('saved_animes', savedAnimesJson);

        setState(() {
          _isSaved = true;
        });

        // Play save animation
        _saveAnimationController.forward().then((_) {
          _saveAnimationController.reverse();
        });

        _showSuccessSnackBar('Anime saved successfully!');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to save anime: $e');
    }
  }

  SavedAnime _createSavedAnime() {
    return SavedAnime(
      id: widget.anime.id.toString(),
      name: widget.anime.name,
      overview: widget.anime.overview,
      posterUrl: widget.anime.getPosterUrl(),
      backdropUrl: widget.anime.getBackdropUrl(),
      firstAirDate: widget.anime.firstAirDate,
      voteAverage: widget.anime.voteAverage,
      originalLanguage: widget.anime.originalLanguage,
      savedAt: DateTime.now(),
    );
  }

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
    final positionMs = prefs.getInt('anime_${widget.anime.id}_position');
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
      'anime_${widget.anime.id}_position',
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
        widget.anime.name,
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
        result = await _api.searchAnime(
          animeName: widget.anime.name,
          quality: '1080',
          fetchSubs: true,
        );

        // Cache the result
        await StreamCacheService.cacheStreamResult(widget.anime.name, result);

        setState(() {
          _streamResult = result;
          _isFetching = false;
          _isUsingCache = false;
        });
      }

      _playAnime(result);
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

  void _playAnime(Map<String, dynamic> result) {
    if (result['m3u8_link'] != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SimpleStreamPlayer(
            streamUrl: result['m3u8_link'],
            movieTitle: widget.anime.name,
            startPosition: _lastWatchedPosition,
            onPositionChanged: _saveWatchProgress,
            subtitleUrls: result['subtitles'] != null
                ? List<String>.from(result['subtitles'])
                : null,
            isTvShow: true,
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

  Future<void> _loadAnimeDetails() async {
    setState(() {
      _isLoadingDetails = true;
    });

    try {
      // You'll need to implement this method in your ExploreApi or create a similar service for anime
      // final details = await ExploreApi.getAnimeDetails(widget.anime.id);
      // For now, we'll use the existing anime data
      setState(() {
        _animeDetails = {
          'overview': widget.anime.overview,
          'vote_average': widget.anime.voteAverage,
          'first_air_date': widget.anime.firstAirDate,
          'original_language': widget.anime.originalLanguage,
        };
        _isLoadingDetails = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingDetails = false;
      });
      print('Failed to load anime details: $e');
    }
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
              child: _buildAnimeDetails(),
            ),
          ),
        ],
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
          onPressed: () => Navigator.pop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: CachedNetworkImageProvider(
                    widget.anime.getBackdropUrl(),
                  ),
                  fit: BoxFit.cover,
                ),
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

  Widget _buildAnimeDetails() {
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
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.anime.name,
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        if (widget.anime.originalName != widget.anime.name) ...[
          const SizedBox(height: 8),
          Text(
            widget.anime.originalName,
            style: GoogleFonts.nunito(
              color: Colors.grey[400],
              fontSize: 18,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetaInfo() {
    return Wrap(
      spacing: 20,
      runSpacing: 12,
      children: [
        _buildMetaChip(
          icon: Icons.star_rounded,
          text: widget.anime.voteAverage.toStringAsFixed(1),
          color: Colors.amber,
        ),
        if (widget.anime.firstAirDate.isNotEmpty)
          _buildMetaChip(
            icon: Icons.calendar_today_rounded,
            text: widget.anime.firstAirDate.split('-')[0],
            color: Colors.blue,
          ),
        _buildMetaChip(
          icon: Icons.language_rounded,
          text: widget.anime.originalLanguage.toUpperCase(),
          color: Colors.purple,
        ),
        _buildMetaChip(
          icon: Icons.tv_rounded,
          text: 'TV Series',
          color: Colors.green,
        ),
      ],
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.nunito(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: ElevatedButton.icon(
              // 🔥 CHANGE THIS LINE
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Coming soon!',
                            style: GoogleFonts.nunito(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.blueGrey.shade800,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: Icon(Icons.play_arrow, size: 24),
              label: Text(
                'Watch Anime',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 73, 54, 244),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
                shadowColor: const Color.fromARGB(
                  255,
                  54,
                  184,
                  244,
                ).withOpacity(0.3),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // ✅ Keep your save button as it is
        ScaleTransition(
          scale: _saveAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: _isSaved
                  ? Colors.red.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isSaved
                    ? Colors.red.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.3),
              ),
            ),
            child: IconButton(
              onPressed: _toggleSaveAnime,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  _isSaved ? Icons.bookmark : Icons.bookmark_border,
                  key: ValueKey(_isSaved),
                  color: _isSaved ? Colors.red : Colors.grey[400],
                  size: 28,
                ),
              ),
              tooltip: _isSaved ? 'Remove from saved' : 'Save anime',
              padding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
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
    if (widget.anime.overview.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Synopsis',
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[900]?.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: Text(
            widget.anime.overview,
            style: GoogleFonts.nunito(
              color: Colors.grey[300],
              fontSize: 16,
              height: 1.6,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
