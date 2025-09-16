import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:soyo/Screens/movieDetailscreen.dart';
import 'package:soyo/Services/collections_api.dart';
import 'package:soyo/Services/hindimovies_api.dart';
import 'package:soyo/models/moviemodel.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HindiMoviesScreen extends StatefulWidget {
  const HindiMoviesScreen({Key? key}) : super(key: key);

  @override
  _HindiMoviesScreenState createState() => _HindiMoviesScreenState();
}

class _HindiMoviesScreenState extends State<HindiMoviesScreen> {
  HindiMoviesApi _hindiMoviesApi = HindiMoviesApi();
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

  // Hindi movies gradient colors
  final List<Color> gradientColors = [Colors.orange, Colors.red];

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
      final searchMovies = await _hindiMoviesApi.searchHindiMovies(
        query,
        limit: 50,
      );

      // Filter to only Hindi movies if possible
      final hindiMovies = searchMovies.where((movie) {
        return movie.title.toLowerCase().contains(query.toLowerCase());
      }).toList();

      setState(() {
        searchResults = _sortMovies(hindiMovies);
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
        errorMessage = '';
      });

      final result = await _hindiMoviesApi.getHindiMovies(
        limit: 20,
        page: currentPage,
        sortBy: 'created_at',
        sortOrder: 'desc',
      );

      setState(() {
        if (currentPage == 1) {
          _allMovies = result;
        } else {
          _allMovies.addAll(result);
        }
        movies = _sortMovies(_allMovies);
        isLoading = false;
        hasMore = result.length == 20; // Assume more if we got full page
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load Hindi movies: $e';
        isLoading = false;
      });
    }
  }

  List<Movie> _sortMovies(List<Movie> moviesToSort) {
    return List.from(moviesToSort)..sort((a, b) {
      final dateA = DateTime.tryParse(a.releaseDate) ?? DateTime(0);
      final dateB = DateTime.tryParse(b.releaseDate) ?? DateTime(0);

      return _sortBy == 'newest'
          ? dateB.compareTo(dateA)
          : dateA.compareTo(dateB);
    });
  }

  Future<void> _loadMore() async {
    if (isLoading || !hasMore || isSearching) return;

    try {
      setState(() {
        isLoading = true;
      });

      final nextPage = currentPage + 1;
      final result = await _hindiMoviesApi.getHindiMovies(
        limit: 20,
        page: nextPage,
        sortBy: 'created_at',
        sortOrder: 'desc',
      );

      setState(() {
        _allMovies.addAll(result);
        movies = _sortMovies(_allMovies);
        currentPage = nextPage;
        isLoading = false;
        hasMore = result.length == 20;
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
          hintText: 'Search Hindi movies...',
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
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: gradientColors[0], width: 1.5),
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
                            color: gradientColors[0].withOpacity(0.3),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                            spreadRadius: -5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: CachedNetworkImage(
                          imageUrl: movie.posterUrl,
                          fit: BoxFit.cover,
                          width: 140,
                          height: 190,
                          maxHeightDiskCache: 400,
                          maxWidthDiskCache: 300,
                          memCacheHeight: 400,
                          memCacheWidth: 300,
                          placeholder: (context, url) => Container(
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
                                color: gradientColors[0],
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.asset(
                                'assets/notfoundRaw.png',
                                fit: BoxFit.cover,
                                width: 140,
                                height: 190,
                              ),
                            ),
                          ),
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
                    // Hindi badge
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: gradientColors[0].withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Hindi',
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
            if (movie.releaseDate.isNotEmpty)
              Text(
                movie.releaseDate.length > 4
                    ? movie.releaseDate.substring(0, 4)
                    : movie.releaseDate,
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
                    colors: [Colors.white, gradientColors[0].withOpacity(0.8)],
                  ).createShader(bounds),
                  child: Text(
                    'Hindi Movies',
                    style: GoogleFonts.nunito(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                Text(
                  'Bollywood & Hindi Cinema',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          _buildFilterButton(),
          SizedBox(width: 10),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors),
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
                color: _sortBy == 'newest' ? gradientColors[0] : Colors.grey,
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
                color: _sortBy == 'oldest' ? gradientColors[0] : Colors.grey,
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
    return Center(child: CircularProgressIndicator(color: gradientColors[0]));
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
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  currentPage = 1;
                  errorMessage = '';
                });
                _fetchMovies();
              },
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
              'No Hindi movies found for "$searchQuery"',
              style: GoogleFonts.nunito(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (!isLoading &&
            hasMore &&
            !isSearching &&
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
            ? CircularProgressIndicator(color: gradientColors[0])
            : ElevatedButton(
                onPressed: _loadMore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: gradientColors[0],
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
