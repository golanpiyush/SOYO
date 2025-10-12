import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soyo/Screens/animedetails.dart';
import 'package:provider/provider.dart';
import 'package:soyo/Screens/collectionDetailScreen.dart';
import 'package:soyo/Screens/hindimoviesScreen.dart';
import 'package:soyo/Screens/javDetailsScreen.dart';
import 'package:soyo/Screens/moreJavs.dart';
import 'package:soyo/Screens/moviechatscreen.dart';
import 'package:soyo/Screens/moviecollectionscreen.dart';
import 'package:soyo/Screens/playerScreen.dart';
import 'package:soyo/Screens/movieDetailScreen.dart';
import 'package:soyo/Screens/pondoScreen.dart';
import 'package:soyo/Screens/xhamsterallcategory.dart';
import 'package:soyo/Services/Providers/settings_provider.dart';
import 'package:soyo/Services/anime_collection_api.dart';
import 'package:soyo/Services/hindimovies_api.dart';
import 'package:soyo/Services/javScrapper.dart';
import 'package:soyo/Services/m3u8api.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:soyo/Services/xhamsterservices.dart';
import 'package:soyo/models/anime_model.dart';
import 'package:soyo/models/javData.dart';
import 'package:soyo/models/moviecollections.dart';
import 'package:soyo/models/moviemodel.dart';
import 'package:soyo/Services/collections_api.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _movieController = TextEditingController();
  final M3U8Api _api = M3U8Api();
  final XHamsterService _service = XHamsterService();
  HindiMoviesApi _hindiMoviesApi = HindiMoviesApi();
  bool _isLoading = false;
  Map<String, dynamic>? _searchResult;
  List<Movie> _searchResults = [];
  bool _showMultipleResults = false;
  String _searchStatus = '';
  List<MovieCollection> _movieCollections = [];
  bool _collectionsLoading = true;

  List<Movie> _hindiMovies = [];
  bool _hindiMoviesLoading = true;
  AnimeCollectionApi _animeApi = AnimeCollectionApi();
  List<Anime> _animeList = [];
  bool _animeLoading = true;

  // Collections data - now supports streaming
  Map<String, List<Movie>> _collections = {};
  Map<String, bool> _collectionLoading = {
    'Apple TV+': true,
    'Prime Video': true,
    'Netflix': true,
    'Disney+': true,
  };
  String _errorMessage = '';

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _shimmerController;
  late AnimationController _searchController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _searchAnimation;

  // JAV Scraper variables
  JAVScraper _javScraper = JAVScraper();
  List<JAVVideo> _javVideos = [];
  bool _javLoading = true;
  List<XHamsterCategory> _xhamsterCategories = [];
  bool _xhamsterLoading = true;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadHindiMovies();
    _loadAnime();
    _loadCollectionsStreaming();
    _loadMovieCollections(); // Add this line
    // _loadJAVVideos();
    _loadXHamsterCategories();
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

    _searchController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

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

    _searchAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _searchController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _shimmerController.dispose();
    _searchController.dispose();
    _movieController.dispose();
    _animeApi.dispose();
    super.dispose();
  }

  Future<void> _loadMovieCollections() async {
    try {
      setState(() {
        _collectionsLoading = true;
      });

      final collections = await CollectionsApiService.getPopularCollections();

      setState(() {
        _movieCollections = collections;
        _collectionsLoading = false;
      });
    } catch (e) {
      setState(() {
        _collectionsLoading = false;
      });
      print('Error loading movie collections: $e');
    }
  }

  Future<void> _loadAnime() async {
    try {
      setState(() {
        _animeLoading = true;
      });

      final animeResponse = await _animeApi.getPopularAnime(page: 1);

      setState(() {
        _animeList = animeResponse.results;
        _animeLoading = false;
      });
    } catch (e) {
      setState(() {
        _animeLoading = false;
      });
      print('Error loading anime: $e');
    }
  }

  Future<void> _loadHindiMovies() async {
    try {
      setState(() {
        _hindiMoviesLoading = true;
      });

      final movies = await _hindiMoviesApi.getLatestHindiMovies(limit: 20);

      setState(() {
        _hindiMovies = movies;
        _hindiMoviesLoading = false;
      });
    } catch (e) {
      setState(() {
        _hindiMoviesLoading = false;
      });
      print('Error loading Hindi movies: $e');
    }
  }

  // Streaming collections loading - loads each collection independently
  Future<void> _loadCollectionsStreaming() async {
    final collectionTypes = ['apple', 'prime', 'netflix', 'disney'];
    final collectionNames = ['Apple TV+', 'Prime Video', 'Netflix', 'Disney+'];

    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();

    for (int i = 0; i < collectionTypes.length; i++) {
      String type = collectionTypes[i];
      String name = collectionNames[i];

      _loadSingleCollectionStream(type, name);
    }
  }

  Future<void> _loadSingleCollectionStream(String type, String name) async {
    try {
      // Initialize empty list for this collection
      if (!_collections.containsKey(name)) {
        _collections[name] = [];
      }

      // // await for (final movie in _collectionsApi.getCollectionMoviesStream(
      //   type,
      // )) {
      //   setState(() {
      //     _collections[name]!.add(movie);
      //   });
      // }

      // Mark as fully loaded
      setState(() {
        _collectionLoading[name] = false;
      });
    } catch (e) {
      setState(() {
        _collectionLoading[name] = false;
        if (_errorMessage.isEmpty) {
          _errorMessage = 'Failed to load some collections';
        }
      });
    }
  }

  Future<void> _loadXHamsterCategories() async {
    // Get NSFW setting from provider
    final nsfwEnabled = context.read<SettingsProvider>().nsfwEnabled;

    if (!nsfwEnabled) {
      setState(() {
        _xhamsterCategories = [];
        _xhamsterLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _xhamsterLoading = true;
      });

      final categories = await _service.getCategories();

      setState(() {
        _xhamsterCategories = categories;
        _xhamsterLoading = false;
      });
    } catch (e) {
      setState(() {
        _xhamsterLoading = false;
      });
      print('Error loading xHamster categories: $e');
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
              _buildMinimalSearchBar(),
              Expanded(
                child: _isLoading
                    ? _buildLoadingSection()
                    : _showMultipleResults && _searchResults.isNotEmpty
                    ? _buildMultipleResultsSection()
                    : _searchResult != null && !_showMultipleResults
                    ? _buildResultSection()
                    : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedAppBar() {
    return GestureDetector(
      onTap: _navigateToMovieChat,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
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
                    child: const Icon(
                      Icons.home,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.white, Colors.red],
                          ).createShader(bounds),
                          child: Text(
                            'S-O-Y-O',
                            style: GoogleFonts.nunito(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        Text(
                          '~ Stream On Your Own',
                          style: GoogleFonts.caveat(
                            fontSize: 17,
                            color: Colors.white.withOpacity(0.7),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white70,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadJAVVideos() async {
    try {
      setState(() {
        _javLoading = true;
      });

      final videos = await _javScraper.scrapeMultiplePages(
        maxPages: 3,
      ); // Adjust pages as needed

      setState(() {
        _javVideos = videos;
        _javLoading = false;
      });
    } catch (e) {
      setState(() {
        _javLoading = false;
      });
      print('Error loading JAV videos: $e');
    }
  }

  void _navigateToMovieChat() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MovieChatScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  Widget _buildMinimalSearchBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 50,
              child: TextField(
                controller: _movieController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search movies or tv shows...',
                  hintStyle: GoogleFonts.cabin(color: Colors.white60),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide(color: Colors.red, width: 2),
                  ),
                  prefixIcon: Icon(Icons.search, color: Colors.white70),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                ),
                onSubmitted: (_) => _searchMovie(),
              ),
            ),
          ),
          SizedBox(width: 10),
          Container(
            height: 50,
            width: 50,
            child: _isLoading
                ? Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.red.withOpacity(0.3),
                          Colors.purple.withOpacity(0.3),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  )
                : FloatingActionButton(
                    onPressed: _searchMovie,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red, Colors.red.shade700],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.4),
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: Icon(Icons.search, color: Colors.white),
                    ),
                  ),
          ),
          SizedBox(width: 10),
          Container(
            height: 50,
            width: 50,
            child: FloatingActionButton(
              onPressed: _isLoading ? null : _searchMultipleMovies,
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isLoading
                        ? [Colors.grey, Colors.grey.shade600]
                        : [Colors.purple, Colors.purple.shade700],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isLoading ? Colors.grey : Colors.purple)
                          .withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Icon(Icons.grid_view, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.red),
          SizedBox(height: 15),
          Text(
            _searchStatus.isNotEmpty ? _searchStatus : 'Searching...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final nsfwEnabled = context.watch<SettingsProvider>().nsfwEnabled;

    final sections = [
      {
        'title': 'Movie Collections',
        'isCollections': true,
        'collections': _movieCollections,
        'gradient': [Colors.deepPurple, Colors.indigo],
        'icon': 'assets/icon/collection_icon.svg',
        'loading': _collectionsLoading,
      },
      {
        'title': 'Anime Collection',
        'movies': _animeList
            .map(
              (anime) => Movie(
                id: anime.id,
                title: anime.name,
                originalTitle: anime.originalName,
                overview: anime.overview,
                posterPath: anime.posterPath ?? "",
                backdropPath: anime.backdropPath ?? "",
                releaseDate: anime.firstAirDate,
                voteAverage: anime.voteAverage,
                voteCount: anime.voteCount,
                popularity: anime.popularity,
                genreIds: anime.genreIds,
                adult: anime.adult,
                originalLanguage: anime.originalLanguage,
              ),
            )
            .toList(),
        'gradient': [Colors.purple, Colors.pink],
        'icon': 'assets/icon/anime_icon.svg',
        'loading': _animeLoading,
        'isHindiMovies': false,
        'isAnime': true,
      },
      {
        'title': 'Hindi Movies',
        'movies': _hindiMovies,
        'gradient': [Colors.orange, Colors.red],
        'icon': 'assets/icon/bollywood_icon.svg',
        'loading': _hindiMoviesLoading,
        'isHindiMovies': true,
        'isAnime': false,
      },
      // Add JAV Section here
      // {
      //   'title': 'JAV HD',
      //   'javVideos': _javVideos,
      //   'gradient': [Colors.pink, Colors.purple],
      //   'icon': 'assets/icon/jav_icon.svg', // You'll need to create this icon
      //   'loading': _javLoading,
      //   'isJAV': true, // New flag for JAV section
      // },
      if (nsfwEnabled)
        {
          'title': 'Adult Categories',
          'xhamsterCategories': _xhamsterCategories,
          'gradient': [
            const Color.fromARGB(255, 65, 204, 72),
            const Color.fromARGB(255, 21, 56, 211),
          ],
          'icon': 'assets/icon/adult_icon.svg',
          'loading': _xhamsterLoading,
          'isXHamster': true,
        },
    ];

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(
          children: [
            SizedBox(height: 10),
            ...sections.asMap().entries.map((entry) {
              int index = entry.key;
              Map<String, dynamic> section = entry.value;

              return AnimatedBuilder(
                animation: _slideController,
                builder: (context, child) {
                  // Fixed animation calculation - now all sections have full opacity
                  // Using a staggered slide animation instead of opacity reduction
                  double slideProgress = _slideController.value;
                  double staggeredDelay = (index * 0.1).clamp(0.0, 0.5);
                  double adjustedProgress = (slideProgress - staggeredDelay)
                      .clamp(0.0, 1.0);

                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - adjustedProgress)),
                    child: Opacity(
                      opacity:
                          adjustedProgress, // This ensures all sections reach full opacity
                      child: section['isCollections'] == true
                          ? _buildCollectionsSection(
                              section['title'],
                              section['collections'],
                              section['gradient'],
                              section['icon'],
                              section['loading'],
                            )
                          // : section['isJAV'] ==
                          //       true // Check for JAV section
                          // ? _buildJAVSection(
                          //     section['title'],
                          //     section['javVideos'],
                          //     section['gradient'],
                          //     section['icon'],
                          //     section['loading'],
                          //   )
                          : section['isXHamster'] == true
                          ? _buildXHamsterCategoriesSection(
                              section['title'],
                              section['xhamsterCategories'],
                              section['gradient'],
                              section['icon'],
                              section['loading'],
                            )
                          : _buildSection(
                              section['title'],
                              section['movies'],
                              section['gradient'],
                              section['icon'],
                              section['loading'],
                              section['isHindiMovies'] ?? false,
                              isAnime: section['isAnime'] ?? false,
                            ),
                    ),
                  );
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildXHamsterCategoriesSection(
    String title,
    List<XHamsterCategory> categories,
    List<Color> gradientColors,
    String iconPath,
    bool isLoading,
  ) {
    if (isLoading) {
      return _buildSectionShimmer(title, gradientColors);
    }

    if (categories.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: _navigateToAllCategories,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withOpacity(0.05),
                ),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.category_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            Colors.white,
                            gradientColors[0].withOpacity(0.9),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: gradientColors),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${categories.length}',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          Container(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: categories.length > 15 ? 15 : categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 300 + (index * 50)),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.95 + (0.05 * value),
                      child: _buildCategoryCard(
                        category,
                        index,
                        categories.length,
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

  Widget _buildCategoryCard(
    XHamsterCategory category,
    int index,
    int totalCount,
    List<Color> gradientColors,
  ) {
    final isFirst = index == 0;
    final isLast = index == totalCount - 1;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                HamsterCategoryVideosScreen(category: category),
          ),
        );
      },
      child: Container(
        width: 140,
        margin: EdgeInsets.only(left: isFirst ? 20 : 8, right: isLast ? 20 : 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors[0].withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.grey[900],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: category.coverImage,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[850],
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                gradientColors[0],
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[850],
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.grey[600],
                            size: 40,
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
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                category.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToAllCategories() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            HamsterAllCategoriesScreen(),
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

  Widget _buildJAVSection(
    String title,
    List<JAVVideo> javVideos,
    List<Color> gradientColors,
    String iconPath,
    bool isLoading,
  ) {
    if (isLoading) {
      return _buildSectionShimmer(title, gradientColors);
    }

    if (javVideos.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: _navigateToAllJAV, // Your custom navigation method
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withOpacity(0.05),
                ),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: iconPath.endsWith('.svg')
                          ? SvgPicture.asset(
                              iconPath,
                              width: 24,
                              height: 24,
                              color: Colors.white,
                            )
                          : const Icon(
                              Icons.video_library,
                              color: Colors.white,
                              size: 24,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            Colors.white,
                            gradientColors[0].withOpacity(0.9),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: gradientColors),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${javVideos.length}',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          Container(
            height: 250,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: javVideos.length,
              itemBuilder: (context, index) {
                final JAVVideo video = javVideos[index];
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 300 + (index * 50)),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.95 + (0.05 * value),
                      child: _buildJAVCard(
                        video,
                        index,
                        javVideos.length,
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

  Widget _buildJAVCard(
    JAVVideo video,
    int index,
    int totalCount,
    List<Color> gradientColors,
  ) {
    final isFirst = index == 0;
    final isLast = index == totalCount - 1;

    return GestureDetector(
      onTap: () {
        // Navigate to JAV detail screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JAVDetailScreen(video: video),
          ),
        );
      },
      child: Container(
        width: 160,
        margin: EdgeInsets.only(left: isFirst ? 20 : 8, right: isLast ? 20 : 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster container with gradient border
            Container(
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors[0].withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.grey[900],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Poster image
                      CachedNetworkImage(
                        imageUrl: video.posterUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[850],
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                gradientColors[0],
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[850],
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.grey[600],
                            size: 40,
                          ),
                        ),
                      ),

                      // Gradient overlay at bottom
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.8),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Duration badge (top-right)
                      if (video.duration.isNotEmpty)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time,
                                  color: Colors.white,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  video.duration,
                                  style: GoogleFonts.nunito(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Code badge (bottom-left)
                      if (video.code.isNotEmpty)
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: gradientColors),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: gradientColors[0].withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              video.code,
                              style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),

                      // Play icon overlay (center)
                      Center(
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),

            const SizedBox(height: 4),

            // Upload date
            if (video.uploadDate.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: Colors.grey[500],
                      size: 11,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      video.uploadDate,
                      style: GoogleFonts.nunito(
                        color: Colors.grey[500],
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
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

  void _navigateToAllJAV() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            HamsterAllCategoriesScreen(
              // preloadedVideos: _javVideos,
              // gradientColors: [Colors.pink, Colors.purple],
            ),
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

  // New method for collections section
  Widget _buildCollectionsSection(
    String title,
    List<MovieCollection> collections,
    List<Color> gradientColors,
    String iconPath,
    bool isLoading,
  ) {
    if (isLoading) {
      return _buildSectionShimmer(title, gradientColors);
    }

    if (collections.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () => _navigateToMovieCollections(),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withOpacity(0.05),
                ),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // Platform icon
                    Container(
                      width: 32,
                      height: 32,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: iconPath.endsWith('.svg')
                          ? SvgPicture.asset(
                              iconPath,
                              width: 24,
                              height: 24,
                              color: Colors.white,
                            )
                          : const Icon(
                              Icons.collections,
                              color: Colors.white,
                              size: 24,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            Colors.white,
                            gradientColors[0].withOpacity(0.9),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: gradientColors),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${collections.length}',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          Container(
            height: 250,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: collections.length,
              itemBuilder: (context, index) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 300 + (index * 50)),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.95 + (0.05 * value),
                      child: _buildCollectionCard(
                        collections[index],
                        index,
                        collections.length,
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

  // New method for collection cards
  Widget _buildCollectionCard(
    MovieCollection collection,
    int index,
    int totalItems,
    List<Color> gradientColors,
  ) {
    return GestureDetector(
      onTap: () => _navigateToCollectionDetails(collection),
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
              tag: 'collection-${collection.id}',
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
                            color: gradientColors[0].withOpacity(0.6),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                            spreadRadius: -3,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: CachedNetworkImage(
                          imageUrl: collection.posterUrl,
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
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.movie_filter,
                              color: Colors.amber,
                              size: 12,
                            ),
                            SizedBox(width: 2),
                            Text(
                              '${collection.parts.length}',
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
                    Positioned(
                      bottom: 10,
                      left: 10,
                      right: 10,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
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
                              collection.averageRating.toStringAsFixed(1),
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
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),
            Text(
              collection.name,
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

  // Navigation methods
  void _navigateToMovieCollections() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            MovieCollectionsScreen(
              preloadedCollections:
                  _movieCollections, // Pass the already loaded collections
            ),
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

  void _navigateToCollectionDetails(MovieCollection collection) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CollectionDetailScreen(collection: collection),
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

  Widget _buildSection(
    String title,
    List<Movie> movies,
    List<Color> gradientColors,
    String iconPath,
    bool isLoading,
    bool isHindiMovies, {
    bool isAnime = false, // Optional parameter
  }) {
    if (isLoading) {
      return _buildSectionShimmer(title, gradientColors);
    }

    if (movies.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: isHindiMovies
                  ? _navigateToHindiMovies
                  : isAnime
                  ? _navigateToAnime // ✅ This will trigger anime navigation
                  : null,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: (isHindiMovies || isAnime)
                      ? Colors.white.withOpacity(0.05)
                      : Colors.transparent,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: (isHindiMovies || isAnime) ? 12 : 0,
                  vertical: (isHindiMovies || isAnime) ? 8 : 0,
                ),
                child: Row(
                  children: [
                    // Platform icon
                    Container(
                      width: 32,
                      height: 32,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: iconPath.endsWith('.svg')
                          ? SvgPicture.asset(
                              iconPath,
                              width: 24,
                              height: 24,
                              color: Colors.white,
                            )
                          : const Icon(
                              Icons.movie,
                              color: Colors.white,
                              size: 24,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            Colors.white,
                            gradientColors[0].withOpacity(0.9),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
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
                    if (isHindiMovies || isAnime) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          Container(
            height: 250,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: movies.length,
              itemBuilder: (context, index) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 300 + (index * 50)),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.95 + (0.05 * value),
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

  Widget _buildSectionShimmer(String title, List<Color> gradientColors) {
    return Container(
      margin: EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Shimmer placeholder for icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 24,
                    width: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.2),
                          Colors.white.withOpacity(0.1),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 40,
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
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
          ),
          SizedBox(height: 15),
          Container(
            height: 250,
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
                        height: 190,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.1),
                              Colors.white.withOpacity(0.2),
                              Colors.white.withOpacity(0.1),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      Container(
                        height: 16,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.1),
                              Colors.white.withOpacity(0.15),
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
  }

  void _navigateToHindiMovies() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            HindiMoviesScreen(),
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

  void _navigateToAnime() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AnimeDetailScreen(
              categoryName: 'Anime Collection',
              gradientColors: [Colors.purple, Colors.pink],
            ),
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

  Widget _buildEmptySection() {
    return Center(
      child: Text(
        'No movies available',
        style: TextStyle(color: Colors.white60),
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
                            color: gradientColors[0].withOpacity(0.6),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                            spreadRadius: -3,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: CachedNetworkImage(
                          imageUrl: movie.posterPath.isNotEmpty
                              ? 'https://image.tmdb.org/t/p/w500${movie.posterPath}'
                              : movie.posterUrl,
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
                    // Removed the gradient overlay container that was reducing opacity
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
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
          ],
        ),
      ),
    );
  }

  Widget _buildMultipleResultsSection() {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Search Results (${_searchResults.length} found)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.7,
              ),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                return _buildMovieCardGrid(_searchResults[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieCardGrid(Movie movie) {
    return GestureDetector(
      onTap: () => _onMovieCardTap(movie),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[800],
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Movie poster
              movie.posterPath.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: movie.posterUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      maxHeightDiskCache: 400,
                      maxWidthDiskCache: 300,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[700],
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.red),
                        ),
                      ),
                      errorWidget: (context, url, error) => Image.asset(
                        'assets/notfound.jpg',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    )
                  : Image.asset(
                      'assets/notfound.jpg',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.9),
                    ],
                  ),
                ),
              ),

              // Movie info at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      if (movie.releaseDate.isNotEmpty)
                        Text(
                          'Released: ${movie.releaseDate.substring(0, 4)}',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 11,
                          ),
                        ),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 14),
                          SizedBox(width: 4),
                          Text(
                            movie.voteAverage.toStringAsFixed(1),
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.green, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text(
                'Stream Found!',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          _buildStreamLink(),
          if (_searchResult!['subtitles'] != null &&
              (_searchResult!['subtitles'] as List).isNotEmpty)
            _buildSubtitlesInfo(),
        ],
      ),
    );
  }

  Widget _buildStreamLink() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stream Link:',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  _searchResult!['m3u8_link'],
                  style: TextStyle(color: Colors.blue, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () => _copyToClipboard(_searchResult!['m3u8_link']),
                icon: Icon(Icons.copy, color: Colors.grey),
                iconSize: 20,
              ),
            ],
          ),
          SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () => _openStreamLink(_searchResult!['m3u8_link']),
            icon: Icon(Icons.play_arrow),
            label: Text('Play Stream'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitlesInfo() {
    List subtitles = _searchResult!['subtitles'];
    return Container(
      margin: EdgeInsets.only(top: 15),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purple),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subtitles Available: ${subtitles.length}',
            style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 5),
          Text(
            'Subtitle files found for this movie',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _searchMovie() async {
    if (_movieController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a movie name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _searchResult = null;
      _showMultipleResults = false;
      _searchStatus = 'Initializing search...';
    });

    try {
      final result = await _api.searchMovie(
        movieName: _movieController.text.trim(),
        quality: '1080',
        fetchSubs: true,
        onStatusUpdate: (status) {
          setState(() {
            _searchStatus = status;
          });
        },
      );

      setState(() {
        _isLoading = false;
        _searchResult = result;
        _searchStatus = '';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _searchStatus = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _searchMultipleMovies() async {
    if (_movieController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a movie name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _searchResult = null;
      _searchStatus = 'Searching multiple results...';
    });

    try {
      final results = await _api.searchMultipleMovies(
        _movieController.text.trim(),
      );

      setState(() {
        _isLoading = false;
        _searchResults = results
            .map((movieData) => Movie.fromJson(movieData))
            .toList();
        _showMultipleResults = true;
        _searchStatus = '';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _searchStatus = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
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

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Link copied to clipboard'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openStreamLink(String link) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SimpleStreamPlayer(
          streamUrl: link,
          movieTitle: _movieController.text.trim(),
          subtitleUrls: null, // No subtitles for direct links
        ),
      ),
    );
  }
}
