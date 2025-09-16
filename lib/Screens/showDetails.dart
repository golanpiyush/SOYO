import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soyo/Services/exploretvapi.dart';
import 'package:soyo/Services/m3u8api.dart';
import 'package:soyo/Screens/playerScreen.dart';
import 'package:soyo/Services/streams_cacher.dart';
import 'package:soyo/models/tvshowsmodel.dart';
import 'package:soyo/widget/custom_dropdown_tv.dart';

class ShowDetailScreen extends StatefulWidget {
  final TvShow show;

  const ShowDetailScreen({Key? key, required this.show}) : super(key: key);

  @override
  _ShowDetailScreenState createState() => _ShowDetailScreenState();
}

class _ShowDetailScreenState extends State<ShowDetailScreen>
    with SingleTickerProviderStateMixin {
  final M3U8Api _api = M3U8Api();
  bool _isFetching = false;
  Map<String, dynamic>? _streamResult;
  Map<int, Map<int, Duration>> _watchProgress = {};
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Map<String, dynamic>? _showDetails;
  bool _isLoadingDetails = false;

  // Season/Episode selection
  int _selectedSeason = 1;
  int _selectedEpisode = 1;
  Map<int, List<Map<String, dynamic>>> _episodesBySeason = {};
  bool _isSeasonDropdownOpen = false;
  bool _isEpisodeDropdownOpen = false;

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
    _loadShowDetails();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadWatchProgress() async {
    final prefs = await SharedPreferences.getInstance();

    // Load progress for all episodes
    final progressKeys = prefs.getKeys().where(
      (key) => key.startsWith('show_${widget.show.id}_'),
    );

    setState(() {
      for (final key in progressKeys) {
        final parts = key.split('_');
        if (parts.length >= 5) {
          final season = int.tryParse(parts[3]);
          final episode = int.tryParse(parts[4]);
          final positionMs = prefs.getInt(key);

          if (season != null &&
              episode != null &&
              positionMs != null &&
              positionMs > 0) {
            if (!_watchProgress.containsKey(season)) {
              _watchProgress[season] = {};
            }
            _watchProgress[season]![episode] = Duration(
              milliseconds: positionMs,
            );
          }
        }
      }
    });
  }

  Future<void> _saveWatchProgress(
    int season,
    int episode,
    Duration position,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'show_${widget.show.id}_season_${season}_episode_${episode}_position',
      position.inMilliseconds,
    );
  }

  void _fetchStream() async {
    setState(() {
      _isFetching = true;
    });

    try {
      // Check cache first
      final cachedResult = await StreamCacheService.getCachedTvShowStreamResult(
        widget.show.id,
        _selectedSeason,
        _selectedEpisode,
      );

      if (cachedResult != null) {
        setState(() {
          _streamResult = cachedResult;
          _isFetching = false;
        });
        _playEpisode(cachedResult);
        return;
      }

      // If no cache, fetch from API
      final result = await _api.searchTvShowByTmdbId(
        tmdbId: widget.show.id,
        season: _selectedSeason,
        episode: _selectedEpisode,
        quality: '1080',
        fetchSubs: true,
        onStatusUpdate: (status) {
          print('Search status: $status');
        },
      );

      // Cache the result
      await StreamCacheService.cacheTvShowStreamResult(
        widget.show.id,
        _selectedSeason,
        _selectedEpisode,
        result,
      );

      setState(() {
        _streamResult = result;
        _isFetching = false;
      });

      _playEpisode(result);
    } catch (e) {
      setState(() {
        _isFetching = false;
      });

      _showErrorSnackBar('Failed to fetch stream: $e');
    }
  }

  // Updated _playEpisode method in ShowDetailScreen
  void _playEpisode(Map<String, dynamic> result) {
    if (result['m3u8_link'] != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SimpleStreamPlayer(
            streamUrl: result['m3u8_link'],
            movieTitle: widget.show.name,
            startPosition: _watchProgress[_selectedSeason]?[_selectedEpisode],
            onPositionChanged: (position) =>
                _saveWatchProgress(_selectedSeason, _selectedEpisode, position),
            subtitleUrls: result['subtitles'] != null
                ? List<String>.from(result['subtitles'])
                : null,
            isTvShow: true,
            currentEpisode: _selectedEpisode,
            totalEpisodes: _episodesBySeason[_selectedSeason]?.length,
            onNextEpisode: _canGoToNextEpisode() ? _goToNextEpisode : null,
            onPreviousEpisode: _canGoToPreviousEpisode()
                ? _goToPreviousEpisode
                : null,
          ),
        ),
      );
    }
  }

  // Helper method to check if next episode is available
  bool _canGoToNextEpisode() {
    final currentSeasonEpisodes = _episodesBySeason[_selectedSeason] ?? [];
    final currentEpisodeIndex = currentSeasonEpisodes.indexWhere(
      (ep) => ep['episode_number'] == _selectedEpisode,
    );

    // Check if there's a next episode in current season
    if (currentEpisodeIndex != -1 &&
        currentEpisodeIndex < currentSeasonEpisodes.length - 1) {
      return true;
    }

    // Check if there's a next season with episodes
    final seasons = _episodesBySeason.keys.toList()..sort();
    final currentSeasonIndex = seasons.indexOf(_selectedSeason);
    if (currentSeasonIndex != -1 && currentSeasonIndex < seasons.length - 1) {
      final nextSeason = seasons[currentSeasonIndex + 1];
      final nextSeasonEpisodes = _episodesBySeason[nextSeason] ?? [];
      return nextSeasonEpisodes.isNotEmpty;
    }

    return false;
  }

  // Helper method to check if previous episode is available
  bool _canGoToPreviousEpisode() {
    final currentSeasonEpisodes = _episodesBySeason[_selectedSeason] ?? [];
    final currentEpisodeIndex = currentSeasonEpisodes.indexWhere(
      (ep) => ep['episode_number'] == _selectedEpisode,
    );

    // Check if there's a previous episode in current season
    if (currentEpisodeIndex > 0) {
      return true;
    }

    // Check if there's a previous season with episodes
    final seasons = _episodesBySeason.keys.toList()..sort();
    final currentSeasonIndex = seasons.indexOf(_selectedSeason);
    if (currentSeasonIndex > 0) {
      final previousSeason = seasons[currentSeasonIndex - 1];
      final previousSeasonEpisodes = _episodesBySeason[previousSeason] ?? [];
      return previousSeasonEpisodes.isNotEmpty;
    }

    return false;
  }

  // Method to navigate to next episode
  void _goToNextEpisode() {
    final currentSeasonEpisodes = _episodesBySeason[_selectedSeason] ?? [];
    final currentEpisodeIndex = currentSeasonEpisodes.indexWhere(
      (ep) => ep['episode_number'] == _selectedEpisode,
    );

    // Try next episode in current season first
    if (currentEpisodeIndex != -1 &&
        currentEpisodeIndex < currentSeasonEpisodes.length - 1) {
      final nextEpisode = currentSeasonEpisodes[currentEpisodeIndex + 1];
      setState(() {
        _selectedEpisode = nextEpisode['episode_number'];
      });
    } else {
      // Move to first episode of next season
      final seasons = _episodesBySeason.keys.toList()..sort();
      final currentSeasonIndex = seasons.indexOf(_selectedSeason);
      if (currentSeasonIndex != -1 && currentSeasonIndex < seasons.length - 1) {
        final nextSeason = seasons[currentSeasonIndex + 1];
        final nextSeasonEpisodes = _episodesBySeason[nextSeason] ?? [];
        if (nextSeasonEpisodes.isNotEmpty) {
          setState(() {
            _selectedSeason = nextSeason;
            _selectedEpisode = nextSeasonEpisodes.first['episode_number'];
          });
        }
      }
    }

    // Automatically fetch and play the next episode
    _fetchStream();
  }

  // Method to navigate to previous episode
  void _goToPreviousEpisode() {
    final currentSeasonEpisodes = _episodesBySeason[_selectedSeason] ?? [];
    final currentEpisodeIndex = currentSeasonEpisodes.indexWhere(
      (ep) => ep['episode_number'] == _selectedEpisode,
    );

    // Try previous episode in current season first
    if (currentEpisodeIndex > 0) {
      final previousEpisode = currentSeasonEpisodes[currentEpisodeIndex - 1];
      setState(() {
        _selectedEpisode = previousEpisode['episode_number'];
      });
    } else {
      // Move to last episode of previous season
      final seasons = _episodesBySeason.keys.toList()..sort();
      final currentSeasonIndex = seasons.indexOf(_selectedSeason);
      if (currentSeasonIndex > 0) {
        final previousSeason = seasons[currentSeasonIndex - 1];
        final previousSeasonEpisodes = _episodesBySeason[previousSeason] ?? [];
        if (previousSeasonEpisodes.isNotEmpty) {
          setState(() {
            _selectedSeason = previousSeason;
            _selectedEpisode = previousSeasonEpisodes.last['episode_number'];
          });
        }
      }
    }

    // Automatically fetch and play the previous episode
    _fetchStream();
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

  Future<void> _loadShowDetails() async {
    setState(() {
      _isLoadingDetails = true;
    });

    try {
      Map<String, dynamic> details = {};
      bool tmdbSuccess = false;

      try {
        // Try TMDB first
        details = await ExploreTvApi.getTvShowDetails(widget.show.id);
        tmdbSuccess = true;
      } catch (tmdbError) {
        print("TMDB failed, falling back to OMDb: $tmdbError");
      }

      if (tmdbSuccess) {
        // ✅ TMDB path
        setState(() {
          _showDetails = details;
          _isLoadingDetails = false;
        });

        if (details['seasons'] != null) {
          final seasons = List<Map<String, dynamic>>.from(details['seasons']);

          final validSeasons = seasons
              .where(
                (season) =>
                    season['season_number'] != null &&
                    season['season_number']! > 0 &&
                    season['episode_count'] != null &&
                    season['episode_count']! > 0,
              )
              .toList();

          if (validSeasons.isNotEmpty) {
            for (final season in validSeasons) {
              final seasonNumber = season['season_number'];
              final episodeData = await ExploreTvApi.getSeasonEpisodes(
                widget.show.id,
                seasonNumber,
              );

              if (episodeData['episodes'] != null) {
                final episodes = List<Map<String, dynamic>>.from(
                  episodeData['episodes'],
                );
                _episodesBySeason[seasonNumber] = episodes;
              }
            }

            setState(() {
              _selectedSeason = validSeasons.first['season_number'];
              if (_episodesBySeason.containsKey(_selectedSeason) &&
                  _episodesBySeason[_selectedSeason]!.isNotEmpty) {
                _selectedEpisode =
                    _episodesBySeason[_selectedSeason]!.first['episode_number'];
              }
            });
          }
        }
      } else {
        // ❌ TMDB failed → fallback to OMDb
        // You need an IMDb ID for OMDb
        final imdbId = widget.show.imdbId ?? details['imdb_id'];
        if (imdbId == null) {
          throw Exception("No IMDb ID available for OMDb fallback");
        }

        // OMDb gives totalSeasons
        final firstSeason = await ExploreTvApi.getOmdbSeasonEpisodes(imdbId, 1);

        if (firstSeason["totalSeasons"] != null) {
          int totalSeasons = int.tryParse(firstSeason["totalSeasons"]) ?? 1;

          for (int s = 1; s <= totalSeasons; s++) {
            final seasonData = await ExploreTvApi.getOmdbSeasonEpisodes(
              imdbId,
              s,
            );

            if (seasonData['Episodes'] != null) {
              final episodes = List<Map<String, dynamic>>.from(
                seasonData['Episodes'],
              );
              _episodesBySeason[s] = episodes;
            }
          }

          setState(() {
            _showDetails = {
              "Title": firstSeason["Title"] ?? widget.show.name,
              "totalSeasons": totalSeasons,
            };
            _isLoadingDetails = false;

            _selectedSeason = 1;
            if (_episodesBySeason.containsKey(1) &&
                _episodesBySeason[1]!.isNotEmpty) {
              _selectedEpisode = 1; // OMDb uses "Episode": "1", etc.
            }
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingDetails = false;
      });
      print('Failed to load show details (TMDB + OMDb): $e');
    }
  }

  bool _hasWatchProgress(int season, int episode) {
    return _watchProgress.containsKey(season) &&
        _watchProgress[season]!.containsKey(episode) &&
        _watchProgress[season]![episode]!.inSeconds > 0;
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
              child: _buildShowDetails(),
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
                    widget.show.backdropUrlLarge,
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

  Widget _buildShowDetails() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitleSection(),
          const SizedBox(height: 20),
          _buildMetaInfo(),
          const SizedBox(height: 24),
          _buildSeasonEpisodeSelector(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.show.name,
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        if (widget.show.originalName != widget.show.name) ...[
          const SizedBox(height: 8),
          Text(
            widget.show.originalName ?? '',
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
          text: widget.show.voteAverage.toStringAsFixed(1),
          color: Colors.amber,
        ),
        if (widget.show.firstAirDate != null)
          _buildMetaChip(
            icon: Icons.calendar_today_rounded,
            text: widget.show.firstAirDate!.split('-')[0],
            color: Colors.blue,
          ),
        _buildMetaChip(
          icon: Icons.language_rounded,
          text: widget.show.originalLanguage?.toUpperCase() ?? '',
          color: Colors.purple,
        ),
        if (_showDetails != null && _showDetails!['number_of_seasons'] != null)
          _buildMetaChip(
            icon: Icons.live_tv_rounded,
            text: '${_showDetails!['number_of_seasons']} Seasons',
            color: Colors.green,
          ),
        if (_showDetails != null && _showDetails!['number_of_episodes'] != null)
          _buildMetaChip(
            icon: Icons.playlist_play_rounded,
            text: '${_showDetails!['number_of_episodes']} Episodes',
            color: Colors.orange,
          ),
        if (_showDetails != null && _showDetails!['status'] != null)
          _buildMetaChip(
            icon: Icons.info_rounded,
            text: _showDetails!['status'],
            color: _showDetails!['status'] == 'Ended'
                ? Colors.red
                : Colors.teal,
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

  Widget _buildSeasonEpisodeSelector() {
    final seasons = _episodesBySeason.keys.toList()..sort();
    final episodes = _episodesBySeason[_selectedSeason] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Episode',
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomDropdown<int>(
                label: 'Season',
                value: _selectedSeason,
                items: seasons,
                maxHeight: 300,
                displayText: (value) => 'Season $value',
                onChanged: (value) {
                  setState(() {
                    _selectedSeason = value;
                    final seasonEpisodes = _episodesBySeason[value] ?? [];
                    _selectedEpisode = seasonEpisodes.isNotEmpty
                        ? seasonEpisodes.first['episode_number'] ?? 1
                        : 1;
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomDropdown<int>(
                label: 'Episode',
                value: _selectedEpisode,
                items: episodes.map((e) => e['episode_number'] as int).toList(),
                maxHeight: 350,
                displayText: (value) {
                  final episode = episodes.firstWhere(
                    (e) => e['episode_number'] == value,
                    orElse: () => {'name': 'Episode $value'},
                  );
                  final name = episode['name'] ?? 'Episode $value';
                  return 'E${value.toString().padLeft(2, '0')}: ${name.length > 25 ? '${name.substring(0, 25)}...' : name}';
                },
                trailing: (value) {
                  return _hasWatchProgress(_selectedSeason, value)
                      ? Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 14,
                          ),
                        )
                      : null;
                },
                onChanged: (value) {
                  setState(() {
                    _selectedEpisode = value;
                  });
                },
              ),
            ),
          ],
        ),
        if (episodes.isNotEmpty &&
            episodes.any((e) => e['episode_number'] == _selectedEpisode))
          _buildEpisodeDetails(
            episodes.firstWhere(
              (e) => e['episode_number'] == _selectedEpisode,
              orElse: () => {},
            ),
          ),
      ],
    );
  }

  Widget _buildEpisodeDetails(Map<String, dynamic> episode) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900]!.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (episode['name'] != null)
            Text(
              episode['name'],
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (episode['overview'] != null &&
              episode['overview'].isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              episode['overview'],
              style: GoogleFonts.nunito(
                color: Colors.grey[300],
                fontSize: 14,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (episode['air_date'] != null) ...[
            const SizedBox(height: 8),
            Text(
              'Aired: ${episode['air_date']}',
              style: GoogleFonts.nunito(color: Colors.grey[400], fontSize: 12),
            ),
          ],
          if (episode['runtime'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Runtime: ${episode['runtime']} minutes',
              style: GoogleFonts.nunito(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayButton() {
    final hasProgress = _hasWatchProgress(_selectedSeason, _selectedEpisode);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton.icon(
        onPressed: _isFetching ? null : _fetchStream,
        icon: _isFetching
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(
                hasProgress ? Icons.play_circle_filled : Icons.play_arrow,
                size: 24,
              ),
        label: Text(
          _isFetching
              ? 'Loading Stream...'
              : hasProgress
              ? 'Continue Watching'
              : 'Play Episode',
          style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: hasProgress
              ? const Color.fromARGB(255, 9, 255, 0)
              : const Color.fromARGB(255, 73, 54, 244),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          shadowColor:
              (hasProgress
                      ? Colors.orange
                      : const Color.fromARGB(255, 54, 184, 244))
                  .withOpacity(0.3),
        ),
      ),
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
    if (widget.show.overview?.isEmpty ?? true) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
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
            widget.show.overview!,
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

  Widget _buildCrewSection() {
    if (_isLoadingDetails) {
      return Center(child: CircularProgressIndicator());
    }

    if (_showDetails == null) {
      return SizedBox.shrink();
    }

    final credits = _showDetails!['credits'];
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
            'Creator',
            'Director',
            'Producer',
            'Screenplay',
            'Writer',
            'Executive Producer',
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
      'Creator',
      'Director',
      'Executive Producer',
      'Producer',
      'Writer',
      'Screenplay',
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
