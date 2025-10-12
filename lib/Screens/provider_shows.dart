import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:soyo/Screens/showDetails.dart';
import 'package:soyo/models/tvshowsmodel.dart';
import 'package:soyo/Services/exploretvapi.dart';
import 'dart:async'; // Add this import at the top

class ProviderShowsScreen extends StatefulWidget {
  final String providerName;
  final int providerId;
  final List<Color> gradientColors;
  final IconData icon;

  const ProviderShowsScreen({
    Key? key,
    required this.providerName,
    required this.providerId,
    required this.gradientColors,
    required this.icon,
  }) : super(key: key);

  @override
  _ProviderShowsScreenState createState() => _ProviderShowsScreenState();
}

class _ProviderShowsScreenState extends State<ProviderShowsScreen>
    with TickerProviderStateMixin {
  late AnimationController _shimmerAnimation;
  List<TvShow> shows = [];
  int currentPage = 1;
  bool isLoading = false;
  bool hasMore = true;
  String errorMessage = '';
  ScrollController _scrollController = ScrollController();
  TextEditingController _searchController = TextEditingController();
  List<TvShow> searchResults = [];
  bool isSearching = false;
  String searchQuery = '';
  bool _showFilters = false;
  String _selectedLanguage = 'All';
  List<TvShow> _filteredShows = [];
  bool _isFilteredSearch = false;
  bool _hasUnsavedLanguageChange = false;
  String _savedLanguage = 'All';
  Timer? _searchDebounce; // Add this variable

  // Language options
  final Map<String, String> _languageOptions = {
    'All': 'All Languages',
    'en': 'English',
    'hi': 'Hindi',
    'ko': 'Korean (K-Drama)',
    'ja': 'Japanese (J-Drama)',
    'zh': 'Chinese',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'pt': 'Portuguese',
  };

  @override
  void initState() {
    super.initState();
    _savedLanguage = 'All';
    _shimmerAnimation = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _fetchShows();
    _scrollController.addListener(_scrollListener);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _shimmerAnimation.dispose();
    _searchDebounce?.cancel(); // Add this

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

    // Cancel previous timer
    _searchDebounce?.cancel();

    if (query.isEmpty) {
      setState(() {
        isSearching = false;
        searchQuery = '';
        searchResults.clear();
        _filteredShows.clear();
        _isFilteredSearch = false;
      });
    } else {
      // Set a debounce timer - wait 500ms after user stops typing
      _searchDebounce = Timer(const Duration(milliseconds: 500), () {
        if (query != searchQuery) {
          setState(() {
            searchQuery = query;
            isSearching = true;
          });
          _performEnhancedSearch(query);
        }
      });
    }
  }

  Future<void> _performEnhancedSearch(String query) async {
    try {
      setState(() {
        isSearching = true;
      });

      final lowerQuery = query.toLowerCase();
      List<TvShow> results = [];

      // Use the API to search within provider shows
      final searchResult = await ExploreTvApi.searchTvShowsWithProvider(
        query,
        widget.providerId,
        page: 1,
        useCache: false,
      );

      // Convert search results to TvShow objects
      results = (searchResult['results'] as List)
          .map((show) => TvShow.fromJson(show))
          .toList();

      // Apply language filter if not 'All'
      if (_selectedLanguage != 'All') {
        results = results.where((show) {
          return show.originalLanguage == _selectedLanguage;
        }).toList();
      }

      setState(() {
        searchResults = results;
        _filteredShows = results;
        isSearching = false;
        _isFilteredSearch = _selectedLanguage != 'All';
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Search failed: $e';
        isSearching = false;
      });
    }
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });
  }

  // NEW: Apply language filter
  void _applyLanguageFilter(String languageCode) {
    setState(() {
      _selectedLanguage = languageCode;
      _hasUnsavedLanguageChange = _savedLanguage != languageCode;
    });

    if (_searchController.text.isNotEmpty) {
      _performEnhancedSearch(_searchController.text);
    }
  }

  // 4. Updated _saveLanguageFilter method to get 30 shows of specific language
  Future<void> _saveLanguageFilter() async {
    try {
      setState(() {
        _savedLanguage = _selectedLanguage;
        _hasUnsavedLanguageChange = false;
        isLoading = true;
        shows.clear();
        currentPage = 1;
        errorMessage = '';
        hasMore = true;
      });

      if (_selectedLanguage == 'All') {
        // Load all provider shows normally
        final result = await ExploreTvApi.getTvShowsByProvider(
          widget.providerId,
          page: 1,
          useCache: false,
        );

        setState(() {
          shows = (result['results'] as List)
              .map((show) => TvShow.fromJson(show))
              .toList();
          currentPage = 1;
          isLoading = false;
          hasMore = currentPage < (result['total_pages'] ?? 1);
        });
      } else {
        // Load shows with language filter - fetch multiple pages if needed
        await _loadFilteredShows(minShowsTarget: 20);
      }

      // Clear search if active
      if (_searchController.text.isNotEmpty) {
        _searchController.clear();
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to apply language filter: $e';
        isLoading = false;
        hasMore = false;
      });
    }
  }

  Future<void> _loadFilteredShows({int minShowsTarget = 20}) async {
    List<TvShow> filteredShows = [];
    int page = 1;
    int totalPages = 1;
    int maxPagesToFetch = 10; // Prevent infinite loop

    try {
      while (filteredShows.length < minShowsTarget &&
          page <= totalPages &&
          page <= maxPagesToFetch) {
        final result = await ExploreTvApi.getTvShowsByProvider(
          widget.providerId,
          page: page,
          useCache: page > 1, // Cache subsequent pages
        );

        final pageShows = (result['results'] as List)
            .map((show) => TvShow.fromJson(show))
            .where((show) => show.originalLanguage == _savedLanguage)
            .toList();

        filteredShows.addAll(pageShows);
        totalPages = result['total_pages'] ?? 1;
        page++;
      }

      setState(() {
        shows = filteredShows;
        currentPage = page - 1;
        isLoading = false;
        hasMore = currentPage < totalPages;
      });
    } catch (e) {
      setState(() {
        shows = filteredShows; // Keep what we loaded
        isLoading = false;
        hasMore = false;
        if (filteredShows.isEmpty) {
          errorMessage = 'Failed to load shows: $e';
        }
      });
    }
  }

  Widget _buildShimmerLoading() {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return GridView.builder(
          padding: EdgeInsets.all(20),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: 10,
            mainAxisSpacing: 20,
          ),
          itemCount: 6, // Show 6 shimmer items
          itemBuilder: (context, index) {
            return Container(
              width: 140,
              margin: EdgeInsets.only(left: 20, right: index % 2 == 1 ? 20 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 190,
                    width: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment(-1.0 + _shimmerAnimation.value, -1.0),
                        end: Alignment(1.0 + _shimmerAnimation.value, 1.0),
                        colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.3),
                          Colors.white.withOpacity(0.1),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    height: 16,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        begin: Alignment(-1.0 + _shimmerAnimation.value, 0.0),
                        end: Alignment(1.0 + _shimmerAnimation.value, 0.0),
                        colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.2),
                          Colors.white.withOpacity(0.1),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 4),
                  Container(
                    height: 12,
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                        begin: Alignment(-1.0 + _shimmerAnimation.value, 0.0),
                        end: Alignment(1.0 + _shimmerAnimation.value, 0.0),
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
        );
      },
    );
  }

  Future<void> _loadAllShows() async {
    while (hasMore && shows.length < 500) {
      // Limit to prevent excessive API calls
      await _loadMore();
      if (isLoading) break; // Prevent infinite loop
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      isSearching = false;
      searchQuery = '';
      searchResults.clear();
      _filteredShows.clear();
      _isFilteredSearch = false;
      _showFilters = false;
      _selectedLanguage = 'All';
      _savedLanguage = 'All';
      _hasUnsavedLanguageChange = false;
    });
  }

  Future<void> _fetchShows() async {
    try {
      setState(() {
        isLoading = true;
      });

      final result = await ExploreTvApi.getTvShowsByProvider(
        widget.providerId,
        page: currentPage,
      );

      setState(() {
        shows = (result['results'] as List)
            .map((show) => TvShow.fromJson(show))
            .toList();
        isLoading = false;
        hasMore = currentPage < (result['total_pages'] ?? 1);
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load shows: $e';
        isLoading = false;
      });
    }
  }

  // Replace your existing _loadMore method with this:
  Future<void> _loadMore() async {
    if (isLoading || !hasMore) return;

    try {
      setState(() {
        isLoading = true;
      });

      if (_savedLanguage == 'All') {
        // Normal pagination for unfiltered results
        final nextPage = currentPage + 1;
        final result = await ExploreTvApi.getTvShowsByProvider(
          widget.providerId,
          page: nextPage,
          useCache: true,
        );

        List<TvShow> newShows = (result['results'] as List)
            .map((show) => TvShow.fromJson(show))
            .toList();

        setState(() {
          shows.addAll(newShows);
          currentPage = nextPage;
          isLoading = false;
          hasMore = currentPage < (result['total_pages'] ?? 1);
        });
      } else {
        // For filtered results, load more pages until we get enough shows
        List<TvShow> newFilteredShows = [];
        int totalPages = 100; // Start with high number
        int maxPagesToFetch = 10; // Load up to 10 pages at a time
        int pagesChecked = 0;

        int nextPage = currentPage + 1;

        while (newFilteredShows.length < 10 &&
            pagesChecked < maxPagesToFetch &&
            nextPage <= totalPages) {
          final result = await ExploreTvApi.getTvShowsByProvider(
            widget.providerId,
            page: nextPage,
            useCache: true,
          );

          totalPages = result['total_pages'] ?? 1;

          final pageShows = (result['results'] as List)
              .map((show) => TvShow.fromJson(show))
              .where((show) => show.originalLanguage == _savedLanguage)
              .toList();

          newFilteredShows.addAll(pageShows);
          nextPage++;
          pagesChecked++;

          // Break if we've reached the last page
          if (nextPage > totalPages) break;
        }

        setState(() {
          if (newFilteredShows.isNotEmpty) {
            shows.addAll(newFilteredShows);
          }
          currentPage = nextPage - 1;
          isLoading = false;
          // hasMore is true if we haven't reached the last page
          hasMore = currentPage < totalPages;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load more shows: $e';
        isLoading = false;
        hasMore = false;
      });
    }
  }

  void _onShowCardTap(TvShow show) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ShowDetailScreen(show: show)),
    );
  }

  Widget _buildShowCard(TvShow show, int index) {
    return GestureDetector(
      onTap: () => _onShowCardTap(show),
      child: Container(
        width: 140,
        margin: EdgeInsets.only(left: 20, right: index % 2 == 1 ? 20 : 0),
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
                child: shows.isEmpty && isLoading
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

  Widget _buildSearchBar() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: widget.gradientColors[0].withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            style: GoogleFonts.nunito(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search ${widget.providerName} shows...',
              hintStyle: GoogleFonts.nunito(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Colors.white.withOpacity(0.7),
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSearching)
                    Container(
                      width: 20,
                      height: 20,
                      margin: EdgeInsets.only(right: 8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.gradientColors[0],
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
                  SizedBox(width: 8),
                  GestureDetector(
                    onTap: _toggleFilters,
                    child: Icon(
                      Icons.tune_rounded,
                      color: _showFilters
                          ? widget.gradientColors[0]
                          : Colors.white.withOpacity(0.7),
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
                borderSide: BorderSide(
                  color: widget.gradientColors[0],
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),

        // Filter options
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _showFilters ? null : 0,
          child: _showFilters ? _buildFilterOptions() : null,
        ),
      ],
    );
  }

  Widget _buildFilterOptions() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: widget.gradientColors[0].withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.language_rounded,
                color: widget.gradientColors[0],
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Language Filter',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Spacer(),
              // Save button (only show if there are unsaved changes)
              if (_hasUnsavedLanguageChange)
                GestureDetector(
                  onTap: isLoading ? null : _saveLanguageFilter,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: widget.gradientColors),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: widget.gradientColors[0].withOpacity(0.3),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: isLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Save',
                            style: GoogleFonts.nunito(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              if (_hasUnsavedLanguageChange) SizedBox(width: 8),
              // Clear button (only show if not 'All' or has saved preference)
              if (_selectedLanguage != 'All' || _savedLanguage != 'All')
                GestureDetector(
                  onTap: () {
                    _applyLanguageFilter('All');
                    if (_savedLanguage != 'All') {
                      _saveLanguageFilter();
                    }
                  },
                  child: Text(
                    'Clear',
                    style: GoogleFonts.nunito(
                      color: widget.gradientColors[0],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _languageOptions.entries.map((entry) {
              final isSelected = _selectedLanguage == entry.key;
              return GestureDetector(
                onTap: () => _applyLanguageFilter(entry.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(colors: widget.gradientColors)
                        : null,
                    color: isSelected ? null : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : Colors.white.withOpacity(0.3),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: widget.gradientColors[0].withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    entry.value,
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
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
                    colors: [
                      Colors.white,
                      widget.gradientColors[0].withOpacity(0.8),
                    ],
                  ).createShader(bounds),
                  child: Text(
                    widget.providerName,
                    style: GoogleFonts.nunito(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                Text(
                  'Browse all shows',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: widget.gradientColors),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(widget.icon, color: Colors.white, size: 24),
          ),
        ],
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
              onPressed: _fetchShows,
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
    // Determine which shows to display
    List<TvShow> showsToShow;

    if (searchQuery.isNotEmpty) {
      // If there's a search query, show search results
      showsToShow = searchResults;
    } else if (_selectedLanguage != 'All' && _savedLanguage != 'All') {
      // If language filter is saved and applied, show filtered results
      showsToShow = shows;
    } else {
      // Default: show all provider shows
      showsToShow = shows;
    }

    // Show shimmer when loading after language filter save
    if (isLoading && shows.isEmpty) {
      return _buildShimmerLoading();
    }

    // Show "no results" message for search
    if (searchQuery.isNotEmpty && showsToShow.isEmpty && !isSearching) {
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
                'No shows found for "$searchQuery"',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                _selectedLanguage != 'All'
                    ? 'in ${_languageOptions[_selectedLanguage]}'
                    : 'Try adjusting your search terms',
                style: GoogleFonts.nunito(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (!isLoading &&
            hasMore &&
            searchQuery.isEmpty &&
            scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          _loadMore();
        }
        return true;
      },
      child: Column(
        children: [
          // Show search results info
          if (searchQuery.isNotEmpty && showsToShow.isNotEmpty)
            Container(
              margin: EdgeInsets.fromLTRB(20, 0, 20, 10),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.gradientColors
                      .map((c) => c.withOpacity(0.2))
                      .toList(),
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.white.withOpacity(0.8),
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '${showsToShow.length} results found',
                    style: GoogleFonts.nunito(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

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
              itemCount: showsToShow.length,
              itemBuilder: (context, index) {
                return _buildShowCard(showsToShow[index], index);
              },
            ),
          ),

          // Loading indicator at bottom (outside grid)
          if (isLoading && searchQuery.isEmpty && hasMore)
            Container(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(color: widget.gradientColors[0]),
            ),
        ],
      ),
    );
  }

  //   Widget _buildLoadMoreButton() {
  //     return Container(
  //       margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
  //       child: Center(
  //         child: isLoading
  //             ? CircularProgressIndicator(color: widget.gradientColors[0])
  //             : ElevatedButton(
  //                 onPressed: _loadMore,
  //                 style: ElevatedButton.styleFrom(
  //                   backgroundColor: widget.gradientColors[0],
  //                   foregroundColor: Colors.white,
  //                   padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
  //                   shape: RoundedRectangleBorder(
  //                     borderRadius: BorderRadius.circular(25),
  //                   ),
  //                 ),
  //                 child: Text(
  //                   'Load More',
  //                   style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
  //                 ),
  //               ),
  //       ),
  //     );
  //   }
}
