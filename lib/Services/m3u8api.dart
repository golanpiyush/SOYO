import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class M3U8Api {
  static const String baseUrl = 'https://0nnf7qzl-5000.inc1.devtunnels.ms';

  Future<Map<String, dynamic>> searchMovie({
    required String movieName,
    String? quality,
    bool fetchSubs = false,
    Function(String)? onStatusUpdate,
    Function(String)? onStreamReady, // Add stream ready callback
  }) async {
    try {
      // Start the search
      final startResponse = await http.post(
        Uri.parse('$baseUrl/search/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'moviename': movieName,
          'quality': quality,
          'fetch_subs': fetchSubs ? 'yes' : 'no',
        }),
      );

      if (startResponse.statusCode != 200) {
        throw Exception('Failed to start search: ${startResponse.statusCode}');
      }

      final startData = jsonDecode(startResponse.body);
      final searchId = startData['search_id'];

      if (searchId == null) {
        throw Exception('No search ID received');
      }

      // Poll for status updates with stream ready callback
      return await _pollSearchStatus(searchId, onStatusUpdate, onStreamReady);
    } catch (e) {
      throw Exception('Search failed: $e');
    }
  }

  // Add this method to your M3U8Api class
  Future<Map<String, dynamic>> searchAnime({
    required String animeName,
    String quality = '1080',
    bool fetchSubs = false,
    Function(String)? onStatusUpdate,
    Function(String)? onStreamReady,
  }) async {
    // Use the same movie search since anime are treated as movies
    return await searchMovie(
      movieName: animeName,
      quality: quality,
      fetchSubs: fetchSubs,
      onStatusUpdate: onStatusUpdate,
      onStreamReady: onStreamReady,
    );
  }

  // In M3U8Api class
  Future<List<dynamic>> searchMultipleMovies(String query) async {
    final response = await http.post(
      Uri.parse('$baseUrl/searchmultiples'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'moviename': query, 'max_results': 7}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['results'];
    } else {
      throw Exception('Failed to search movies');
    }
  }

  Future<List<dynamic>> searchMultipleTvShows(String query) async {
    final response = await http.post(
      Uri.parse('$baseUrl/searchmultiples'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'moviename': query, 'type': 'tv', 'max_results': 7}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['results'];
    } else {
      throw Exception('Failed to search TV shows');
    }
  }

  // Add this method to your M3U8Api class
  Future<List<String>> fetchTvSubtitles({
    required int tmdbId,
    required int seasonNumber,
    required int episodeNumber,
    String? showTitle,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tv/subtitles'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tmdb_id': tmdbId,
          'season_number': seasonNumber,
          'episode_number': episodeNumber,
          'title': showTitle ?? '',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final searchId = data['search_id'];

        if (searchId == null) {
          throw Exception('No search ID received for subtitle extraction');
        }

        // Poll for subtitle extraction status
        return await _pollSubtitleStatus(searchId);
      } else {
        throw Exception(
          'Failed to start subtitle extraction: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Subtitle extraction failed: $e');
    }
  }

  Future<Map<String, dynamic>> _pollSearchStatus(
    String searchId,
    Function(String)? onStatusUpdate,
    Function(String)? onStreamReady, // New callback for immediate stream
  ) async {
    const maxAttempts = 120; // 2 minutes with 1-second intervals
    int attempts = 0;
    bool streamSent = false; // Track if stream was already sent

    while (attempts < maxAttempts) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/search/status/$searchId'),
        );

        if (response.statusCode != 200) {
          throw Exception('Failed to get status: ${response.statusCode}');
        }

        final data = jsonDecode(response.body);
        final status = data['status'];

        // Update status callback
        if (onStatusUpdate != null && status != null) {
          onStatusUpdate(status);
        }

        // Handle immediate stream ready
        if (status == 'stream_ready' && !streamSent) {
          final movieData = data['data'];
          if (movieData != null && movieData['m3u8_link'] != null) {
            streamSent = true;

            // Call the stream ready callback immediately
            if (onStreamReady != null) {
              onStreamReady(movieData['m3u8_link']);
            }

            // Continue polling for subtitles if they're empty
            if (movieData['subtitles'] == null ||
                (movieData['subtitles'] as List).isEmpty) {
              // Update status to show subtitles are loading
              if (onStatusUpdate != null) {
                onStatusUpdate('Stream playing, loading subtitles...');
              }

              // Continue polling for subtitles
              await Future.delayed(Duration(seconds: 1));
              attempts++;
              continue;
            } else {
              // Stream and subtitles both available
              return {
                'm3u8_link': movieData['m3u8_link'],
                'subtitles': movieData['subtitles'] ?? [],
              };
            }
          }
        }

        // Handle final completion
        if (status == 'completed') {
          final movieData = data['data'];
          if (movieData == null) {
            throw Exception('No movie data received');
          }

          return {
            'm3u8_link': movieData['m3u8_link'],
            'subtitles': movieData['subtitles'] ?? [],
          };
        } else if (status == 'error') {
          throw Exception(data['error'] ?? 'Unknown error occurred');
        }

        // Wait before next poll
        await Future.delayed(Duration(seconds: 1));
        attempts++;
      } catch (e) {
        if (attempts >= maxAttempts - 1) {
          throw Exception('Polling failed: $e');
        }
        await Future.delayed(Duration(seconds: 1));
        attempts++;
      }
    }

    throw Exception('Search timed out after 2 minutes');
  }

  // Helper method to poll subtitle extraction status
  Future<List<String>> _pollSubtitleStatus(String searchId) async {
    const maxAttempts = 30; // 30 seconds max
    int attempts = 0;

    while (attempts < maxAttempts) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/search/status/$searchId'),
        );

        if (response.statusCode != 200) {
          throw Exception(
            'Failed to get subtitle status: ${response.statusCode}',
          );
        }

        final data = jsonDecode(response.body);
        final status = data['status'];

        if (status == 'completed') {
          final subtitleData = data['data'];
          if (subtitleData != null && subtitleData['subtitles'] != null) {
            final subtitles = List<String>.from(subtitleData['subtitles']);
            print('🎯 Found ${subtitles.length} subtitle files');
            return subtitles;
          }
          return [];
        } else if (status == 'error') {
          throw Exception(data['error'] ?? 'Subtitle extraction error');
        }

        // Wait before next poll
        await Future.delayed(Duration(seconds: 1));
        attempts++;
      } catch (e) {
        if (attempts >= maxAttempts - 1) {
          throw Exception('Subtitle polling failed: $e');
        }
        await Future.delayed(Duration(seconds: 1));
        attempts++;
      }
    }

    throw Exception('Subtitle extraction timed out');
  }

  // Alternative method using the original search endpoint (for backward compatibility)
  Future<Map<String, dynamic>> searchMovieDirect({
    required String movieName,
    String? quality,
    bool fetchSubs = false,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/search').replace(
        queryParameters: {
          'moviename': movieName,
          if (quality != null) 'quality': quality,
          'fetch_subs': fetchSubs ? 'yes' : 'no',
        },
      );

      final response = await http.get(uri).timeout(Duration(minutes: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return {
            'm3u8_link': data['data']['m3u8_link'],
            'subtitles': data['data']['subtitles'] ?? [],
          };
        } else {
          throw Exception(data['error'] ?? 'Unknown error');
        }
      } else if (response.statusCode == 404) {
        throw Exception('Movie not found');
      } else if (response.statusCode == 500) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Server error');
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    } catch (e) {
      if (e.toString().contains('SocketException')) {
        throw Exception('No internet connection');
      }
      rethrow;
    }
  }

  // Test API connectivity
  Future<bool> testConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Get movie info using direct movie name URL
  Future<Map<String, dynamic>> getMovieByPath(String movieName) async {
    try {
      final uri = Uri.parse('$baseUrl/$movieName');

      final response = await http.get(uri).timeout(Duration(minutes: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return {
            'm3u8_link': data['data']['m3u8_link'],
            'subtitles': data['data']['subtitles'] ?? [],
          };
        } else {
          throw Exception(data['error'] ?? 'Unknown error');
        }
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      throw Exception('Failed to get movie: $e');
    }
  }

  // Updated TV show search with immediate streaming support
  Future<Map<String, dynamic>> searchTvShow({
    required String showName,
    required int season,
    required int episode,
    String? quality,
    bool fetchSubs = false,
    Function(String)? onStatusUpdate,
    Function(String)? onStreamReady,
  }) async {
    try {
      // Start the search
      final startResponse = await http.post(
        Uri.parse('$baseUrl/search/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'moviename': showName,
          'tmdb_id': null, // We'll search by name first
          'type': 'tv',
          'season_number': season,
          'episode_number': episode,
          'quality': quality,
          'fetch_subs': fetchSubs ? 'yes' : 'no',
        }),
      );

      if (startResponse.statusCode != 200) {
        throw Exception('Failed to start search: ${startResponse.statusCode}');
      }

      final startData = jsonDecode(startResponse.body);
      final searchId = startData['search_id'];

      if (searchId == null) {
        throw Exception('No search ID received');
      }

      // Poll for status updates with stream ready callback
      return await _pollSearchStatus(searchId, onStatusUpdate, onStreamReady);
    } catch (e) {
      throw Exception('Search failed: $e');
    }
  }

  // Alternative method using direct TMDB ID
  Future<Map<String, dynamic>> searchTvShowByTmdbId({
    required int tmdbId,
    required int season,
    required int episode,
    String? quality,
    bool fetchSubs = false,
    Function(String)? onStatusUpdate,
    Function(String)? onStreamReady,
  }) async {
    try {
      // Start the search
      final startResponse = await http.post(
        Uri.parse('$baseUrl/search/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'moviename': '', // Empty name since we're using TMDB ID
          'tmdb_id': tmdbId.toString(),
          'type': 'tv',
          'season_number': season,
          'episode_number': episode,
          'quality': quality,
          'fetch_subs': fetchSubs ? 'yes' : 'no',
        }),
      );

      if (startResponse.statusCode != 200) {
        throw Exception('Failed to start search: ${startResponse.statusCode}');
      }

      final startData = jsonDecode(startResponse.body);
      final searchId = startData['search_id'];

      if (searchId == null) {
        throw Exception('No search ID received');
      }

      // Poll for status updates with stream ready callback
      return await _pollSearchStatus(searchId, onStatusUpdate, onStreamReady);
    } catch (e) {
      throw Exception('Search failed: $e');
    }
  }

  // Search movie by TMDB ID with immediate streaming
  Future<Map<String, dynamic>> searchMovieByTmdbId({
    required int tmdbId,
    String? quality,
    bool fetchSubs = false,
    Function(String)? onStatusUpdate,
    Function(String)? onStreamReady,
  }) async {
    try {
      // Start the search
      final startResponse = await http.post(
        Uri.parse('$baseUrl/search/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'moviename': '', // Empty name since we're using TMDB ID
          'tmdb_id': tmdbId.toString(),
          'type': 'movie',
          'quality': quality,
          'fetch_subs': fetchSubs ? 'yes' : 'no',
        }),
      );

      if (startResponse.statusCode != 200) {
        throw Exception('Failed to start search: ${startResponse.statusCode}');
      }

      final startData = jsonDecode(startResponse.body);
      final searchId = startData['search_id'];

      if (searchId == null) {
        throw Exception('No search ID received');
      }

      // Poll for status updates with stream ready callback
      return await _pollSearchStatus(searchId, onStatusUpdate, onStreamReady);
    } catch (e) {
      throw Exception('Search failed: $e');
    }
  }
}
