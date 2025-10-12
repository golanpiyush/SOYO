import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ExploreTvApi {
  static const String baseUrl = 'https://cinemaos.me/api/tmdb';
  static const String tmdbBaseUrl = 'https://api.themoviedb.org/3';
  static const String tmdbApiKey = 'ad301b7cc82ffe19273e55e4d4206885';
  static const String tmdbImageBaseUrl = 'https://image.tmdb.org/t/p';

  // ✅ OMDb API
  static const String omdbBaseUrl = 'http://www.omdbapi.com/';
  static const String omdbApiKey = '16c27680';

  // Cache configuration
  static const Duration cacheExpiration = Duration(days: 3);
  static const String cachePrefix = 'tv_api_cache_';

  // Retry configuration
  static const int maxRetries = 10;
  static const Duration requestTimeout = Duration(seconds: 2);
  static const Duration retryDelay = Duration(milliseconds: 500);

  // Provider IDs for different streaming services
  static const Map<String, int> providers = {
    'Netflix': 8,
    'Apple TV': 350,
    'Prime Video': 9,
    'Disney+': 337,
    'HBO Max': 1899,
    'Hulu': 15,
    'Paramount+': 531,
  };

  // Language codes for popular languages
  static const Map<String, String> languageCodes = {
    'English': 'en',
    'Hindi': 'hi',
    'Korean': 'ko',
    'Japanese': 'ja',
    'Chinese': 'zh',
    'Spanish': 'es',
    'French': 'fr',
    'German': 'de',
    'Italian': 'it',
    'Portuguese': 'pt',
  };

  // -----------------------------------------------------------
  // 🔹 Cache Management Methods
  // -----------------------------------------------------------

  /// Generate cache key for API calls
  static String _generateCacheKey(
    String endpoint,
    Map<String, dynamic>? params,
  ) {
    final paramString =
        params?.entries.map((e) => '${e.key}=${e.value}').join('&') ?? '';
    return '$cachePrefix${endpoint}_$paramString';
  }

  /// Check if cached data is still valid
  static Future<bool> _isCacheValid(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampKey = '${cacheKey}_timestamp';
      final timestamp = prefs.getInt(timestampKey);

      if (timestamp == null) return false;

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();

      return now.difference(cacheTime) < cacheExpiration;
    } catch (e) {
      print('Cache validation error: $e');
      return false;
    }
  }

  /// Get data from cache
  static Future<Map<String, dynamic>?> _getFromCache(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(cacheKey);

      if (cachedData != null && await _isCacheValid(cacheKey)) {
        return json.decode(cachedData);
      }

      return null;
    } catch (e) {
      print('Cache retrieval error: $e');
      return null;
    }
  }

  /// Save data to cache
  static Future<void> _saveToCache(
    String cacheKey,
    Map<String, dynamic> data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampKey = '${cacheKey}_timestamp';

      await prefs.setString(cacheKey, json.encode(data));
      await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Cache saving error: $e');
    }
  }

  /// Clear expired cache entries
  static Future<void> clearExpiredCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where((key) => key.startsWith(cachePrefix))
          .toList();

      for (final key in keys) {
        if (key.endsWith('_timestamp')) continue;

        if (!await _isCacheValid(key)) {
          await prefs.remove(key);
          await prefs.remove('${key}_timestamp');
        }
      }
    } catch (e) {
      print('Cache cleanup error: $e');
    }
  }

  /// Clear all cache
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where((key) => key.startsWith(cachePrefix))
          .toList();

      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      print('Clear all cache error: $e');
    }
  }

  /// Helper method to make HTTP requests with retry mechanism and caching
  static Future<http.Response> _makeRequestWithRetry(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
    int retries = maxRetries,
  }) async {
    Exception? lastException;

    for (int attempt = 0; attempt < retries; attempt++) {
      try {
        final response = await http
            .get(
              Uri.parse(url),
              headers:
                  headers ??
                  {
                    'Accept': 'application/json',
                    'Content-Type': 'application/json',
                  },
            )
            .timeout(timeout ?? requestTimeout);

        if (response.statusCode == 200) {
          return response;
        } else {
          lastException = Exception('HTTP ${response.statusCode}');
        }
      } catch (e) {
        lastException = Exception('Request failed: $e');
      }

      // Wait before retrying (except on last attempt)
      if (attempt < retries - 1) {
        await Future.delayed(retryDelay);
      }
    }

    throw lastException ?? Exception('All retry attempts failed');
  }

  /// Generic method for cached API calls
  static Future<Map<String, dynamic>> _cachedApiCall(
    String endpoint,
    String url, {
    Map<String, dynamic>? params,
    bool useCache = true,
  }) async {
    if (useCache) {
      final cacheKey = _generateCacheKey(endpoint, params);
      final cachedData = await _getFromCache(cacheKey);

      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      final response = await _makeRequestWithRetry(url);
      final data = json.decode(response.body);

      if (useCache) {
        final cacheKey = _generateCacheKey(endpoint, params);
        await _saveToCache(cacheKey, data);
      }

      return data;
    } catch (e) {
      throw Exception('API call failed: $e');
    }
  }

  // -----------------------------------------------------------
  // 🔹 Language-Specific Methods
  // -----------------------------------------------------------

  /// Get TV shows by language
  static Future<Map<String, dynamic>> getTvShowsByLanguage(
    String languageCode, {
    int page = 1,
    bool useCache = true,
  }) async {
    final params = {'language': languageCode, 'page': page};
    final url =
        '$tmdbBaseUrl/discover/tv?api_key=$tmdbApiKey&with_original_language=$languageCode&page=$page&sort_by=popularity.desc';

    return _cachedApiCall(
      'tv_by_language',
      url,
      params: params,
      useCache: useCache,
    );
  }

  /// Get English TV shows
  static Future<Map<String, dynamic>> getEnglishTvShows({
    int page = 1,
    bool useCache = true,
  }) async {
    return getTvShowsByLanguage(
      languageCodes['English']!,
      page: page,
      useCache: useCache,
    );
  }

  /// Get Hindi TV shows
  static Future<Map<String, dynamic>> getHindiTvShows({
    int page = 1,
    bool useCache = true,
  }) async {
    return getTvShowsByLanguage(
      languageCodes['Hindi']!,
      page: page,
      useCache: useCache,
    );
  }

  /// Get Korean TV shows (K-dramas)
  static Future<Map<String, dynamic>> getKoreanTvShows({
    int page = 1,
    bool useCache = true,
  }) async {
    return getTvShowsByLanguage(
      languageCodes['Korean']!,
      page: page,
      useCache: useCache,
    );
  }

  /// Get Japanese TV shows (J-dramas)
  static Future<Map<String, dynamic>> getJapaneseTvShows({
    int page = 1,
    bool useCache = true,
  }) async {
    return getTvShowsByLanguage(
      languageCodes['Japanese']!,
      page: page,
      useCache: useCache,
    );
  }

  /// Get Chinese TV shows
  static Future<Map<String, dynamic>> getChineseTvShows({
    int page = 1,
    bool useCache = true,
  }) async {
    return getTvShowsByLanguage(
      languageCodes['Chinese']!,
      page: page,
      useCache: useCache,
    );
  }

  /// Get Spanish TV shows
  static Future<Map<String, dynamic>> getSpanishTvShows({
    int page = 1,
    bool useCache = true,
  }) async {
    return getTvShowsByLanguage(
      languageCodes['Spanish']!,
      page: page,
      useCache: useCache,
    );
  }

  /// Get French TV shows
  static Future<Map<String, dynamic>> getFrenchTvShows({
    int page = 1,
    bool useCache = true,
  }) async {
    return getTvShowsByLanguage(
      languageCodes['French']!,
      page: page,
      useCache: useCache,
    );
  }

  /// Get German TV shows
  static Future<Map<String, dynamic>> getGermanTvShows({
    int page = 1,
    bool useCache = true,
  }) async {
    return getTvShowsByLanguage(
      languageCodes['German']!,
      page: page,
      useCache: useCache,
    );
  }

  /// Get Italian TV shows
  static Future<Map<String, dynamic>> getItalianTvShows({
    int page = 1,
    bool useCache = true,
  }) async {
    return getTvShowsByLanguage(
      languageCodes['Italian']!,
      page: page,
      useCache: useCache,
    );
  }

  /// Get Portuguese TV shows
  static Future<Map<String, dynamic>> getPortugueseTvShows({
    int page = 1,
    bool useCache = true,
  }) async {
    return getTvShowsByLanguage(
      languageCodes['Portuguese']!,
      page: page,
      useCache: useCache,
    );
  }

  /// Get all language TV shows in parallel
  static Future<Map<String, Map<String, dynamic>>> getAllLanguageTvShows({
    int page = 1,
    bool useCache = true,
  }) async {
    try {
      final results = <String, Map<String, dynamic>>{};

      final futures = languageCodes.entries.map((entry) async {
        try {
          final shows = await getTvShowsByLanguage(
            entry.value,
            page: page,
            useCache: useCache,
          );
          return MapEntry(entry.key, shows);
        } catch (e) {
          print('Failed to load ${entry.key} shows: $e');
          return MapEntry(entry.key, <String, dynamic>{});
        }
      });

      final completedFutures = await Future.wait(futures);

      for (final entry in completedFutures) {
        results[entry.key] = entry.value;
      }

      return results;
    } catch (e) {
      throw Exception('Failed to load all language shows: $e');
    }
  }

  // -----------------------------------------------------------
  // 🔹 Enhanced Provider Methods with Caching
  // -----------------------------------------------------------

  static Future<Map<String, dynamic>> getTvShowsByProvider(
    int providerId, {
    int page = 1,
    bool useCache = true,
  }) async {
    final params = {'provider_id': providerId, 'page': page};

    // Use TMDB API directly for better provider filtering
    final url =
        '$tmdbBaseUrl/discover/tv?api_key=$tmdbApiKey'
        '&with_watch_providers=$providerId'
        '&watch_region=US' // Change region if needed
        '&language=en-US'
        '&sort_by=popularity.desc'
        '&page=$page';

    return _cachedApiCall(
      'tv_by_provider',
      url,
      params: params,
      useCache: useCache,
    );
  }

  /// Fast provider search - combines search and provider filtering in one API call
  static Future<Map<String, dynamic>> searchTvShowsWithProvider(
    String query,
    int providerId, {
    int page = 1,
    bool useCache = false,
  }) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);

      // First, do a general TV search
      final searchUrl =
          '$tmdbBaseUrl/search/tv?api_key=$tmdbApiKey&language=en-US&query=$encodedQuery&page=$page';

      final searchResponse = await _makeRequestWithRetry(searchUrl);
      final searchData = json.decode(searchResponse.body);

      if (searchData['results'] == null ||
          (searchData['results'] as List).isEmpty) {
        return {'results': [], 'total_pages': 0, 'total_results': 0};
      }

      // Get provider shows to verify availability
      List<int> providerShowIds = [];
      int providerPage = 1;

      // Load multiple pages of provider shows to ensure comprehensive coverage
      while (providerPage <= 10) {
        final providerUrl =
            '$tmdbBaseUrl/discover/tv?api_key=$tmdbApiKey'
            '&with_watch_providers=$providerId'
            '&watch_region=US'
            '&language=en-US'
            '&sort_by=popularity.desc'
            '&page=$providerPage';

        try {
          final providerResponse = await _makeRequestWithRetry(providerUrl);
          final providerData = json.decode(providerResponse.body);

          final pageShows = providerData['results'] as List? ?? [];
          providerShowIds.addAll(
            pageShows.map((show) => show['id'] as int).toList(),
          );

          if (providerPage >= (providerData['total_pages'] ?? 1)) break;
          providerPage++;
        } catch (e) {
          print('Error loading provider page $providerPage: $e');
          break;
        }
      }

      // Filter search results to only include shows available on this provider
      final filteredResults = (searchData['results'] as List).where((show) {
        final showId = show['id'] as int;
        return providerShowIds.contains(showId);
      }).toList();

      return {
        'results': filteredResults,
        'total_pages': 1,
        'total_results': filteredResults.length,
      };
    } catch (e) {
      print('Provider search error: $e');
      throw Exception('Provider search failed: $e');
    }
  }

  // Get TV show details from TMDB with caching
  static Future<Map<String, dynamic>> getTvShowDetails(
    int showId, {
    bool useCache = true,
  }) async {
    final params = {'show_id': showId};
    final url = '$tmdbBaseUrl/tv/$showId?api_key=$tmdbApiKey&language=en-US';

    return _cachedApiCall(
      'tv_details',
      url,
      params: params,
      useCache: useCache,
    );
  }

  // -----------------------------------------------------------
  // 🔹 OMDb Methods with Retry and Caching
  // -----------------------------------------------------------

  /// Get all episodes for a given season by IMDb ID with retry mechanism and caching
  static Future<Map<String, dynamic>> getOmdbSeasonEpisodes(
    String imdbId,
    int season, {
    bool useCache = true,
  }) async {
    final params = {'imdb_id': imdbId, 'season': season};

    if (useCache) {
      final cacheKey = _generateCacheKey('omdb_season', params);
      final cachedData = await _getFromCache(cacheKey);

      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      final url = '$omdbBaseUrl?i=$imdbId&Season=$season&apikey=$omdbApiKey';
      final response = await _makeRequestWithRetry(url);
      final data = json.decode(response.body);

      // Check if the response contains valid episode data
      if (data['Response'] == 'True' && data['Episodes'] != null) {
        if (useCache) {
          final cacheKey = _generateCacheKey('omdb_season', params);
          await _saveToCache(cacheKey, data);
        }
        return data;
      } else {
        throw Exception(
          'Invalid season data: ${data['Error'] ?? 'No episodes found'}',
        );
      }
    } catch (e) {
      throw Exception('OMDb season error: $e');
    }
  }

  /// Get a specific episode from OMDb with retry mechanism and caching
  static Future<Map<String, dynamic>> getOmdbEpisode(
    String imdbId,
    int season,
    int episode, {
    bool useCache = true,
  }) async {
    final params = {'imdb_id': imdbId, 'season': season, 'episode': episode};

    if (useCache) {
      final cacheKey = _generateCacheKey('omdb_episode', params);
      final cachedData = await _getFromCache(cacheKey);

      if (cachedData != null) {
        return cachedData;
      }
    }

    try {
      final url =
          '$omdbBaseUrl?i=$imdbId&Season=$season&Episode=$episode&apikey=$omdbApiKey';
      final response = await _makeRequestWithRetry(url);
      final data = json.decode(response.body);

      // Check if the response contains valid episode data
      if (data['Response'] == 'True' && data['Title'] != null) {
        if (useCache) {
          final cacheKey = _generateCacheKey('omdb_episode', params);
          await _saveToCache(cacheKey, data);
        }
        return data;
      } else {
        throw Exception(
          'Invalid episode data: ${data['Error'] ?? 'Episode not found'}',
        );
      }
    } catch (e) {
      throw Exception('OMDb episode error: $e');
    }
  }

  // Get season episodes from TMDB with retry mechanism and caching
  static Future<Map<String, dynamic>> getSeasonEpisodes(
    int showId,
    int seasonNumber, {
    bool useCache = true,
  }) async {
    final params = {'show_id': showId, 'season': seasonNumber};
    final url =
        '$tmdbBaseUrl/tv/$showId/season/$seasonNumber?api_key=$tmdbApiKey&language=en-US';

    return _cachedApiCall(
      'tmdb_season',
      url,
      params: params,
      useCache: useCache,
    );
  }

  /// Get detailed episode information from TMDB with retry mechanism and caching
  static Future<Map<String, dynamic>> getTmdbEpisodeDetails(
    int showId,
    int seasonNumber,
    int episodeNumber, {
    bool useCache = true,
  }) async {
    final params = {
      'show_id': showId,
      'season': seasonNumber,
      'episode': episodeNumber,
    };
    final url =
        '$tmdbBaseUrl/tv/$showId/season/$seasonNumber/episode/$episodeNumber?api_key=$tmdbApiKey&language=en-US';

    return _cachedApiCall(
      'tmdb_episode',
      url,
      params: params,
      useCache: useCache,
    );
  }

  /// Get all seasons for a show with retry mechanism and caching
  static Future<List<Map<String, dynamic>>> getAllSeasons(
    int showId, {
    bool useCache = true,
  }) async {
    try {
      // First get the show details to know how many seasons exist
      final showDetails = await getTvShowDetails(showId, useCache: useCache);
      final seasons = showDetails['seasons'] as List?;

      if (seasons == null || seasons.isEmpty) {
        throw Exception('No seasons found for show ID: $showId');
      }

      List<Map<String, dynamic>> allSeasonsData = [];

      for (var season in seasons) {
        final seasonNumber = season['season_number'] as int;
        // Skip season 0 (specials) unless specifically needed
        if (seasonNumber > 0) {
          try {
            final seasonData = await getSeasonEpisodes(
              showId,
              seasonNumber,
              useCache: useCache,
            );
            allSeasonsData.add(seasonData);
          } catch (e) {
            print('Failed to load season $seasonNumber: $e');
            // Continue with other seasons even if one fails
          }
        }
      }

      return allSeasonsData;
    } catch (e) {
      throw Exception('Failed to load all seasons: $e');
    }
  }

  // Helper method to get original language
  static String getOriginalLanguage(Map<String, dynamic> showData) {
    return showData['original_language']?.toString() ?? 'en';
  }

  // Helper method to get original name
  static String getOriginalName(Map<String, dynamic> showData) {
    return showData['original_name']?.toString() ?? '';
  }

  // Helper method to get large backdrop URL
  static String getBackdropUrlLarge(Map<String, dynamic> showData) {
    final backdropPath = showData['backdrop_path']?.toString();
    if (backdropPath != null && backdropPath.isNotEmpty) {
      return '$tmdbImageBaseUrl/w1280$backdropPath';
    }

    // Fallback to poster if no backdrop available
    final posterPath = showData['poster_path']?.toString();
    if (posterPath != null && posterPath.isNotEmpty) {
      return '$tmdbImageBaseUrl/w1280$posterPath';
    }

    // Final fallback
    return 'https://via.placeholder.com/1280x720/333/fff?text=No+Image';
  }

  // Helper method to get poster URL
  static String getPosterUrl(
    Map<String, dynamic> showData, {
    String size = 'w500',
  }) {
    final posterPath = showData['poster_path']?.toString();
    if (posterPath != null && posterPath.isNotEmpty) {
      return '$tmdbImageBaseUrl/$size$posterPath';
    }
    return 'https://via.placeholder.com/500x750/333/fff?text=No+Image';
  }

  // -----------------------------------------------------------
  // 🔹 Enhanced Provider Methods with Caching
  // -----------------------------------------------------------

  // Get Netflix TV shows
  static Future<Map<String, dynamic>> getNetflixTvShows({
    int page = 1,
    bool useCache = true,
  }) async {
    return getTvShowsByProvider(
      providers['Netflix']!,
      page: page,
      useCache: useCache,
    );
  }

  // Get Apple TV shows
  static Future<Map<String, dynamic>> getAppleTvShows({
    int page = 1,
    bool useCache = true,
  }) async {
    return getTvShowsByProvider(
      providers['Apple TV']!,
      page: page,
      useCache: useCache,
    );
  }

  // Get Prime Video shows
  static Future<Map<String, dynamic>> getPrimeVideoShows({
    int page = 1,
    bool useCache = true,
  }) async {
    return getTvShowsByProvider(
      providers['Prime Video']!,
      page: page,
      useCache: useCache,
    );
  }

  // Get Disney+ shows
  static Future<Map<String, dynamic>> getDisneyShows({
    int page = 1,
    bool useCache = true,
  }) async {
    return getTvShowsByProvider(
      providers['Disney+']!,
      page: page,
      useCache: useCache,
    );
  }

  // Get HBO Max shows
  static Future<Map<String, dynamic>> getHboMaxShows({
    int page = 1,
    bool useCache = true,
  }) async {
    return getTvShowsByProvider(
      providers['HBO Max']!,
      page: page,
      useCache: useCache,
    );
  }

  // Get Hulu shows
  static Future<Map<String, dynamic>> getHuluShows({
    int page = 1,
    bool useCache = true,
  }) async {
    return getTvShowsByProvider(
      providers['Hulu']!,
      page: page,
      useCache: useCache,
    );
  }

  // Get Paramount+ shows
  static Future<Map<String, dynamic>> getParamountShows({
    int page = 1,
    bool useCache = true,
  }) async {
    return getTvShowsByProvider(
      providers['Paramount+']!,
      page: page,
      useCache: useCache,
    );
  }

  // Get all provider shows in parallel with caching
  static Future<List<Map<String, dynamic>>> getAllProviderShows({
    bool useCache = true,
  }) async {
    try {
      final futures = providers.values
          .map(
            (providerId) =>
                getTvShowsByProvider(providerId, useCache: useCache),
          )
          .toList();

      return await Future.wait(futures);
    } catch (e) {
      throw Exception('Failed to load all provider shows: $e');
    }
  }

  // Search TV shows with caching
  static Future<Map<String, dynamic>> searchTvShows(
    String query, {
    int page = 1,
    bool useCache = true,
  }) async {
    final params = {'query': query, 'page': page};
    final encodedQuery = Uri.encodeComponent(query);
    final url =
        '$tmdbBaseUrl/search/tv?api_key=$tmdbApiKey&language=en-US&query=$encodedQuery&page=$page';

    return _cachedApiCall('search_tv', url, params: params, useCache: useCache);
  }

  // Get popular TV shows with caching
  static Future<Map<String, dynamic>> getPopularTvShows({
    int page = 1,
    bool useCache = true,
  }) async {
    final params = {'page': page};
    final url =
        '$tmdbBaseUrl/tv/popular?api_key=$tmdbApiKey&language=en-US&page=$page';

    return _cachedApiCall(
      'popular_tv',
      url,
      params: params,
      useCache: useCache,
    );
  }

  // Get top rated TV shows with caching
  static Future<Map<String, dynamic>> getTopRatedTvShows({
    int page = 1,
    bool useCache = true,
  }) async {
    final params = {'page': page};
    final url =
        '$tmdbBaseUrl/tv/top_rated?api_key=$tmdbApiKey&language=en-US&page=$page';

    return _cachedApiCall(
      'top_rated_tv',
      url,
      params: params,
      useCache: useCache,
    );
  }

  // Get trending TV shows with caching
  static Future<Map<String, dynamic>> getTrendingTvShows({
    String timeWindow = 'week',
    int page = 1,
    bool useCache = true,
  }) async {
    final params = {'time_window': timeWindow, 'page': page};
    final url =
        '$tmdbBaseUrl/trending/tv/$timeWindow?api_key=$tmdbApiKey&page=$page';

    return _cachedApiCall(
      'trending_tv',
      url,
      params: params,
      useCache: useCache,
    );
  }
}
