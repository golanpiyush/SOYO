import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:soyo/Screens/movieDetailscreen.dart';
import 'package:soyo/Services/exploreapi.dart';
import 'package:soyo/models/moviemodel.dart';
import 'package:intl/intl.dart';

class GenreMoviesScreen extends StatefulWidget {
  final String genreName;
  final int genreId;
  final List<Color> gradientColors;

  const GenreMoviesScreen({
    Key? key,
    required this.genreName,
    required this.genreId,
    required this.gradientColors,
  }) : super(key: key);

  @override
  _GenreMoviesScreenState createState() => _GenreMoviesScreenState();
}

class _GenreMoviesScreenState extends State<GenreMoviesScreen> {
  List<Movie> movies = [];
  int currentPage = 1;
  String _sortBy = 'newest';
  List<Movie> _allMovies = [];
  bool isLoading = false;
  bool hasMore = true;
  String errorMessage = '';
  ScrollController _scrollController = ScrollController();
  TextEditingController _searchController = TextEditingController();
  List<Movie> searchResults = [];
  bool isSearching = false;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchMovies();
    _scrollController.addListener(_scrollListener);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMore();
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        isSearching = false;
        searchQuery = '';
        searchResults.clear();
      });
    } else if (query != searchQuery) {
      setState(() {
        searchQuery = query;
        isSearching = true;
      });
      _performSearch(query);
    }
  }

  Future<void> _performSearch(String query) async {
    try {
      final result = await ExploreApi.searchMovies(query);
      final searchMovies = (result['results'] as List)
          .map((movie) => Movie.fromJson(movie))
          .toList();

      setState(() {
        searchResults = _sortMovies(searchMovies);
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Search failed: $e';
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      isSearching = false;
      searchQuery = '';
      searchResults.clear();
    });
  }

  Future<void> _fetchMovies() async {
    try {
      setState(() {
        isLoading = true;
      });

      Map<String, dynamic> result;

      // Handle special cases
      if (widget.genreId == -1) {
        // Upcoming movies
        result = await ExploreApi.getUpcomingMovies(page: currentPage);
      } else if (widget.genreId == 0) {
        // Popular movies
        result = await ExploreApi.getPopularMovies(page: currentPage);
      } else if (widget.genreId == 1) {
        // Top Rated movies
        result = await ExploreApi.getTopRatedMovies(page: currentPage);
      } else {
        // Genre-specific movies
        result = await ExploreApi.getMoviesByGenre(
          widget.genreId,
          page: currentPage,
        );
      }

      setState(() {
        _allMovies = (result['results'] as List)
            .map((movie) => Movie.fromJson(movie))
            .toList();
        movies = _sortMovies(_allMovies);
        isLoading = false;
        hasMore = currentPage < (result['total_pages'] ?? 1);
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load movies: $e';
        isLoading = false;
      });
    }
  }

  List<Movie> _sortMovies(List<Movie> moviesToSort) {
    return List.from(moviesToSort)..sort((a, b) {
      final dateA = DateTime.tryParse(a.releaseDate) ?? DateTime(0);
      final dateB = DateTime.tryParse(b.releaseDate) ?? DateTime(0);

      if (widget.genreId == -1) {
        // For upcoming movies, sort by release date (soonest first by default)
        return _sortBy == 'newest'
            ? dateB.compareTo(dateA)
            : dateA.compareTo(dateB);
      } else {
        // For other movies, sort by release date (newest first by default)
        return _sortBy == 'newest'
            ? dateB.compareTo(dateA)
            : dateA.compareTo(dateB);
      }
    });
  }

  Future<void> _loadMore() async {
    if (isLoading || !hasMore) return;

    try {
      setState(() {
        isLoading = true;
      });

      final nextPage = currentPage + 1;
      Map<String, dynamic> result;

      // Handle special cases
      if (widget.genreId == -1) {
        result = await ExploreApi.getUpcomingMovies(page: nextPage);
      } else if (widget.genreId == 0) {
        result = await ExploreApi.getPopularMovies(page: nextPage);
      } else if (widget.genreId == 1) {
        result = await ExploreApi.getTopRatedMovies(page: nextPage);
      } else {
        result = await ExploreApi.getMoviesByGenre(
          widget.genreId,
          page: nextPage,
        );
      }

      setState(() {
        final newMovies = (result['results'] as List)
            .map((movie) => Movie.fromJson(movie))
            .toList();

        _allMovies.addAll(newMovies);
        movies = _sortMovies(_allMovies);
        currentPage = nextPage;
        isLoading = false;
        hasMore = currentPage < (result['total_pages'] ?? 1);
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load more movies: $e';
        isLoading = false;
      });
    }
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.nunito(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search movies...',
          hintStyle: GoogleFonts.nunito(
            color: Colors.white.withOpacity(0.5),
            fontSize: 16,
          ),
          prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
          suffixIcon: isSearching
              ? GestureDetector(
                  onTap: _clearSearch,
                  child: Icon(
                    Icons.clear,
                    color: Colors.white.withOpacity(0.7),
                  ),
                )
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30), // more rounded
            borderSide: BorderSide.none, // remove border for minimal look
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: widget.gradientColors[0], width: 1.5),
          ),
        ),
      ),
    );
  }

  void _onMovieCardTap(Movie movie) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            MovieDetailScreen(movie: movie),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: Offset(1.0, 0.0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          );
        },
        transitionDuration: Duration(milliseconds: 300),
      ),
    );
  }

  Widget _buildMovieCard(Movie movie, int index) {
    final isUpcoming = widget.genreId == -1;
    final releaseDate = movie.releaseDate;
    final currentDate = DateTime.now();

    // Format the date with coming/released status
    String formattedDate = 'Coming soon';
    String statusText = 'Coming soon';

    if (releaseDate.isNotEmpty) {
      final date = DateTime.tryParse(releaseDate);
      if (date != null) {
        final dateString = DateFormat('MMM dd, yyyy').format(date);
        formattedDate = dateString;

        // Check if movie is released or upcoming
        if (date.isBefore(currentDate) || date.isAtSameMomentAs(currentDate)) {
          statusText = 'Recently Released $dateString';
        } else {
          statusText = 'Coming on $dateString';
        }
      } else {
        formattedDate = releaseDate;
        statusText = 'Coming soon';
      }
    }

    return GestureDetector(
      onTap: () => _onMovieCardTap(movie),
      child: Container(
        width: 140,
        margin: EdgeInsets.only(left: 20, right: index % 2 == 1 ? 20 : 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'movie-${movie.id}',
              child: Container(
                height: 190,
                width: 140,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: widget.gradientColors[0].withOpacity(0.3),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                            spreadRadius: -5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(
                          movie.posterUrl,
                          fit: BoxFit.cover,
                          width: 140,
                          height: 190,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.grey.shade900,
                                    Colors.grey.shade800,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: widget.gradientColors[0],
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.grey.shade900,
                                    Colors.grey.shade800,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.movie,
                                  color: Colors.white.withOpacity(0.3),
                                  size: 40,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 12),
                            SizedBox(width: 2),
                            Text(
                              movie.voteAverage.toStringAsFixed(1),
                              style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Release date badge for upcoming movies
                    if (isUpcoming && releaseDate.isNotEmpty)
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: widget.gradientColors[0].withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            formattedDate.split(
                              ' ',
                            )[0], // Just show month abbreviation
                            style: GoogleFonts.nunito(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),
            Text(
              movie.title,
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            // Release date below title with status
            if (releaseDate.isNotEmpty)
              Text(
                statusText,
                style: GoogleFonts.nunito(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0A0A),
              Color(0xFF1A0A1A),
              Color(0xFF0A1A2A),
              Color(0xFF000000),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              _buildSearchBar(),
              Expanded(
                child: movies.isEmpty && isLoading
                    ? _buildLoading()
                    : errorMessage.isNotEmpty
                    ? _buildErrorState()
                    : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    String subtitle;

    if (widget.genreId == -1) {
      subtitle = 'Coming soon to theaters';
    } else if (widget.genreId == 0) {
      subtitle = 'Most popular movies';
    } else if (widget.genreId == 1) {
      subtitle = 'Highest rated movies';
    } else {
      subtitle = 'Browse all movies';
    }

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withOpacity(0.3),
                    Colors.purple.withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Icon(Icons.arrow_back, color: Colors.white, size: 24),
            ),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      Colors.white,
                      widget.gradientColors[0].withOpacity(0.8),
                    ],
                  ).createShader(bounds),
                  child: Text(
                    widget.genreName,
                    style: GoogleFonts.nunito(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          // Filter button
          _buildFilterButton(),
          SizedBox(width: 10),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: widget.gradientColors),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.movie, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    return PopupMenuButton<String>(
      onSelected: (value) {
        setState(() {
          _sortBy = value;
          movies = _sortMovies(_allMovies);
        });
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem(
          value: 'newest',
          child: Row(
            children: [
              Icon(
                Icons.arrow_downward,
                color: _sortBy == 'newest'
                    ? widget.gradientColors[0]
                    : Colors.grey,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Newest First',
                style: GoogleFonts.nunito(
                  color: _sortBy == 'newest' ? Colors.white : Colors.grey,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'oldest',
          child: Row(
            children: [
              Icon(
                Icons.arrow_upward,
                color: _sortBy == 'oldest'
                    ? widget.gradientColors[0]
                    : Colors.grey,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Oldest First',
                style: GoogleFonts.nunito(
                  color: _sortBy == 'oldest' ? Colors.white : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Icon(
          _sortBy == 'newest' ? Icons.arrow_downward : Icons.arrow_upward,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: CircularProgressIndicator(color: widget.gradientColors[0]),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: EdgeInsets.all(30),
        padding: EdgeInsets.all(30),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.withOpacity(0.1), Colors.red.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 60),
            SizedBox(height: 20),
            Text(
              errorMessage,
              style: GoogleFonts.nunito(color: Colors.white, fontSize: 16),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchMovies,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final moviesToShow = isSearching ? searchResults : movies;

    if (isSearching && searchResults.isEmpty && searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 60,
              color: Colors.white.withOpacity(0.3),
            ),
            SizedBox(height: 20),
            Text(
              'No movies found for "$searchQuery"',
              style: GoogleFonts.nunito(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (!isLoading &&
            hasMore &&
            !isSearching && // Don't load more when searching
            scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          _loadMore();
        }
        return true;
      },
      child: Column(
        children: [
          Expanded(
            child: GridView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(20),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
                crossAxisSpacing: 10,
                mainAxisSpacing: 20,
              ),
              itemCount:
                  moviesToShow.length + (!isSearching && hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < moviesToShow.length) {
                  return _buildMovieCard(moviesToShow[index], index);
                } else {
                  return _buildLoadMoreButton();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Center(
        child: isLoading
            ? CircularProgressIndicator(color: widget.gradientColors[0])
            : ElevatedButton(
                onPressed: _loadMore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.gradientColors[0],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  'Load More',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
                ),
              ),
      ),
    );
  }
}
