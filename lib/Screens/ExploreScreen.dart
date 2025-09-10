import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:soyo/Screens/ExploreShows.dart';
import 'package:soyo/Screens/movieDetailscreen.dart';
import 'package:soyo/Screens/playerScreen.dart';
import 'package:soyo/Services/exploreapi.dart';
import 'package:soyo/Services/m3u8api.dart';
import 'package:soyo/models/moviemodel.dart';

class ExploreScreen extends StatefulWidget {
  @override
  _ExploreScreenState createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with TickerProviderStateMixin {
  List<Movie> popularMovies = [];
  List<Movie> topRatedMovies = [];
  List<Movie> horrorMovies = [];
  List<Movie> actionMovies = [];
  List<Movie> scifiMovies = [];
  List<Movie> comedyMovies = [];
  List<Movie> thrillerMovies = [];
  List<Movie> tvMovieMovies = [];
  List<Movie> mysteryMovies = [];
  List<Movie> crimeMovies = [];
  List<Movie> animationMovies = [];
  List<Movie> adventureMovies = [];
  bool isLoading = true;
  String errorMessage = '';
  bool _isSearching = false;
  String _searchingMovieTitle = '';
  final M3U8Api _api = M3U8Api();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _shimmerController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _fetchAllData();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutQuart),
    );

    _slideAnimation = Tween<Offset>(begin: Offset(0.0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _shimmerAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Fetch all data in parallel
      final results = await Future.wait([
        ExploreApi.getPopularMovies(),
        ExploreApi.getTopRatedMovies(),
        ExploreApi.getMoviesByGenre(27), // Horror
        ExploreApi.getMoviesByGenre(28), // Action
        ExploreApi.getMoviesByGenre(878), // Sci-Fi
        ExploreApi.getMoviesByGenre(35), // Comedy
        ExploreApi.getMoviesByGenre(53), // Thriller
        ExploreApi.getMoviesByGenre(10770), // TV Movie
        ExploreApi.getMoviesByGenre(9648), // Mystery
        ExploreApi.getMoviesByGenre(80), // Crime
        ExploreApi.getMoviesByGenre(16), // Animation
        ExploreApi.getMoviesByGenre(12), // Adventure
      ]);

      setState(() {
        popularMovies = (results[0]['results'] as List)
            .map((movie) => Movie.fromJson(movie))
            .toList();

        topRatedMovies = (results[1]['results'] as List)
            .map((movie) => Movie.fromJson(movie))
            .toList();

        horrorMovies = (results[2]['results'] as List)
            .map((movie) => Movie.fromJson(movie))
            .toList();

        actionMovies = (results[3]['results'] as List)
            .map((movie) => Movie.fromJson(movie))
            .toList();

        scifiMovies = (results[4]['results'] as List)
            .map((movie) => Movie.fromJson(movie))
            .toList();

        comedyMovies = (results[5]['results'] as List)
            .map((movie) => Movie.fromJson(movie))
            .toList();

        thrillerMovies = (results[6]['results'] as List)
            .map((movie) => Movie.fromJson(movie))
            .toList();

        tvMovieMovies = (results[7]['results'] as List)
            .map((movie) => Movie.fromJson(movie))
            .toList();

        mysteryMovies = (results[8]['results'] as List)
            .map((movie) => Movie.fromJson(movie))
            .toList();

        crimeMovies = (results[9]['results'] as List)
            .map((movie) => Movie.fromJson(movie))
            .toList();

        animationMovies = (results[10]['results'] as List)
            .map((movie) => Movie.fromJson(movie))
            .toList();

        adventureMovies = (results[11]['results'] as List)
            .map((movie) => Movie.fromJson(movie))
            .toList();

        isLoading = false;
      });

      // Trigger animations after data loads
      _fadeController.forward();
      _slideController.forward();
      _scaleController.forward();
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load data: $e';
        isLoading = false;
      });
    }
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
              _buildAnimatedAppBar(),
              Expanded(
                child: isLoading
                    ? _buildShimmerLoading()
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

  Widget _buildAnimatedAppBar() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ExploreShows(), // Make sure to import exploreshows.dart
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.withOpacity(0.3),
                        Colors.purple.withOpacity(0.3),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Icon(Icons.explore, color: Colors.white, size: 24),
                ),
              ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [Colors.white, Colors.red.shade300],
                      ).createShader(bounds),
                      child: Text(
                        'Explore',
                        style: GoogleFonts.nunito(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    Text(
                      'Discover amazing content',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return SingleChildScrollView(
          child: Column(
            children: List.generate(6, (sectionIndex) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        height: 24,
                        width: 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            begin: Alignment(
                              -1.0 + _shimmerAnimation.value,
                              0.0,
                            ),
                            end: Alignment(1.0 + _shimmerAnimation.value, 0.0),
                            colors: [
                              Colors.white.withOpacity(0.1),
                              Colors.white.withOpacity(0.3),
                              Colors.white.withOpacity(0.1),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 15),
                    Container(
                      height: 220,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: 5,
                        itemBuilder: (context, index) {
                          return Container(
                            width: 140,
                            margin: EdgeInsets.only(left: 20),
                            child: Column(
                              children: [
                                Container(
                                  height: 180,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    gradient: LinearGradient(
                                      begin: Alignment(
                                        -1.0 + _shimmerAnimation.value,
                                        -1.0,
                                      ),
                                      end: Alignment(
                                        1.0 + _shimmerAnimation.value,
                                        1.0,
                                      ),
                                      colors: [
                                        Colors.white.withOpacity(0.1),
                                        Colors.white.withOpacity(0.3),
                                        Colors.white.withOpacity(0.1),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Container(
                                  height: 16,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    gradient: LinearGradient(
                                      begin: Alignment(
                                        -1.0 + _shimmerAnimation.value,
                                        0.0,
                                      ),
                                      end: Alignment(
                                        1.0 + _shimmerAnimation.value,
                                        0.0,
                                      ),
                                      colors: [
                                        Colors.white.withOpacity(0.1),
                                        Colors.white.withOpacity(0.2),
                                        Colors.white.withOpacity(0.1),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: EdgeInsets.all(30),
          padding: EdgeInsets.all(30),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.red.withOpacity(0.1),
                Colors.red.withOpacity(0.05),
              ],
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
                onPressed: _fetchAllData,
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
      ),
    );
  }

  Widget _buildContent() {
    final sections = [
      {
        'title': 'Popular',
        'movies': popularMovies,
        'gradient': [Colors.red, Colors.pink],
      },
      {
        'title': 'Top Rated',
        'movies': topRatedMovies,
        'gradient': [Colors.amber, Colors.orange],
      },
      {
        'title': 'Horror',
        'movies': horrorMovies,
        'gradient': [Colors.purple, Colors.deepPurple],
      },
      {
        'title': 'Action',
        'movies': actionMovies,
        'gradient': [Colors.red, Colors.deepOrange],
      },
      {
        'title': 'Sci-Fi',
        'movies': scifiMovies,
        'gradient': [Colors.blue, Colors.cyan],
      },
      {
        'title': 'Comedy',
        'movies': comedyMovies,
        'gradient': [Colors.green, Colors.lightGreen],
      },
      {
        'title': 'Thriller',
        'movies': thrillerMovies,
        'gradient': [Colors.grey, Colors.blueGrey],
      },
      {
        'title': 'TV Movies',
        'movies': tvMovieMovies,
        'gradient': [Colors.indigo, Colors.blue],
      },
      {
        'title': 'Mystery',
        'movies': mysteryMovies,
        'gradient': [Colors.deepPurple, Colors.purple],
      },
      {
        'title': 'Crime',
        'movies': crimeMovies,
        'gradient': [Colors.red.shade800, Colors.red.shade600],
      },
      {
        'title': 'Animation',
        'movies': animationMovies,
        'gradient': [Colors.pink, Colors.purple],
      },
      {
        'title': 'Adventure',
        'movies': adventureMovies,
        'gradient': [Colors.teal, Colors.green],
      },
    ];

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Column(
            children: sections.asMap().entries.map((entry) {
              int index = entry.key;
              Map<String, dynamic> section = entry.value;

              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 300 + (index * 100)),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 50 * (1 - value)),
                    child: Opacity(
                      opacity: value,
                      child: _buildSection(
                        section['title'],
                        section['movies'],
                        section['gradient'],
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    String title,
    List<Movie> movies,
    List<Color> gradientColors,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        Colors.white,
                        gradientColors[0].withOpacity(0.8),
                      ],
                    ).createShader(bounds),
                    child: Text(
                      title,
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradientColors),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${movies.length}',
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 15),
          Container(
            height: 250,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: BouncingScrollPhysics(),
              itemCount: movies.length,
              itemBuilder: (context, index) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 300 + (index * 50)),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.8 + (0.2 * value),
                      child: _buildMovieCard(
                        movies[index],
                        index,
                        movies.length,
                        gradientColors,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieCard(
    Movie movie,
    int index,
    int totalItems,
    List<Color> gradientColors,
  ) {
    return GestureDetector(
      onTap: () => _onMovieCardTap(movie),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        width: 140,
        margin: EdgeInsets.only(
          left: 20,
          right: index == totalItems - 1 ? 20 : 0,
        ),
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
                                  color: gradientColors[0],
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

                    // Gradient overlay
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

                    // Rating badge
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

                    // Play button overlay when searching
                    if (_isSearching && _searchingMovieTitle == movie.title)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: gradientColors,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Loading...',
                                style: GoogleFonts.nunito(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 12),

            // Movie title
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
          ],
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

  void _showPlayDialog(Movie movie, Map<String, dynamic> result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ScaleTransition(
        scale: CurvedAnimation(
          parent: AnimationController(
            duration: Duration(milliseconds: 300),
            vsync: this,
          )..forward(),
          curve: Curves.elasticOut,
        ),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(25),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey.shade900.withOpacity(0.95),
                  Colors.black.withOpacity(0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red, Colors.red.shade700],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        movie.title,
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20),

                Container(
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Stream found! Ready to play.',
                          style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (result['subtitles'] != null &&
                    (result['subtitles'] as List).isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(top: 10),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.subtitles, color: Colors.blue, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Subtitles available',
                          style: GoogleFonts.nunito(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                SizedBox(height: 25),

                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.nunito(
                            color: Colors.grey,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red, Colors.red.shade700],
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              blurRadius: 15,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _playMovie(movie, result);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          icon: Icon(Icons.play_arrow, size: 20),
                          label: Text(
                            'Play Now',
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
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

  void _playMovie(Movie movie, Map<String, dynamic> result) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            SimpleStreamPlayer(
              streamUrl: result['m3u8_link'],
              movieTitle: movie.title,
              subtitleUrls: result['subtitles'] != null
                  ? List<String>.from(result['subtitles'])
                  : null,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: Offset(0.0, 1.0), end: Offset.zero)
                  .animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            ),
          );
        },
        transitionDuration: Duration(milliseconds: 400),
      ),
    );
  }
}
