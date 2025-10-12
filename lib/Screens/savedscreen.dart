import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soyo/Screens/homescreen.dart';
import 'package:soyo/Screens/showDetails.dart';
import 'package:soyo/models/moviemodel.dart';
import 'package:soyo/Screens/movieDetailScreen.dart';
import 'package:soyo/models/savedmoviesmodel.dart';
import 'package:soyo/models/savedtvshowmodel.dart';
import 'package:soyo/models/tvshowsmodel.dart';

enum SavedItemType { movie, tvShow }

class SavedItem {
  final String id;
  final SavedItemType type;
  final dynamic data;
  final bool isWatched;

  SavedItem({
    required this.id,
    required this.type,
    required this.data,
    required this.isWatched,
  });
}

class SavedScreen extends StatefulWidget {
  @override
  _SavedScreenState createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen>
    with TickerProviderStateMixin {
  List<SavedItem> _savedItems = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  late AnimationController _headerAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  String _filterType = 'all';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _loadSavedItems();
    _headerAnimationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _headerAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<SavedItem> items = [];

      final savedMoviesJson = prefs.getStringList('saved_movies') ?? [];
      for (final json in savedMoviesJson) {
        final movie = SavedMovie.fromJson(jsonDecode(json));
        final isWatched = await _isMovieWatched(movie.id, prefs);
        items.add(
          SavedItem(
            id: movie.id,
            type: SavedItemType.movie,
            data: movie,
            isWatched: isWatched,
          ),
        );
      }

      final savedShowsJson = prefs.getStringList('saved_shows') ?? [];
      for (final json in savedShowsJson) {
        final show = SavedTvShow.fromJson(jsonDecode(json));
        final isWatched = await _isShowWatched(show.id, prefs);
        items.add(
          SavedItem(
            id: show.id,
            type: SavedItemType.tvShow,
            data: show,
            isWatched: isWatched,
          ),
        );
      }

      setState(() {
        _savedItems = items;
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading saved items: $e');
    }
  }

  Future<bool> _isMovieWatched(String movieId, SharedPreferences prefs) async {
    final positionKey = 'movie_${movieId}_position';
    final durationKey = 'movie_${movieId}_duration';

    final position = prefs.getInt(positionKey) ?? 0;
    final duration = prefs.getInt(durationKey) ?? 0;

    if (duration > 0 && position > 0) {
      final watchedPercentage = (position / duration) * 100;
      return watchedPercentage >= 90;
    }
    return false;
  }

  Future<bool> _isShowWatched(String showId, SharedPreferences prefs) async {
    final progressKeys = prefs.getKeys().where(
      (key) => key.startsWith('show_${showId}_') && key.contains('_position'),
    );

    if (progressKeys.isEmpty) return false;

    for (final positionKey in progressKeys) {
      final position = prefs.getInt(positionKey) ?? 0;
      final durationKey = positionKey.replaceAll('_position', '_duration');
      final duration = prefs.getInt(durationKey) ?? 0;

      if (duration > 0 && position > 0) {
        final watchedPercentage = (position / duration) * 100;
        if (watchedPercentage >= 90) {
          return true;
        }
      }
    }

    return false;
  }

  Future<void> _removeSavedItem(SavedItem item) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (item.type == SavedItemType.movie) {
        final savedMoviesJson = prefs.getStringList('saved_movies') ?? [];
        savedMoviesJson.removeWhere((json) {
          final movie = SavedMovie.fromJson(jsonDecode(json));
          return movie.id == item.id;
        });
        await prefs.setStringList('saved_movies', savedMoviesJson);
        _showSnackBar('Movie removed from saved list', Colors.orange);
      } else {
        final savedShowsJson = prefs.getStringList('saved_shows') ?? [];
        savedShowsJson.removeWhere((json) {
          final show = SavedTvShow.fromJson(jsonDecode(json));
          return show.id == item.id;
        });
        await prefs.setStringList('saved_shows', savedShowsJson);
        _showSnackBar('Show removed from saved list', Colors.orange);
      }

      setState(() {
        _savedItems.removeWhere((i) => i.id == item.id);
      });
    } catch (e) {
      _showSnackBar('Failed to remove item', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.red
                  ? Icons.error_outline
                  : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
      ),
    );
  }

  List<SavedItem> get _filteredItems {
    if (_filterType == 'movies') {
      return _savedItems
          .where((item) => item.type == SavedItemType.movie)
          .toList();
    } else if (_filterType == 'shows') {
      return _savedItems
          .where((item) => item.type == SavedItemType.tvShow)
          .toList();
    }
    return _savedItems;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildFilterTabs()),
          _isLoading
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue, Colors.purple],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Loading your collection...',
                          style: GoogleFonts.nunito(
                            color: Colors.grey[400],
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _filteredItems.isEmpty
              ? SliverFillRemaining(child: _buildEmptyState())
              : _buildSavedItemsGrid(),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final movieCount = _savedItems
        .where((i) => i.type == SavedItemType.movie)
        .length;
    final showCount = _savedItems
        .where((i) => i.type == SavedItemType.tvShow)
        .length;

    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF0A0A0A),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.withOpacity(0.15),
                Colors.purple.withOpacity(0.15),
                const Color(0xFF0A0A0A),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue, Colors.purple],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.bookmark,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Collection',
                              style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$movieCount Movies • $showCount Shows',
                              style: GoogleFonts.nunito(
                                color: Colors.grey[400],
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Colors.grey[900]?.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _animationController.reset();
              });
              _loadSavedItems();
            },
            tooltip: 'Refresh',
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildFilterChip('All', 'all', Icons.grid_view_rounded),
            const SizedBox(width: 12),
            _buildFilterChip('Movies', 'movies', Icons.movie_rounded),
            const SizedBox(width: 12),
            _buildFilterChip('TV Shows', 'shows', Icons.live_tv_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _filterType == value;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _filterType = value;
            });
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [Colors.blue, Colors.purple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected ? null : Colors.grey[900]?.withOpacity(0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected ? Colors.transparent : Colors.grey[800]!,
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.grey[400],
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.nunito(
                    color: isSelected ? Colors.white : Colors.grey[400],
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message = 'No Saved Items';
    String subtitle = 'Start building your collection!';
    IconData icon = Icons.bookmark_border_rounded;

    if (_filterType == 'movies') {
      message = 'No Saved Movies';
      subtitle = 'Save movies to watch later';
      icon = Icons.movie_outlined;
    } else if (_filterType == 'shows') {
      message = 'No Saved TV Shows';
      subtitle = 'Save shows to binge watch';
      icon = Icons.live_tv_outlined;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withOpacity(0.2),
                  Colors.purple.withOpacity(0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 70, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          Text(
            message,
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: GoogleFonts.nunito(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSavedItemsGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = _filteredItems[index];
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: item.type == SavedItemType.movie
                  ? _buildMovieCard(item, index)
                  : _buildShowCard(item, index),
            ),
          );
        }, childCount: _filteredItems.length),
      ),
    );
  }

  Widget _buildMovieCard(SavedItem item, int index) {
    final movie = item.data as SavedMovie;
    return _buildItemCard(
      id: item.id,
      title: movie.title,
      posterUrl: movie.posterUrl,
      voteAverage: movie.voteAverage,
      year: movie.releaseDate.isNotEmpty ? movie.releaseDate.split('-')[0] : '',
      overview: movie.overview,
      additionalInfo: movie.cast.isNotEmpty
          ? 'Cast: ${movie.cast.take(3).join(', ')}'
          : null,
      isWatched: item.isWatched,
      type: 'Movie',
      onTap: () => _navigateToMovieDetail(movie),
      onRemove: () => _showRemoveDialog(item),
      index: index,
    );
  }

  Widget _buildShowCard(SavedItem item, int index) {
    final show = item.data as SavedTvShow;
    return _buildItemCard(
      id: item.id,
      title: show.name,
      posterUrl: show.posterUrl,
      voteAverage: show.voteAverage,
      year: show.firstAirDate.isNotEmpty ? show.firstAirDate.split('-')[0] : '',
      overview: show.overview,
      additionalInfo: show.originalName != show.name
          ? 'Original: ${show.originalName}'
          : null,
      isWatched: item.isWatched,
      type: 'TV Show',
      onTap: () => _navigateToShowDetail(show),
      onRemove: () => _showRemoveDialog(item),
      index: index,
    );
  }

  Widget _buildItemCard({
    required String id,
    required String title,
    required String posterUrl,
    required double voteAverage,
    required String year,
    required String overview,
    required String? additionalInfo,
    required bool isWatched,
    required String type,
    required VoidCallback onTap,
    required VoidCallback onRemove,
    required int index,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[900]!.withOpacity(0.6),
            Colors.grey[900]!.withOpacity(0.3),
          ],
        ),
        border: Border.all(
          color: Colors.grey[800]!.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Enhanced Poster
                Hero(
                  tag: 'saved_$id',
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: type == 'Movie'
                                  ? Colors.blue.withOpacity(0.3)
                                  : Colors.purple.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: posterUrl,
                            width: 100,
                            height: 150,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 100,
                              height: 150,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.grey[800]!,
                                    Colors.grey[900]!,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 100,
                              height: 150,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.grey[800]!,
                                    Colors.grey[900]!,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Icon(
                                type == 'Movie'
                                    ? Icons.movie_rounded
                                    : Icons.live_tv_rounded,
                                color: Colors.grey[600],
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isWatched)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.green, Colors.teal],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'WATCHED',
                                  style: GoogleFonts.nunito(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),

                // Enhanced Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        title,
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: type == 'Movie'
                                ? [
                                    Colors.blue.withOpacity(0.3),
                                    Colors.blue.withOpacity(0.1),
                                  ]
                                : [
                                    Colors.purple.withOpacity(0.3),
                                    Colors.purple.withOpacity(0.1),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: type == 'Movie'
                                ? Colors.blue.withOpacity(0.5)
                                : Colors.purple.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              type == 'Movie'
                                  ? Icons.movie_rounded
                                  : Icons.live_tv_rounded,
                              color: type == 'Movie'
                                  ? Colors.blue
                                  : Colors.purple,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              type,
                              style: GoogleFonts.nunito(
                                color: type == 'Movie'
                                    ? Colors.blue
                                    : Colors.purple,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Rating and Year
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.amber.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  voteAverage.toStringAsFixed(1),
                                  style: GoogleFonts.nunito(
                                    color: Colors.amber,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (year.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    color: Colors.blue,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    year,
                                    style: GoogleFonts.nunito(
                                      color: Colors.blue,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Overview
                      if (overview.isNotEmpty)
                        Text(
                          overview,
                          style: GoogleFonts.nunito(
                            color: Colors.grey[400],
                            fontSize: 13,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                      if (additionalInfo != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          additionalInfo,
                          style: GoogleFonts.nunito(
                            color: Colors.grey[500],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Remove Button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: IconButton(
                    onPressed: onRemove,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                    tooltip: 'Remove',
                    iconSize: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRemoveDialog(SavedItem item) {
    final title = item.type == SavedItemType.movie
        ? (item.data as SavedMovie).title
        : (item.data as SavedTvShow).name;
    final typeStr = item.type == SavedItemType.movie ? 'movie' : 'show';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red, Colors.orange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Remove ${item.type == SavedItemType.movie ? 'Movie' : 'Show'}?',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "$title" from your saved $typeStr?',
          style: GoogleFonts.nunito(
            color: Colors.grey[300],
            fontSize: 15,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.nunito(
                color: Colors.grey[400],
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red, Colors.orange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                _removeSavedItem(item);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Remove',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToMovieDetail(SavedMovie savedMovie) async {
    final movie = Movie(
      id: int.parse(savedMovie.id),
      title: savedMovie.title,
      overview: savedMovie.overview,
      posterPath: _extractPath(savedMovie.posterUrl),
      backdropPath: _extractPath(savedMovie.backdropUrl),
      releaseDate: savedMovie.releaseDate,
      voteAverage: savedMovie.voteAverage,
      originalTitle: savedMovie.title,
      originalLanguage: 'en',
      runtime: null,
      voteCount: 0,
      genreIds: [],
    );

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MovieDetailScreen(movie: movie)),
    );

    _loadSavedItems();
  }

  void _navigateToShowDetail(SavedTvShow savedShow) async {
    final show = TvShow(
      id: int.parse(savedShow.id),
      name: savedShow.name,
      originalName: savedShow.originalName,
      overview: savedShow.overview,
      posterPath: _extractPath(savedShow.posterUrl),
      backdropPath: _extractPath(savedShow.backdropUrl),
      firstAirDate: savedShow.firstAirDate,
      voteCount: 1,
      voteAverage: savedShow.voteAverage,
      originalLanguage: savedShow.originalLanguage,
      imdbId: '2',
    );

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ShowDetailScreen(show: show)),
    );

    _loadSavedItems();
  }

  String _extractPath(String fullUrl) {
    if (fullUrl.contains('image.tmdb.org')) {
      final parts = fullUrl.split('/');
      return '/${parts.last}';
    }
    return fullUrl;
  }
}
