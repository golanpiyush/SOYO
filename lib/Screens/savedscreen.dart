import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soyo/models/moviemodel.dart';
import 'package:soyo/Screens/movieDetailScreen.dart';
import 'package:soyo/models/savedmoviesmodel.dart';

class SavedScreen extends StatefulWidget {
  @override
  _SavedScreenState createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen>
    with TickerProviderStateMixin {
  List<SavedMovie> _savedMovies = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadSavedMovies();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedMovies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMoviesJson = prefs.getStringList('saved_movies') ?? [];

      setState(() {
        _savedMovies = savedMoviesJson
            .map((json) => SavedMovie.fromJson(jsonDecode(json)))
            .toList();
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading saved movies: $e');
    }
  }

  Future<void> _removeSavedMovie(String movieId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMoviesJson = prefs.getStringList('saved_movies') ?? [];

      savedMoviesJson.removeWhere((json) {
        final movie = SavedMovie.fromJson(jsonDecode(json));
        return movie.id == movieId;
      });

      await prefs.setStringList('saved_movies', savedMoviesJson);

      setState(() {
        _savedMovies.removeWhere((movie) => movie.id == movieId);
      });

      _showSnackBar('Movie removed from saved list', Colors.orange);
    } catch (e) {
      _showSnackBar('Failed to remove movie', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.red ? Icons.error_outline : Icons.info_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.nunito(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.lightGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: Text(
          'Saved Movies',
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            )
          : _savedMovies.isEmpty
          ? _buildEmptyState()
          : FadeTransition(
              opacity: _fadeAnimation,
              child: _buildSavedMoviesList(),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border, size: 80, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No Saved Movies',
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start saving movies to watch later!',
            style: GoogleFonts.nunito(color: Colors.grey[400], fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSavedMoviesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _savedMovies.length,
      itemBuilder: (context, index) {
        final movie = _savedMovies[index];
        return _buildMovieCard(movie, index);
      },
    );
  }

  Widget _buildMovieCard(SavedMovie movie, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: InkWell(
        onTap: () => _navigateToMovieDetail(movie),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Movie Poster
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: movie.posterUrl,
                  width: 80,
                  height: 120,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 80,
                    height: 120,
                    color: Colors.grey[800],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 80,
                    height: 120,
                    color: Colors.grey[800],
                    child: const Icon(Icons.movie, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Movie Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title,
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Rating and Year
                    Row(
                      children: [
                        Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          movie.voteAverage.toStringAsFixed(1),
                          style: GoogleFonts.nunito(
                            color: Colors.amber,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (movie.releaseDate.isNotEmpty) ...[
                          Icon(
                            Icons.calendar_today_rounded,
                            color: Colors.blue,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            movie.releaseDate.split('-')[0],
                            style: GoogleFonts.nunito(
                              color: Colors.blue,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Overview
                    if (movie.overview.isNotEmpty)
                      Text(
                        movie.overview,
                        style: GoogleFonts.nunito(
                          color: Colors.grey[400],
                          fontSize: 13,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),

                    const SizedBox(height: 12),

                    // Cast info if available
                    if (movie.cast.isNotEmpty) ...[
                      Text(
                        'Cast: ${movie.cast.take(3).join(', ')}',
                        style: GoogleFonts.nunito(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Remove button
              IconButton(
                onPressed: () => _showRemoveDialog(movie),
                icon: const Icon(Icons.close, color: Colors.red),
                tooltip: 'Remove from saved',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRemoveDialog(SavedMovie movie) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Remove Movie',
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to remove "${movie.title}" from your saved movies?',
          style: GoogleFonts.nunito(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.nunito(color: Colors.grey[400]),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeSavedMovie(movie.id);
            },
            child: Text('Remove', style: GoogleFonts.nunito(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _navigateToMovieDetail(SavedMovie savedMovie) async {
    // Convert SavedMovie back to Movie object
    final movie = Movie(
      id: int.parse(savedMovie.id),
      title: savedMovie.title,
      overview: savedMovie.overview,
      posterPath: _extractPath(savedMovie.posterUrl),
      backdropPath: _extractPath(savedMovie.backdropUrl),
      releaseDate: savedMovie.releaseDate,
      voteAverage: savedMovie.voteAverage,
      originalTitle: savedMovie.title,
      originalLanguage: 'en', // Default
      runtime: null, // Will be loaded in detail screen
      voteCount: 0, // Default value since we don't store this
      genreIds: [], // Default empty list since we don't store this
    );

    // Navigate to movie detail screen and refresh saved movies when returning
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MovieDetailScreen(movie: movie)),
    );

    // Refresh the saved movies list when returning from detail screen
    _loadSavedMovies();
  }

  String _extractPath(String fullUrl) {
    // Extract the path from full TMDB URL
    if (fullUrl.contains('image.tmdb.org')) {
      final parts = fullUrl.split('/');
      return '/${parts.last}';
    }
    return fullUrl;
  }
}
