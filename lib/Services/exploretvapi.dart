import 'dart:convert';
import 'package:http/http.dart' as http;

class ExploreTvApi {
  static const String baseUrl = 'https://cinemaos.me/api/tmdb';
  static const String tmdbBaseUrl = 'https://api.themoviedb.org/3';
  static const String tmdbApiKey = 'ad301b7cc82ffe19273e55e4d4206885';
  static const String tmdbImageBaseUrl = 'https://image.tmdb.org/t/p';

  // ✅ OMDb API
  static const String omdbBaseUrl = 'http://www.omdbapi.com/';
  static const String omdbApiKey = '16c27680';

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

  /// Helper method to make HTTP requests with retry mechanism
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

  static Future<Map<String, dynamic>> getTvShowsByProvider(
    int providerId, {
    int page = 1,
  }) async {
    try {
      final url =
          '$baseUrl?requestID=withProvidersTv&provider_id=$providerId&language=en-US&page=$page';

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load TV shows: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get TV show details from TMDB
  static Future<Map<String, dynamic>> getTvShowDetails(int showId) async {
    try {
      final url = '$tmdbBaseUrl/tv/$showId?api_key=$tmdbApiKey&language=en-US';

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
          'Failed to load TV show details: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // -----------------------------------------------------------
  // 🔹 OMDb Methods with Retry
  // -----------------------------------------------------------

  /// Get all episodes for a given season by IMDb ID with retry mechanism
  static Future<Map<String, dynamic>> getOmdbSeasonEpisodes(
    String imdbId,
    int season,
  ) async {
    try {
      final url = '$omdbBaseUrl?i=$imdbId&Season=$season&apikey=$omdbApiKey';

      final response = await _makeRequestWithRetry(url);
      final data = json.decode(response.body);

      // Check if the response contains valid episode data
      if (data['Response'] == 'True' && data['Episodes'] != null) {
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

  /// Get a specific episode from OMDb with retry mechanism
  static Future<Map<String, dynamic>> getOmdbEpisode(
    String imdbId,
    int season,
    int episode,
  ) async {
    try {
      final url =
          '$omdbBaseUrl?i=$imdbId&Season=$season&Episode=$episode&apikey=$omdbApiKey';

      final response = await _makeRequestWithRetry(url);
      final data = json.decode(response.body);

      // Check if the response contains valid episode data
      if (data['Response'] == 'True' && data['Title'] != null) {
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

  // Get season episodes from TMDB with retry mechanism
  static Future<Map<String, dynamic>> getSeasonEpisodes(
    int showId,
    int seasonNumber,
  ) async {
    try {
      final url =
          '$tmdbBaseUrl/tv/$showId/season/$seasonNumber?api_key=$tmdbApiKey&language=en-US';

      final response = await _makeRequestWithRetry(url);
      final data = json.decode(response.body);

      // Check if the response contains valid season data
      if (data['episodes'] != null && data['episodes'] is List) {
        return data;
      } else {
        throw Exception('Invalid season data: No episodes found');
      }
    } catch (e) {
      throw Exception('TMDB season error: $e');
    }
  }

  /// Get detailed episode information from TMDB with retry mechanism
  static Future<Map<String, dynamic>> getTmdbEpisodeDetails(
    int showId,
    int seasonNumber,
    int episodeNumber,
  ) async {
    try {
      final url =
          '$tmdbBaseUrl/tv/$showId/season/$seasonNumber/episode/$episodeNumber?api_key=$tmdbApiKey&language=en-US';

      final response = await _makeRequestWithRetry(url);
      final data = json.decode(response.body);

      // Check if the response contains valid episode data
      if (data['id'] != null && data['name'] != null) {
        return data;
      } else {
        throw Exception('Invalid episode data: Episode details not found');
      }
    } catch (e) {
      throw Exception('TMDB episode details error: $e');
    }
  }

  /// Get all seasons for a show with retry mechanism
  static Future<List<Map<String, dynamic>>> getAllSeasons(int showId) async {
    try {
      // First get the show details to know how many seasons exist
      final showDetails = await getTvShowDetails(showId);
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
            final seasonData = await getSeasonEpisodes(showId, seasonNumber);
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

  // Get Netflix TV shows
  static Future<Map<String, dynamic>> getNetflixTvShows({int page = 1}) async {
    return getTvShowsByProvider(providers['Netflix']!, page: page);
  }

  // Get Apple TV shows
  static Future<Map<String, dynamic>> getAppleTvShows({int page = 1}) async {
    return getTvShowsByProvider(providers['Apple TV']!, page: page);
  }

  // Get Prime Video shows
  static Future<Map<String, dynamic>> getPrimeVideoShows({int page = 1}) async {
    return getTvShowsByProvider(providers['Prime Video']!, page: page);
  }

  // Get Disney+ shows
  static Future<Map<String, dynamic>> getDisneyShows({int page = 1}) async {
    return getTvShowsByProvider(providers['Disney+']!, page: page);
  }

  // Get HBO Max shows
  static Future<Map<String, dynamic>> getHboMaxShows({int page = 1}) async {
    return getTvShowsByProvider(providers['HBO Max']!, page: page);
  }

  // Get Hulu shows
  static Future<Map<String, dynamic>> getHuluShows({int page = 1}) async {
    return getTvShowsByProvider(providers['Hulu']!, page: page);
  }

  // Get Paramount+ shows
  static Future<Map<String, dynamic>> getParamountShows({int page = 1}) async {
    return getTvShowsByProvider(providers['Paramount+']!, page: page);
  }

  // Get all provider shows in parallel
  static Future<List<Map<String, dynamic>>> getAllProviderShows() async {
    try {
      final futures = providers.values
          .map((providerId) => getTvShowsByProvider(providerId))
          .toList();

      return await Future.wait(futures);
    } catch (e) {
      throw Exception('Failed to load all provider shows: $e');
    }
  }

  // Search TV shows
  static Future<Map<String, dynamic>> searchTvShows(
    String query, {
    int page = 1,
  }) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url =
          '$tmdbBaseUrl/search/tv?api_key=$tmdbApiKey&language=en-US&query=$encodedQuery&page=$page';

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to search TV shows: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get popular TV shows
  static Future<Map<String, dynamic>> getPopularTvShows({int page = 1}) async {
    try {
      final url =
          '$tmdbBaseUrl/tv/popular?api_key=$tmdbApiKey&language=en-US&page=$page';

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
          'Failed to load popular TV shows: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get top rated TV shows
  static Future<Map<String, dynamic>> getTopRatedTvShows({int page = 1}) async {
    try {
      final url =
          '$tmdbBaseUrl/tv/top_rated?api_key=$tmdbApiKey&language=en-US&page=$page';

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
          'Failed to load top rated TV shows: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get trending TV shows
  static Future<Map<String, dynamic>> getTrendingTvShows({
    String timeWindow = 'week',
    int page = 1,
  }) async {
    try {
      final url =
          '$tmdbBaseUrl/trending/tv/$timeWindow?api_key=$tmdbApiKey&page=$page';

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
          'Failed to load trending TV shows: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
