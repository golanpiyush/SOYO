import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CacheEntry {
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final Duration maxAge;

  CacheEntry(this.data, this.timestamp, this.maxAge);

  bool get isExpired => DateTime.now().difference(timestamp) > maxAge;
}

class ExploreApi {
  // Cineby base URL for movie lists
  static const String cinebyBaseUrl = 'https://db.cineby.app/3';
  // TMDB base URL for detailed information
  static const String tmdbBaseUrl = 'https://api.themoviedb.org/3';
  static const String apiKey = 'ad301b7cc82ffe19273e55e4d4206885';

  // Timeout duration
  static const Duration _timeout = Duration(seconds: 30);

  // Rate limiting - maximum concurrent requests
  static const int _maxConcurrentRequests = 3;
  static int _activeRequests = 0;
  static final List<Completer<void>> _requestQueue = [];

  // Delay between requests (in milliseconds)
  static const int _delayBetweenRequests = 500;
  static DateTime? _lastRequestTime;

  // Retry configuration
  static const int _maxRetries = 3;
  static const int _baseRetryDelayMs = 1000;

  // Cache storage
  static final Map<String, CacheEntry> _cache = <String, CacheEntry>{};

  // Cache durations for different types of data
  static const Duration _movieListCacheDuration = Duration(days: 2);
  static const Duration _movieDetailsCacheDuration = Duration(days: 2);
  static const Duration _genresCacheDuration = Duration(days: 2);
  static const Duration _personDetailsCacheDuration = Duration(days: 2);
  static const Duration _searchCacheDuration = Duration(days: 2);

  // full cache files
  static const String _cachePrefix = 'api_cache_';
  static const String _cacheTimestampPrefix = 'api_cache_ts_';

  // Request queue management
  static Future<void> _acquireRequestSlot() async {
    // Enforce delay between requests
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
      final requiredDelay = Duration(milliseconds: _delayBetweenRequests);

      if (timeSinceLastRequest < requiredDelay) {
        final waitTime = requiredDelay - timeSinceLastRequest;
        await Future.delayed(waitTime);
      }
    }

    // Wait if too many concurrent requests
    while (_activeRequests >= _maxConcurrentRequests) {
      final completer = Completer<void>();
      _requestQueue.add(completer);
      await completer.future;
    }

    _activeRequests++;
    _lastRequestTime = DateTime.now();
  }

  static void _releaseRequestSlot() {
    _activeRequests--;

    // Allow next queued request to proceed
    if (_requestQueue.isNotEmpty) {
      final completer = _requestQueue.removeAt(0);
      completer.complete();
    }
  }

  // Load cache from persistent storage on app start
  // Load cache from persistent storage on app start
  static Future<void> loadCacheFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      int loadedCount = 0;
      final Set<String> processedCacheKeys = {};

      for (final key in keys) {
        if (key.startsWith(_cachePrefix)) {
          final cacheKey = key.substring(_cachePrefix.length);

          // Skip if already processed
          if (processedCacheKeys.contains(cacheKey)) continue;
          processedCacheKeys.add(cacheKey);

          final timestampKey = '$_cacheTimestampPrefix$cacheKey';
          final maxAgeKey = '${timestampKey}_maxage';

          // Get the actual data string (not int)
          final dataJson = prefs.getString(key);
          final timestamp = prefs.getInt(timestampKey);
          final maxAgeMs = prefs.getInt(maxAgeKey);

          // Validate all required data exists
          if (dataJson != null &&
              dataJson.isNotEmpty &&
              timestamp != null &&
              maxAgeMs != null) {
            try {
              final data = json.decode(dataJson) as Map<String, dynamic>;
              final cacheTimestamp = DateTime.fromMillisecondsSinceEpoch(
                timestamp,
              );
              final maxAge = Duration(milliseconds: maxAgeMs);

              final entry = CacheEntry(data, cacheTimestamp, maxAge);

              // Only load if not expired
              if (!entry.isExpired) {
                _cache[cacheKey] = entry;
                loadedCount++;
              } else {
                // Clean up expired entries from disk
                await prefs.remove(key);
                await prefs.remove(timestampKey);
                await prefs.remove(maxAgeKey);
              }
            } catch (e) {
              print('⚠️  Skipping corrupted cache entry: $cacheKey - $e');
              // Clean up corrupted entry
              await prefs.remove(key);
              await prefs.remove(timestampKey);
              await prefs.remove(maxAgeKey);
            }
          }
        }
      }

      print('✅ Loaded $loadedCount cache entries from disk');
    } catch (e) {
      print('❌ Error loading cache from disk: $e');
    }
  }

  // Save cache entry to persistent storage
  // Save cache entry to persistent storage
  static Future<void> _saveCacheToDisk(
    String cacheKey,
    CacheEntry entry,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataKey = '$_cachePrefix$cacheKey';
      final timestampKey = '$_cacheTimestampPrefix$cacheKey';
      final maxAgeKey = '${timestampKey}_maxage';

      // Save all three values together
      final dataJson = json.encode(entry.data);
      await prefs.setString(dataKey, dataJson);
      await prefs.setInt(timestampKey, entry.timestamp.millisecondsSinceEpoch);
      await prefs.setInt(maxAgeKey, entry.maxAge.inMilliseconds);

      print('💾 Saved to disk: $cacheKey (${dataJson.length} bytes)');
    } catch (e) {
      print('❌ Error saving cache to disk: $e');
    }
  }

  // Clear all persistent cache
  static Future<void> clearPersistentCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where(
            (key) =>
                key.startsWith(_cachePrefix) ||
                key.startsWith(_cacheTimestampPrefix),
          )
          .toList();

      for (final key in keys) {
        await prefs.remove(key);
      }

      _cache.clear();
      print('✅ Persistent cache cleared');
    } catch (e) {
      print('❌ Error clearing persistent cache: $e');
    }
  }

  // Helper method to generate cache keys
  static String _generateCacheKey(
    String endpoint, [
    Map<String, dynamic>? params,
  ]) {
    if (params == null || params.isEmpty) {
      return endpoint;
    }
    final sortedParams = Map.fromEntries(
      params.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    final paramString = sortedParams.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    return '$endpoint?$paramString';
  }

  // Helper method to get data from cache or API with retry logic
  static Future<Map<String, dynamic>> _getCachedOrFetch(
    String cacheKey,
    Duration cacheDuration,
    Future<http.Response> Function() fetchFunction,
  ) async {
    // Check if data exists in cache and is not expired
    final cachedEntry = _cache[cacheKey];
    if (cachedEntry != null && !cachedEntry.isExpired) {
      print('✅ Cache hit for: $cacheKey');
      return cachedEntry.data;
    }

    print('❌ Cache miss for: $cacheKey - Fetching from API...');

    // Retry logic
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      await _acquireRequestSlot();

      try {
        // Fetch from API with timeout
        final response = await fetchFunction().timeout(
          _timeout,
          onTimeout: () {
            throw Exception(
              'Request timeout after ${_timeout.inSeconds} seconds',
            );
          },
        );

        print(
          '📡 API Response Status: ${response.statusCode} (attempt $attempt)',
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;

          // Store in cache
          final entry = CacheEntry(data, DateTime.now(), cacheDuration);
          _cache[cacheKey] = entry;

          // Save to disk synchronously to ensure it persists
          await _saveCacheToDisk(cacheKey, entry);

          print('✅ Data fetched and cached successfully');
          return data;
        } else {
          print('❌ API Error Response: ${response.body}');
          throw Exception(
            'Failed to load data from API (Status: ${response.statusCode})',
          );
        }
      } catch (e) {
        _releaseRequestSlot();

        final isLastAttempt = attempt == _maxRetries;
        final isConnectionReset = e.toString().contains('Connection reset');

        if (isConnectionReset && !isLastAttempt) {
          // Exponential backoff: 1s, 2s, 3s
          final retryDelay = _baseRetryDelayMs * attempt;
          print(
            '⚠️  Connection reset on attempt $attempt/$_maxRetries, retrying in ${retryDelay}ms...',
          );
          await Future.delayed(Duration(milliseconds: retryDelay));
          continue;
        }

        print('❌ Error in _getCachedOrFetch (attempt $attempt): $e');
        rethrow;
      } finally {
        // Only release if we're done (success or final failure)
        if (_activeRequests > 0) {
          _releaseRequestSlot();
        }
      }
    }

    // This should never be reached due to rethrow, but satisfies return type
    throw Exception('Max retries exceeded');
  }

  // Clear all cache
  static Future<void> clearCache() async {
    await clearPersistentCache();
  }

  // Clear expired cache entries
  static void clearExpiredCache() {
    _cache.removeWhere((key, entry) => entry.isExpired);
    print('Expired cache entries cleared');
  }

  // Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    final validEntries = _cache.values
        .where((entry) => !entry.isExpired)
        .length;
    final expiredEntries = _cache.length - validEntries;

    return {
      'total_entries': _cache.length,
      'valid_entries': validEntries,
      'expired_entries': expiredEntries,
      'cache_size_kb': _estimateCacheSize(),
      'active_requests': _activeRequests,
      'queued_requests': _requestQueue.length,
    };
  }

  static double _estimateCacheSize() {
    // Rough estimation of cache size in KB
    int totalSize = 0;
    for (final entry in _cache.values) {
      totalSize += json.encode(entry.data).length;
    }
    return totalSize / 1024.0; // Convert to KB
  }

  // Get popular movies from Cineby (cached)
  static Future<Map<String, dynamic>> getPopularMovies({int page = 1}) async {
    final cacheKey = _generateCacheKey('popular_movies', {'page': page});

    return _getCachedOrFetch(
      cacheKey,
      _movieListCacheDuration,
      () => http.get(
        Uri.parse('$cinebyBaseUrl/movie/popular?page=$page&api_key=$apiKey'),
      ),
    );
  }

  // Get upcoming movies from Cineby (cached)
  static Future<Map<String, dynamic>> getUpcomingMovies({int page = 1}) async {
    final cacheKey = _generateCacheKey('upcoming_movies', {'page': page});

    return _getCachedOrFetch(
      cacheKey,
      _movieListCacheDuration,
      () => http.get(
        Uri.parse('$cinebyBaseUrl/movie/upcoming?page=$page&api_key=$apiKey'),
      ),
    );
  }

  // Get top rated movies from Cineby (cached)
  static Future<Map<String, dynamic>> getTopRatedMovies({int page = 1}) async {
    final cacheKey = _generateCacheKey('top_rated_movies', {'page': page});

    return _getCachedOrFetch(
      cacheKey,
      _movieListCacheDuration,
      () => http.get(
        Uri.parse('$cinebyBaseUrl/movie/top_rated?page=$page&api_key=$apiKey'),
      ),
    );
  }

  // Get movies by genre from Cineby (cached)
  static Future<Map<String, dynamic>> getMoviesByGenre(
    int genreId, {
    int page = 1,
  }) async {
    final cacheKey = _generateCacheKey('movies_by_genre', {
      'genre_id': genreId,
      'page': page,
    });

    return _getCachedOrFetch(
      cacheKey,
      _movieListCacheDuration,
      () => http.get(
        Uri.parse(
          '$cinebyBaseUrl/discover/movie?with_genres=$genreId&page=$page&api_key=$apiKey',
        ),
      ),
    );
  }

  // Get detailed movie information including cast and crew from TMDB (cached)
  static Future<Map<String, dynamic>> getMovieDetails(int movieId) async {
    final cacheKey = _generateCacheKey('movie_details', {'movie_id': movieId});

    return _getCachedOrFetch(
      cacheKey,
      _movieDetailsCacheDuration,
      () => http.get(
        Uri.parse(
          '$tmdbBaseUrl/movie/$movieId?api_key=$apiKey&append_to_response=credits,videos',
        ),
      ),
    );
  }

  // Get movie trailer from TMDB (cached)
  static Future<String?> getMovieTrailer(int movieId) async {
    final cacheKey = _generateCacheKey('movie_trailer', {'movie_id': movieId});

    // Check cache first
    final cachedEntry = _cache[cacheKey];
    if (cachedEntry != null && !cachedEntry.isExpired) {
      print('✅ Cache hit for trailer: $cacheKey');
      return cachedEntry.data['trailer_url'] as String?;
    }

    print('❌ Cache miss for trailer: $cacheKey');

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      await _acquireRequestSlot();

      try {
        final response = await http
            .get(
              Uri.parse('$tmdbBaseUrl/movie/$movieId/videos?api_key=$apiKey'),
            )
            .timeout(_timeout);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final videos = data['results'] as List<dynamic>;

          // Find the first trailer (usually YouTube)
          final trailer = videos.cast<Map<String, dynamic>?>().firstWhere(
            (video) =>
                video != null &&
                video['type'] == 'Trailer' &&
                video['site'] == 'YouTube',
            orElse: () => null,
          );

          final trailerUrl = trailer != null
              ? 'https://www.youtube.com/watch?v=${trailer['key']}'
              : null;

          // Cache the result
          _cache[cacheKey] = CacheEntry(
            {'trailer_url': trailerUrl},
            DateTime.now(),
            _movieDetailsCacheDuration,
          );

          _releaseRequestSlot();
          return trailerUrl;
        } else {
          print('❌ Trailer fetch failed with status: ${response.statusCode}');
        }
      } catch (e) {
        _releaseRequestSlot();

        final isLastAttempt = attempt == _maxRetries;
        final isConnectionReset = e.toString().contains('Connection reset');

        if (isConnectionReset && !isLastAttempt) {
          final retryDelay = _baseRetryDelayMs * attempt;
          print(
            '⚠️  Trailer fetch connection reset on attempt $attempt/$_maxRetries, retrying in ${retryDelay}ms...',
          );
          await Future.delayed(Duration(milliseconds: retryDelay));
          continue;
        }

        print('❌ Error fetching trailer: $e');
        if (isLastAttempt) break;
      }
    }

    return null;
  }

  // Search movies from Cineby (cached with shorter duration)
  static Future<Map<String, dynamic>> searchMovies(
    String query, {
    int page = 1,
  }) async {
    final encodedQuery = Uri.encodeComponent(query);
    final cacheKey = _generateCacheKey('search_movies', {
      'query': query,
      'page': page,
    });

    return _getCachedOrFetch(
      cacheKey,
      _searchCacheDuration,
      () => http.get(
        Uri.parse(
          '$cinebyBaseUrl/search/movie?query=$encodedQuery&page=$page&api_key=$apiKey',
        ),
      ),
    );
  }

  // Get movie recommendations from Cineby (cached)
  static Future<Map<String, dynamic>> getMovieRecommendations(
    int movieId, {
    int page = 1,
  }) async {
    final cacheKey = _generateCacheKey('movie_recommendations', {
      'movie_id': movieId,
      'page': page,
    });

    return _getCachedOrFetch(
      cacheKey,
      _movieListCacheDuration,
      () => http.get(
        Uri.parse(
          '$cinebyBaseUrl/movie/$movieId/recommendations?page=$page&api_key=$apiKey',
        ),
      ),
    );
  }

  // Get genres list from Cineby (cached for long duration)
  static Future<Map<String, dynamic>> getGenres() async {
    const cacheKey = 'genres_list';

    return _getCachedOrFetch(
      cacheKey,
      _genresCacheDuration,
      () => http.get(
        Uri.parse('$cinebyBaseUrl/genre/movie/list?api_key=$apiKey'),
      ),
    );
  }

  // Get person details (for cast/crew) from TMDB (cached)
  static Future<Map<String, dynamic>> getPersonDetails(int personId) async {
    final cacheKey = _generateCacheKey('person_details', {
      'person_id': personId,
    });

    return _getCachedOrFetch(
      cacheKey,
      _personDetailsCacheDuration,
      () => http.get(
        Uri.parse(
          '$tmdbBaseUrl/person/$personId?api_key=$apiKey&append_to_response=movie_credits',
        ),
      ),
    );
  }

  // Invalidate specific cache entries
  static void invalidateCache(String pattern) {
    _cache.removeWhere((key, value) => key.contains(pattern));
    print('Cache entries matching "$pattern" invalidated');
  }

  // Preload popular content with sequential loading to avoid rate limits
  static Future<void> preloadPopularContent() async {
    try {
      print(
        '🔄 Preloading popular content (sequential to avoid rate limits)...',
      );

      // Load one at a time to avoid overwhelming the API
      await getPopularMovies();
      await getTopRatedMovies();
      await getUpcomingMovies();
      await getGenres();

      print('✅ Popular content preloaded successfully');
    } catch (e) {
      print('❌ Error preloading content: $e');
    }
  }

  // Batch load genres with controlled concurrency
  static Future<List<Map<String, dynamic>>> getMoviesByGenres(
    List<int> genreIds, {
    int page = 1,
    bool skipErrors = true,
  }) async {
    print('🔄 Loading movies for ${genreIds.length} genres...');

    final results = <Map<String, dynamic>>[];
    int successCount = 0;
    int failCount = 0;

    // Process genres in smaller batches to respect rate limits
    for (final genreId in genreIds) {
      try {
        final movies = await getMoviesByGenre(genreId, page: page);
        results.add(movies);
        successCount++;
      } catch (e) {
        failCount++;
        print('❌ Error loading genre $genreId: $e');

        if (!skipErrors) {
          rethrow;
        }

        // Add empty result to maintain index alignment if needed
        results.add({'results': [], 'genre_id': genreId, 'error': true});
      }
    }

    print(
      '✅ Loaded movies for $successCount/${genreIds.length} genres successfully ($failCount failed)',
    );
    return results;
  }

  // Retry loading specific genres that failed
  static Future<Map<String, dynamic>?> retryGenre(
    int genreId, {
    int page = 1,
  }) async {
    print('🔄 Retrying genre $genreId after delay...');

    // Wait a bit before retrying to let the API cool down
    await Future.delayed(const Duration(seconds: 2));

    try {
      // Invalidate cache for this genre first
      invalidateCache('movies_by_genre?genre_id=$genreId');

      final movies = await getMoviesByGenre(genreId, page: page);
      print('✅ Retry successful for genre $genreId');
      return movies;
    } catch (e) {
      print('❌ Retry failed for genre $genreId: $e');
      return null;
    }
  }
}
