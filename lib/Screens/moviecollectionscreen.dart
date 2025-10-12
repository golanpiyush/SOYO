import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:soyo/models/moviecollections.dart';
import 'package:soyo/Services/collections_api.dart';
import 'package:soyo/Screens/collectionDetailScreen.dart';

class MovieCollectionsScreen extends StatefulWidget {
  final List<MovieCollection>? preloadedCollections;

  const MovieCollectionsScreen({Key? key, this.preloadedCollections})
    : super(key: key);

  @override
  _MovieCollectionsScreenState createState() => _MovieCollectionsScreenState();
}

class _MovieCollectionsScreenState extends State<MovieCollectionsScreen> {
  List<MovieCollection> _collections = [];
  List<MovieCollection> _filteredCollections = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  ScrollController _scrollController = ScrollController();
  String errorMessage = '';
  String searchQuery = '';

  final List<String> _filterOptions = [
    'All',
    'Trending',
    'Top Rated',
    'Recently Updated',
    'Action',
    'Adventure',
    'Sci-Fi',
    'Fantasy',
  ];

  // Gradient colors similar to anime screen
  final List<Color> gradientColors = [Color(0xFF6A4C93), Color(0xFF9C27B0)];

  @override
  void initState() {
    super.initState();
    if (widget.preloadedCollections != null &&
        widget.preloadedCollections!.isNotEmpty) {
      _collections = widget.preloadedCollections!;
      _filteredCollections = widget.preloadedCollections!;
      _isLoading = false;
      _applyFilter();
    } else {
      _loadCollections();
    }

    _searchController.addListener(_onSearchChangedDebounced);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChangedDebounced() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: 500), () {
      _onSearchChanged();
    });
  }

  Future<void> _loadCollections() async {
    try {
      setState(() {
        _isLoading = true;
        errorMessage = '';
      });

      final collections = await CollectionsApiService.getPopularCollections();

      setState(() {
        _collections = collections;
        _filteredCollections = collections;
        _isLoading = false;
      });

      _applyFilter();
    } catch (e) {
      setState(() {
        _isLoading = false;
        errorMessage = 'Failed to load collections: $e';
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        searchQuery = '';
        _filteredCollections = List.from(_collections);
      });
      _applyFilter();
      return;
    } else if (query != searchQuery) {
      setState(() {
        searchQuery = query;
        _isSearching = true;
      });
    }

    final localResults = _collections
        .where(
          (collection) =>
              collection.name.toLowerCase().contains(query.toLowerCase()) ||
              collection.overview.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();

    if (localResults.isEmpty && query.length >= 3) {
      _performDynamicSearch(query);
    } else {
      setState(() {
        _filteredCollections = localResults;
        _isSearching = false;
      });
      _applyFilter();
    }
  }

  Future<void> _performDynamicSearch(String query) async {
    try {
      setState(() {
        _isSearching = true;
      });

      final searchResults = await CollectionsApiService.searchCollectionsByName(
        query,
      );

      final Map<int, MovieCollection> combinedMap = {};

      for (var collection in _collections) {
        combinedMap[collection.id] = collection;
      }

      for (var collection in searchResults) {
        combinedMap[collection.id] = collection;
      }

      final combinedCollections = combinedMap.values.toList();

      final filteredResults = combinedCollections
          .where(
            (collection) =>
                collection.name.toLowerCase().contains(query.toLowerCase()) ||
                collection.overview.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();

      setState(() {
        _collections = combinedCollections;
        _filteredCollections = filteredResults;
        _isSearching = false;
      });

      _applyFilter();
    } catch (e) {
      setState(() {
        _isSearching = false;
        errorMessage = 'Search failed: $e';
      });
    }
  }

  void _applyFilter() {
    List<MovieCollection> baseList = _searchController.text.trim().isEmpty
        ? List.from(_collections)
        : _filteredCollections;

    List<MovieCollection> filtered = List.from(baseList);

    switch (_selectedFilter) {
      case 'All':
        break;
      case 'Trending':
        filtered.sort((a, b) {
          final aAvgPopularity = a.parts.isEmpty
              ? 0.0
              : a.parts.fold(0.0, (sum, movie) => sum + movie.popularity) /
                    a.parts.length;
          final bAvgPopularity = b.parts.isEmpty
              ? 0.0
              : b.parts.fold(0.0, (sum, movie) => sum + movie.popularity) /
                    b.parts.length;
          return bAvgPopularity.compareTo(aAvgPopularity);
        });
        break;
      case 'Top Rated':
        filtered.sort((a, b) => b.averageRating.compareTo(a.averageRating));
        break;
      case 'Recently Updated':
        filtered = filtered
            .where(
              (collection) =>
                  collection.parts.any((movie) => movie.isRecentRelease),
            )
            .toList();
        break;
      case 'Action':
        filtered = filtered
            .where(
              (collection) =>
                  collection.parts.any((movie) => movie.genreIds.contains(28)),
            )
            .toList();
        break;
      case 'Adventure':
        filtered = filtered
            .where(
              (collection) =>
                  collection.parts.any((movie) => movie.genreIds.contains(12)),
            )
            .toList();
        break;
      case 'Sci-Fi':
        filtered = filtered
            .where(
              (collection) =>
                  collection.parts.any((movie) => movie.genreIds.contains(878)),
            )
            .toList();
        break;
      case 'Fantasy':
        filtered = filtered
            .where(
              (collection) =>
                  collection.parts.any((movie) => movie.genreIds.contains(14)),
            )
            .toList();
        break;
    }

    setState(() {
      _filteredCollections = filtered;
    });
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.nunito(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search movie collections...',
          hintStyle: GoogleFonts.nunito(
            color: Colors.white.withOpacity(0.5),
            fontSize: 16,
          ),
          prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
          suffixIcon: _searchController.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() {
                      _isSearching = false;
                      searchQuery = '';
                    });
                  },
                  child: Icon(
                    Icons.clear,
                    color: Colors.white.withOpacity(0.7),
                  ),
                )
              : _isSearching
              ? Container(
                  width: 20,
                  height: 20,
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    color: gradientColors[0],
                    strokeWidth: 2,
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
                    Colors.purple.withOpacity(0.3),
                    Colors.pink.withOpacity(0.3),
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
                    'Movie Collections',
                    style: GoogleFonts.nunito(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                Text(
                  'Discover amazing movie series',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          _buildSortButton(),
          SizedBox(width: 10),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.movie_filter, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildSortButton() {
    return PopupMenuButton<String>(
      onSelected: (value) {
        setState(() {
          _selectedFilter = value;
        });
        _applyFilter();
      },
      itemBuilder: (BuildContext context) => _filterOptions.map((option) {
        return PopupMenuItem(
          value: option,
          child: _buildMenuRow(
            _getFilterIcon(option),
            option,
            _selectedFilter == option,
          ),
        );
      }).toList(),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Icon(Icons.filter_list, color: Colors.white, size: 20),
      ),
    );
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'All':
        return Icons.grid_view;
      case 'Trending':
        return Icons.trending_up;
      case 'Top Rated':
        return Icons.star;
      case 'Recently Updated':
        return Icons.new_releases;
      case 'Action':
        return Icons.local_fire_department;
      case 'Adventure':
        return Icons.explore;
      case 'Sci-Fi':
        return Icons.rocket_launch;
      case 'Fantasy':
        return Icons.auto_awesome;
      default:
        return Icons.category;
    }
  }

  Widget _buildMenuRow(IconData icon, String text, bool isSelected) {
    return Row(
      children: [
        Icon(
          icon,
          color: isSelected ? gradientColors[0] : Colors.grey,
          size: 20,
        ),
        SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.nunito(
            color: isSelected ? Colors.white : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionCard(MovieCollection collection, int index) {
    return GestureDetector(
      onTap: () => _navigateToCollectionDetail(collection),
      child: Container(
        width: 140,
        margin: EdgeInsets.only(left: 20, right: index % 2 == 1 ? 20 : 0),
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
                          imageUrl: collection.posterUrl,
                          fit: BoxFit.cover,
                          width: 140,
                          height: 190,
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
                          errorWidget: (context, error, stackTrace) {
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
                                  Icons.movie_filter,
                                  color: Colors.white.withOpacity(0.3),
                                  size: 40,
                                ),
                              ),
                            );
                          },
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
                          '${collection.parts.length} Movies',
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
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadCollections,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.movie_filter_outlined,
            size: 60,
            color: Colors.white.withOpacity(0.3),
          ),
          SizedBox(height: 20),
          Text(
            'No collections found',
            style: GoogleFonts.nunito(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final collectionsToShow = _filteredCollections;

    // Show loading state when searching
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: gradientColors[0], strokeWidth: 3),
            SizedBox(height: 20),
            Text(
              'Searching collections...',
              style: GoogleFonts.nunito(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (collectionsToShow.isEmpty && _searchController.text.isNotEmpty) {
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
              'No collections found for "${_searchController.text}"',
              style: GoogleFonts.nunito(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
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
            itemCount: collectionsToShow.length,
            itemBuilder: (context, index) {
              return _buildCollectionCard(collectionsToShow[index], index);
            },
          ),
        ),
      ],
    );
  }

  void _navigateToCollectionDetail(MovieCollection collection) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CollectionDetailScreen(collection: collection),
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
                child: _collections.isEmpty && _isLoading
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
}
