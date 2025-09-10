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

      // Poll for status updates
      return await _pollSearchStatus(searchId, onStatusUpdate);
    } catch (e) {
      throw Exception('Search failed: $e');
    }
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

  Future<Map<String, dynamic>> _pollSearchStatus(
    String searchId,
    Function(String)? onStatusUpdate,
  ) async {
    const maxAttempts = 120; // 2 minutes with 1-second intervals
    int attempts = 0;

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
          .get(Uri.parse(baseUrl), headers: {'Accept': 'text/html'})
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
}
