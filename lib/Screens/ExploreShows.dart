import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:soyo/Screens/provider_shows.dart';
import 'package:soyo/Screens/showDetails.dart';
import 'package:soyo/Services/exploretvapi.dart';
import 'package:soyo/models/tvshowsmodel.dart';

class ExploreShows extends StatefulWidget {
  @override
  _ExploreShowsState createState() => _ExploreShowsState();
}

class _ExploreShowsState extends State<ExploreShows>
    with TickerProviderStateMixin {
  List<TvShow> netflixShows = [];
  List<TvShow> appleTvShows = [];
  List<TvShow> primeVideoShows = [];
  List<TvShow> disneyShows = [];
  List<TvShow> hboMaxShows = [];
  List<TvShow> huluShows = [];
  List<TvShow> paramountShows = [];

  bool isLoading = true;
  String errorMessage = '';
  TextEditingController _searchController = TextEditingController();
  List<TvShow> _searchResults = [];
  bool _isSearching = false;
  String _searchQuery = '';
  Timer? _searchDebounce;
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
    _searchController.addListener(_onSearchChanged);
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
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    _searchDebounce?.cancel();

    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchQuery = '';
        _searchResults.clear();
      });
    } else {
      _searchDebounce = Timer(const Duration(milliseconds: 500), () {
        if (query != _searchQuery) {
          setState(() {
            _searchQuery = query;
            _isSearching = true;
          });
          _performSearch(query);
        }
      });
    }
  }

  Future<void> _performSearch(String query) async {
    try {
      setState(() {
        _isSearching = true;
      });

      // Use TMDB search API to search all TV shows
      final searchResult = await ExploreTvApi.searchTvShows(
        query,
        page: 1,
        useCache: false,
      );

      final results = (searchResult['results'] as List)
          .map((show) => TvShow.fromJson(show))
          .toList();

      // Remove duplicates based on show ID
      final uniqueResults = <int, TvShow>{};
      for (var show in results) {
        uniqueResults[show.id] = show;
      }

      setState(() {
        _searchResults = uniqueResults.values.toList();
        _isSearching = false;
      });
    } catch (e) {
      print('Search error: $e');
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchResults.clear();
    });
  }

  Future<void> _fetchAllData() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Check cache first for all providers
      final cacheResults = await Future.wait([
        _checkCacheAndLoad('Netflix', () => ExploreTvApi.getNetflixTvShows()),
        _checkCacheAndLoad('Apple TV', () => ExploreTvApi.getAppleTvShows()),
        _checkCacheAndLoad(
          'Prime Video',
          () => ExploreTvApi.getPrimeVideoShows(),
        ),
        _checkCacheAndLoad('Disney+', () => ExploreTvApi.getDisneyShows()),
        _checkCacheAndLoad('HBO Max', () => ExploreTvApi.getHboMaxShows()),
        _checkCacheAndLoad('Hulu', () => ExploreTvApi.getHuluShows()),
        _checkCacheAndLoad(
          'Paramount+',
          () => ExploreTvApi.getParamountShows(),
        ),
      ]);

      setState(() {
        netflixShows = (cacheResults[0]['results'] as List)
            .map((show) => TvShow.fromJson(show))
            .toList();

        appleTvShows = (cacheResults[1]['results'] as List)
            .map((show) => TvShow.fromJson(show))
            .toList();

        primeVideoShows = (cacheResults[2]['results'] as List)
            .map((show) => TvShow.fromJson(show))
            .toList();

        disneyShows = (cacheResults[3]['results'] as List)
            .map((show) => TvShow.fromJson(show))
            .toList();

        hboMaxShows = (cacheResults[4]['results'] as List)
            .map((show) => TvShow.fromJson(show))
            .toList();

        huluShows = (cacheResults[5]['results'] as List)
            .map((show) => TvShow.fromJson(show))
            .toList();

        paramountShows = (cacheResults[6]['results'] as List)
            .map((show) => TvShow.fromJson(show))
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

  // Helper method to check cache first, then fallback to API
  Future<Map<String, dynamic>> _checkCacheAndLoad(
    String providerName,
    Future<Map<String, dynamic>> Function() apiCall,
  ) async {
    try {
      // First try to get cached data
      final cachedData =
          await apiCall(); // This will automatically check cache first due to useCache: true
      return cachedData;
    } catch (e) {
      print('Failed to load $providerName shows: $e');
      // Return empty result structure if both cache and API fail
      return {'results': [], 'total_pages': 0, 'total_results': 0, 'page': 1};
    }
  }

  void _onProviderSectionTap(
    String title,
    List<Color> gradientColors,
    IconData icon,
  ) {
    // Map the provider name to its ID
    final providerIds = {
      'Netflix': 8,
      'Apple TV': 350,
      'Prime Video': 9,
      'Disney+': 337,
      'HBO Max': 1899,
      'Hulu': 15,
      'Paramount+': 531,
    };

    final providerId =
        providerIds[title] ?? 8; // Default to Netflix if not found

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProviderShowsScreen(
          providerName: title,
          providerId: providerId,
          gradientColors: gradientColors,
          icon: icon,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.nunito(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search all providers...',
          hintStyle: GoogleFonts.nunito(
            color: Colors.white.withOpacity(0.5),
            fontSize: 16,
          ),
          prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isSearching)
                Container(
                  width: 20,
                  height: 20,
                  margin: EdgeInsets.only(right: 8),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.blue,
                  ),
                ),
              if (_searchController.text.isNotEmpty)
                GestureDetector(
                  onTap: _clearSearch,
                  child: Icon(
                    Icons.clear,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              SizedBox(width: 12),
            ],
          ),
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
            borderSide: BorderSide(color: Colors.blue, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Container(
          margin: EdgeInsets.all(30),
          padding: EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 60,
                color: Colors.white.withOpacity(0.3),
              ),
              SizedBox(height: 20),
              Text(
                'No shows found for "$_searchQuery"',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 15),
          child: Text(
            '${_searchResults.length} results found',
            style: GoogleFonts.nunito(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 10,
              mainAxisSpacing: 20,
            ),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              return _buildShowCard(
                _searchResults[index],
                index,
                _searchResults.length,
                [Colors.blue.shade600, Colors.purple.shade600],
              );
            },
          ),
        ),
      ],
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
              _buildAnimatedAppBar(),
              _buildSearchBar(),
              Expanded(
                child: isLoading
                    ? _buildShimmerLoading()
                    : errorMessage.isNotEmpty
                    ? _buildErrorState()
                    : _searchQuery.isNotEmpty
                    ? _buildSearchResults()
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
                  child: Icon(Icons.tv, color: Colors.white, size: 24),
                ),
              ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [Colors.white, Colors.blue.shade300],
                      ).createShader(bounds),
                      child: Text(
                        'TV Shows',
                        style: GoogleFonts.nunito(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    Text(
                      'Discover amazing series',
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
            children: List.generate(7, (sectionIndex) {
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
        'title': 'Netflix',
        'shows': netflixShows,
        'gradient': [Colors.red.shade600, Colors.red.shade800],
        'icon': Icons.play_circle_fill,
      },
      {
        'title': 'Apple TV+',
        'shows': appleTvShows,
        'gradient': [Colors.grey.shade600, Colors.grey.shade800],
        'icon': Icons.apple,
      },
      {
        'title': 'Prime Video',
        'shows': primeVideoShows,
        'gradient': [Colors.blue.shade600, Colors.blue.shade800],
        'icon': Icons.play_arrow,
      },
      {
        'title': 'Disney+',
        'shows': disneyShows,
        'gradient': [Colors.blue.shade400, Colors.purple.shade600],
        'icon': Icons.castle,
      },
      {
        'title': 'HBO Max',
        'shows': hboMaxShows,
        'gradient': [Colors.purple.shade600, Colors.purple.shade800],
        'icon': Icons.hd,
      },
      {
        'title': 'Hulu',
        'shows': huluShows,
        'gradient': [Colors.green.shade500, Colors.green.shade700],
        'icon': Icons.tv,
      },
      {
        'title': 'Paramount+',
        'shows': paramountShows,
        'gradient': [Colors.blue.shade700, Colors.blue.shade900],
        'icon': Icons.star,
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
                  // Clamp the value to ensure it's within valid range
                  final clampedValue = value.clamp(0.0, 1.0);

                  return Transform.translate(
                    offset: Offset(0, 50 * (1 - clampedValue)),
                    child: Opacity(
                      opacity: clampedValue,
                      child: _buildSection(
                        section['title'],
                        section['shows'],
                        section['gradient'],
                        section['icon'],
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
    List<TvShow> shows,
    List<Color> gradientColors,
    IconData icon,
  ) {
    return GestureDetector(
      onTap: () => _onProviderSectionTap(title, gradientColors, icon),
      child: Container(
        margin: EdgeInsets.only(bottom: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradientColors),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 18),
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
                      '${shows.length}',
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
                itemCount: shows.length,
                itemBuilder: (context, index) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 300 + (index * 50)),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: 0.8 + (0.2 * value),
                        child: _buildShowCard(
                          shows[index],
                          index,
                          shows.length,
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
      ),
    );
  }

  Widget _buildShowCard(
    TvShow show,
    int index,
    int totalItems,
    List<Color> gradientColors,
  ) {
    return GestureDetector(
      onTap: () => _onShowCardTap(show),
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
              tag: 'show-${show.id}',
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
                          show.posterUrl,
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
                                  Icons.tv,
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
                              show.voteAverage.toStringAsFixed(1),
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

            // Show title
            Text(
              show.name,
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

  void _onShowCardTap(TvShow show) {
    // Navigate to show detail screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ShowDetailScreen(show: show)),
    );
  }
}
