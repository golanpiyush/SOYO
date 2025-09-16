// anime_collection_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:soyo/models/anime_model.dart';

class AnimeCollectionApi {
  static const String _baseUrl = 'https://flixer.su/api/tmdb';
  static const String _discoverEndpoint = '/discover/tv';

  final http.Client client;

  AnimeCollectionApi({http.Client? client}) : client = client ?? http.Client();

  // Fetch anime with various filters
  Future<AnimeResponse> getAnime({
    int page = 1,
    String language = 'en-US',
    List<int>? genres,
    String? originalLanguage,
    int? minVoteCount,
    double? minVoteAverage,
    String sortBy = 'popularity.desc',
    String? query, // For search functionality
  }) async {
    // Build query parameters
    final Map<String, String> queryParams = {
      'language': language,
      'page': page.toString(),
    };

    // Add filters if provided
    if (genres != null && genres.isNotEmpty) {
      queryParams['with_genres'] = genres.join(',');
    }

    if (originalLanguage != null) {
      queryParams['with_original_language'] = originalLanguage;
    }

    if (minVoteCount != null) {
      queryParams['vote_count.gte'] = minVoteCount.toString();
    }

    if (minVoteAverage != null) {
      queryParams['vote_average.gte'] = minVoteAverage.toString();
    }

    if (sortBy.isNotEmpty) {
      queryParams['sort_by'] = sortBy;
    }

    // Determine endpoint based on whether we're searching or discovering
    final String endpoint = query != null ? '/search/tv' : _discoverEndpoint;

    // Add search query if provided
    if (query != null) {
      queryParams['query'] = query;
    }

    // Build URI
    final Uri uri = Uri.parse(
      '$_baseUrl$endpoint',
    ).replace(queryParameters: queryParams);

    try {
      // Make the request
      final response = await client.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return AnimeResponse.fromJson(data);
      } else {
        throw Exception('Failed to load anime: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load anime: $e');
    }
  }

  // Convenience method for getting popular anime
  Future<AnimeResponse> getPopularAnime({int page = 1}) {
    return getAnime(
      page: page,
      sortBy: 'popularity.desc',
      minVoteCount: 50,
      minVoteAverage: 6.5,
      originalLanguage: 'ja',
      genres: [16], // Animation genre
    );
  }

  // Convenience method for getting newest anime
  Future<AnimeResponse> getNewestAnime({int page = 1}) {
    return getAnime(
      page: page,
      sortBy: 'first_air_date.desc',
      minVoteCount: 50,
      minVoteAverage: 6.5,
      originalLanguage: 'ja',
      genres: [16], // Animation genre
    );
  }

  // Convenience method for getting highest rated anime
  Future<AnimeResponse> getTopRatedAnime({int page = 1}) {
    return getAnime(
      page: page,
      sortBy: 'vote_average.desc',
      minVoteCount: 50,
      minVoteAverage: 6.5,
      originalLanguage: 'ja',
      genres: [16], // Animation genre
    );
  }

  // Search anime by title
  Future<AnimeResponse> searchAnime(String query, {int page = 1}) {
    return getAnime(
      page: page,
      query: query,
      originalLanguage: 'ja',
      genres: [16], // Animation genre
    );
  }

  void dispose() {
    client.close();
  }
}
