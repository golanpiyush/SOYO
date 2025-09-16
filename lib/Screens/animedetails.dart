import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:soyo/Screens/animesceendetials.dart';
import 'package:soyo/Services/anime_collection_api.dart';
import 'package:soyo/models/anime_model.dart';
import 'package:intl/intl.dart';

class AnimeDetailScreen extends StatefulWidget {
  final String categoryName;
  final List<Color> gradientColors;
  final AnimeSortOption? sortOption;

  const AnimeDetailScreen({
    Key? key,
    required this.categoryName,
    required this.gradientColors,
    this.sortOption,
  }) : super(key: key);

  @override
  _AnimeDetailScreenState createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends State<AnimeDetailScreen> {
  List<Anime> animeList = [];
  int currentPage = 1;
  String _sortBy = 'popularity.desc';
  List<Anime> _allAnime = [];
  bool isLoading = false;
  bool hasMore = true;
  String errorMessage = '';
  ScrollController _scrollController = ScrollController();
  TextEditingController _searchController = TextEditingController();
  List<Anime> searchResults = [];
  bool isSearching = false;
  String searchQuery = '';

  // Filter options
  double _minRating = 0.0;
  int _minVoteCount = 0;
  String _originalLanguage = 'ja'; // Default to Japanese
  List<int> _selectedGenres = [16]; // Animation genre by default

  final AnimeCollectionApi _animeApi = AnimeCollectionApi();

  @override
  void initState() {
    super.initState();
    if (widget.sortOption != null) {
      _sortBy = widget.sortOption!.value;
    }
    _fetchAnime();
    _scrollController.addListener(_scrollListener);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _animeApi.dispose();
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
      final result = await _animeApi.searchAnime(query, page: 1);

      setState(() {
        searchResults = result.results;
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

  Future<void> _fetchAnime() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      AnimeResponse result;

      // Handle different categories
      if (widget.categoryName.toLowerCase().contains('popular')) {
        result = await _animeApi.getPopularAnime(page: currentPage);
      } else if (widget.categoryName.toLowerCase().contains('newest')) {
        result = await _animeApi.getNewestAnime(page: currentPage);
      } else if (widget.categoryName.toLowerCase().contains('top rated')) {
        result = await _animeApi.getTopRatedAnime(page: currentPage);
      } else {
        // General anime fetch with filters
        result = await _animeApi.getAnime(
          page: currentPage,
          sortBy: _sortBy,
          genres: _selectedGenres.isNotEmpty ? _selectedGenres : null,
          originalLanguage: _originalLanguage,
          minVoteCount: _minVoteCount > 0 ? _minVoteCount : null,
          minVoteAverage: _minRating > 0 ? _minRating : null,
        );
      }

      setState(() {
        _allAnime = result.results;
        animeList = _allAnime;
        isLoading = false;
        hasMore = currentPage < result.totalPages;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load anime: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (isLoading || !hasMore) return;

    try {
      setState(() {
        isLoading = true;
      });

      final nextPage = currentPage + 1;
      AnimeResponse result;

      if (widget.categoryName.toLowerCase().contains('popular')) {
        result = await _animeApi.getPopularAnime(page: nextPage);
      } else if (widget.categoryName.toLowerCase().contains('newest')) {
        result = await _animeApi.getNewestAnime(page: nextPage);
      } else if (widget.categoryName.toLowerCase().contains('top rated')) {
        result = await _animeApi.getTopRatedAnime(page: nextPage);
      } else {
        result = await _animeApi.getAnime(
          page: nextPage,
          sortBy: _sortBy,
          genres: _selectedGenres.isNotEmpty ? _selectedGenres : null,
          originalLanguage: _originalLanguage,
          minVoteCount: _minVoteCount > 0 ? _minVoteCount : null,
          minVoteAverage: _minRating > 0 ? _minRating : null,
        );
      }

      setState(() {
        _allAnime.addAll(result.results);
        animeList = _allAnime;
        currentPage = nextPage;
        isLoading = false;
        hasMore = currentPage < result.totalPages;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load more anime: $e';
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
          hintText: 'Search anime...',
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
            borderSide: BorderSide(color: widget.gradientColors[0], width: 1.5),
          ),
        ),
      ),
    );
  }

  void _onAnimeCardTap(Anime anime) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SingleAnimeDetailScreen(anime: anime),
      ),
    );
  }

  Widget _buildAnimeCard(Anime anime, int index) {
    final releaseDate = anime.firstAirDate;
    String formattedDate = 'TBA';

    if (releaseDate.isNotEmpty) {
      final date = DateTime.tryParse(releaseDate);
      if (date != null) {
        formattedDate = DateFormat('MMM dd, yyyy').format(date);
      }
    }

    return GestureDetector(
      onTap: () => _onAnimeCardTap(anime),
      child: Container(
        width: 140,
        margin: EdgeInsets.only(left: 20, right: index % 2 == 1 ? 20 : 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'anime-${anime.id}',
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
                        child: CachedNetworkImage(
                          imageUrl: anime.getPosterUrl(),
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
                                color: widget.gradientColors[0],
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
                              anime.voteAverage.toStringAsFixed(1),
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
                          color: widget.gradientColors[0].withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          anime.originalLanguage.toUpperCase(),
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
              anime.name,
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (releaseDate.isNotEmpty)
              Text(
                'First aired: $formattedDate',
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
                child: animeList.isEmpty && isLoading
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
                    colors: [
                      Colors.white,
                      widget.gradientColors[0].withOpacity(0.8),
                    ],
                  ).createShader(bounds),
                  child: Text(
                    widget.categoryName,
                    style: GoogleFonts.nunito(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                Text(
                  'Discover amazing anime series',
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
          _buildFilterButton(),
          SizedBox(width: 10),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: widget.gradientColors),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.tv, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildSortButton() {
    return PopupMenuButton<String>(
      onSelected: (value) {
        setState(() {
          _sortBy = value;
          currentPage = 1;
          _fetchAnime();
        });
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem(
          value: 'popularity.desc',
          child: _buildMenuRow(
            Icons.trending_up,
            'Most Popular',
            _sortBy == 'popularity.desc',
          ),
        ),
        PopupMenuItem(
          value: 'vote_average.desc',
          child: _buildMenuRow(
            Icons.star,
            'Highest Rated',
            _sortBy == 'vote_average.desc',
          ),
        ),
        PopupMenuItem(
          value: 'first_air_date.desc',
          child: _buildMenuRow(
            Icons.new_releases,
            'Newest First',
            _sortBy == 'first_air_date.desc',
          ),
        ),
        PopupMenuItem(
          value: 'first_air_date.asc',
          child: _buildMenuRow(
            Icons.history,
            'Oldest First',
            _sortBy == 'first_air_date.asc',
          ),
        ),
        PopupMenuItem(
          value: 'original_name.asc',
          child: _buildMenuRow(
            Icons.sort_by_alpha,
            'A-Z',
            _sortBy == 'original_name.asc',
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
        child: Icon(Icons.sort, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildFilterButton() {
    return GestureDetector(
      onTap: _showFilterDialog,
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

  Widget _buildMenuRow(IconData icon, String text, bool isSelected) {
    return Row(
      children: [
        Icon(
          icon,
          color: isSelected ? widget.gradientColors[0] : Colors.grey,
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

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text(
                'Filter Anime',
                style: GoogleFonts.nunito(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Minimum Rating',
                      style: GoogleFonts.nunito(color: Colors.white),
                    ),
                    Slider(
                      value: _minRating,
                      min: 0.0,
                      max: 10.0,
                      divisions: 20,
                      activeColor: widget.gradientColors[0],
                      onChanged: (value) {
                        setDialogState(() {
                          _minRating = value;
                        });
                      },
                      label: _minRating.toStringAsFixed(1),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Minimum Vote Count',
                      style: GoogleFonts.nunito(color: Colors.white),
                    ),
                    Slider(
                      value: _minVoteCount.toDouble(),
                      min: 0.0,
                      max: 1000.0,
                      divisions: 20,
                      activeColor: widget.gradientColors[0],
                      onChanged: (value) {
                        setDialogState(() {
                          _minVoteCount = value.toInt();
                        });
                      },
                      label: _minVoteCount.toString(),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Language',
                      style: GoogleFonts.nunito(color: Colors.white),
                    ),
                    DropdownButton<String>(
                      value: _originalLanguage,
                      dropdownColor: Colors.grey[800],
                      items: [
                        DropdownMenuItem(
                          value: 'ja',
                          child: Text(
                            'Japanese',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'en',
                          child: Text(
                            'English',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'ko',
                          child: Text(
                            'Korean',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'zh',
                          child: Text(
                            'Chinese',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            _originalLanguage = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _minRating = 0.0;
                      _minVoteCount = 0;
                      _originalLanguage = 'ja';
                    });
                    Navigator.of(context).pop();
                    _fetchAnime();
                  },
                  child: Text('Reset', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      currentPage = 1;
                    });
                    _fetchAnime();
                  },
                  child: Text(
                    'Apply',
                    style: TextStyle(color: widget.gradientColors[0]),
                  ),
                ),
              ],
            );
          },
        );
      },
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
              onPressed: _fetchAnime,
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
    final animeToShow = isSearching ? searchResults : animeList;

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
              'No anime found for "$searchQuery"',
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
              itemCount: animeToShow.length + (!isSearching && hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < animeToShow.length) {
                  return _buildAnimeCard(animeToShow[index], index);
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
