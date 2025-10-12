import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:soyo/Screens/javDetailsScreen.dart';
import 'package:soyo/Services/javScrapper.dart';
import 'package:soyo/models/javData.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AllJAVScreen extends StatefulWidget {
  final List<JAVVideo> preloadedVideos;
  final List<Color> gradientColors;

  const AllJAVScreen({
    Key? key,
    required this.preloadedVideos,
    required this.gradientColors,
  }) : super(key: key);

  @override
  _AllJAVScreenState createState() => _AllJAVScreenState();
}

class _AllJAVScreenState extends State<AllJAVScreen> {
  List<JAVVideo> _javVideos = [];
  List<JAVVideo> _filteredVideos = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final JAVScraper _javScraper = JAVScraper();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String _currentSearchQuery = '';
  int _currentPage = 1;
  bool _hasMorePages = false;
  bool _isLoadingMore = false;

  // Cache keys
  static const String _cacheKeyVideos = 'jav_cached_videos';
  static const String _cacheKeyTimestamp = 'jav_cache_timestamp';
  static const int _cacheValidityHours = 24;

  @override
  void initState() {
    super.initState();
    _loadJAVVideos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadJAVVideos() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Try to load from cache first
      final cachedVideos = await _loadFromCache();

      if (cachedVideos != null && cachedVideos.isNotEmpty) {
        setState(() {
          _javVideos = cachedVideos;
          _filteredVideos = cachedVideos;
          _isLoading = false;
        });
        print('Loaded ${cachedVideos.length} videos from cache');
        return;
      }

      // If no cache or expired, load from network
      print('Cache miss or expired, loading from network...');
      final response = await _javScraper.getPopularVideos(page: 1, limit: 50);

      setState(() {
        _javVideos = [...widget.preloadedVideos, ...response.videos];
        _filteredVideos = _javVideos;
        _hasMorePages = response.hasNextPage;
        _currentPage = 1;
        _isLoading = false;
      });

      // Save to cache
      await _saveToCache(_javVideos);
      print('Loaded and cached ${_javVideos.length} videos');
    } catch (e) {
      setState(() {
        _javVideos = widget.preloadedVideos;
        _filteredVideos = widget.preloadedVideos;
        _isLoading = false;
      });
      print('Error loading JAV videos: $e');
    }
  }

  Future<List<JAVVideo>?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKeyVideos);
      final cachedTimestamp = prefs.getInt(_cacheKeyTimestamp);

      if (cachedJson == null || cachedTimestamp == null) {
        return null;
      }

      // Check if cache is still valid
      final cacheAge = DateTime.now().millisecondsSinceEpoch - cachedTimestamp;
      final cacheAgeHours = cacheAge / (1000 * 60 * 60);

      if (cacheAgeHours > _cacheValidityHours) {
        print('Cache expired (${cacheAgeHours.toStringAsFixed(1)} hours old)');
        return null;
      }

      final List<dynamic> jsonList = jsonDecode(cachedJson);
      return jsonList.map((json) => JAVVideo.fromJson(json)).toList();
    } catch (e) {
      print('Error loading from cache: $e');
      return null;
    }
  }

  Future<void> _saveToCache(List<JAVVideo> videos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = videos.map((v) => v.toJson()).toList();
      await prefs.setString(_cacheKeyVideos, jsonEncode(jsonList));
      await prefs.setInt(
        _cacheKeyTimestamp,
        DateTime.now().millisecondsSinceEpoch,
      );
      print('Saved ${videos.length} videos to cache');
    } catch (e) {
      print('Error saving to cache: $e');
    }
  }

  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKeyVideos);
      await prefs.remove(_cacheKeyTimestamp);
      print('Cache cleared');
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _filteredVideos = _javVideos;
        _currentSearchQuery = '';
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _currentSearchQuery = query;
      _currentPage = 1;
    });

    try {
      final response = await _javScraper.searchVideos(
        query,
        page: 1,
        limit: 50,
      );

      setState(() {
        _filteredVideos = response.videos;
        _hasMorePages = response.hasNextPage;
        _isSearching = false;
      });

      print('Search returned ${response.videos.length} results for: $query');
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      print('Search error: $e');
      _showSnackBar('Search failed: $e');
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore || !_hasMorePages) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      JAVResponse response;

      if (_currentSearchQuery.isNotEmpty) {
        response = await _javScraper.searchVideos(
          _currentSearchQuery,
          page: _currentPage + 1,
          limit: 50,
        );
      } else {
        response = await _javScraper.getPopularVideos(
          page: _currentPage + 1,
          limit: 50,
        );
      }

      setState(() {
        if (_currentSearchQuery.isEmpty) {
          _javVideos.addAll(response.videos);
          _filteredVideos = _javVideos;
          // Update cache with new videos
          _saveToCache(_javVideos);
        } else {
          _filteredVideos.addAll(response.videos);
        }
        _currentPage++;
        _hasMorePages = response.hasNextPage;
        _isLoadingMore = false;
      });

      print('Loaded page $_currentPage with ${response.videos.length} videos');
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
      print('Error loading more videos: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: widget.gradientColors[0],
        duration: Duration(seconds: 2),
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
            colors: [Color(0xFF0A0A0A), Color(0xFF1A0A1A), Color(0xFF0A1A2A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              _buildSearchBar(),
              Expanded(child: _isLoading ? _buildLoading() : _buildJAVGrid()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: widget.gradientColors,
              ).createShader(bounds),
              child: Text(
                'JAV HD Collection',
                style: GoogleFonts.nunito(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          // Refresh cache button
          GestureDetector(
            onTap: () async {
              await _clearCache();
              await _loadJAVVideos();
              _showSnackBar('Cache refreshed');
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.refresh, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: widget.gradientColors),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_filteredVideos.length}',
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: Colors.white70, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: GoogleFonts.nunito(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Search JAV videos...',
                hintStyle: GoogleFonts.nunito(
                  color: Colors.white54,
                  fontSize: 16,
                ),
                border: InputBorder.none,
              ),
              onSubmitted: _performSearch,
            ),
          ),
          if (_isSearching)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: widget.gradientColors[0],
                strokeWidth: 2,
              ),
            )
          else if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                _performSearch('');
                _searchFocusNode.unfocus();
              },
              child: Icon(Icons.clear, color: Colors.white70, size: 20),
            ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: widget.gradientColors[0]),
          SizedBox(height: 15),
          Text(
            'Loading JAV Videos...',
            style: GoogleFonts.nunito(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildJAVGrid() {
    if (_filteredVideos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined, size: 64, color: Colors.white38),
            SizedBox(height: 16),
            Text(
              _currentSearchQuery.isEmpty
                  ? 'No videos available'
                  : 'No results for "$_currentSearchQuery"',
              style: GoogleFonts.nunito(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (!_isLoadingMore &&
            _hasMorePages &&
            scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 500) {
          _loadMoreVideos();
        }
        return false;
      },
      child: GridView.builder(
        padding: EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.7,
        ),
        itemCount: _filteredVideos.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _filteredVideos.length) {
            return Center(
              child: CircularProgressIndicator(color: widget.gradientColors[0]),
            );
          }
          return _buildJAVGridCard(_filteredVideos[index]);
        },
      ),
    );
  }

  Widget _buildJAVGridCard(JAVVideo javVideo) {
    return GestureDetector(
      onTap: () => _onJAVCardTap(javVideo),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: widget.gradientColors[0].withOpacity(0.3),
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: javVideo.posterUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.grey.shade900, Colors.grey.shade800],
                    ),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: widget.gradientColors[0],
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey.shade800,
                  child: Center(
                    child: Icon(
                      Icons.videocam_off,
                      color: Colors.white54,
                      size: 40,
                    ),
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
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        javVideo.title.length > 40
                            ? '${javVideo.title.substring(0, 40)}...'
                            : javVideo.title,
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: widget.gradientColors[0],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              javVideo.code,
                              style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.schedule, color: Colors.white70, size: 12),
                          SizedBox(width: 4),
                          Text(
                            javVideo.duration,
                            style: GoogleFonts.nunito(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      if (javVideo.uploadDate.isNotEmpty)
                        Text(
                          javVideo.uploadDate,
                          style: GoogleFonts.nunito(
                            color: Colors.white60,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    javVideo.duration,
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
    );
  }

  void _onJAVCardTap(JAVVideo javVideo) {
    print('JAV Video tapped: ${javVideo.title}');
    // Navigate to JAV detail screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => JAVDetailScreen(video: javVideo)),
    );
  }
}
