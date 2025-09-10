import 'dart:convert';
import 'package:http/http.dart' as http;

class ExploreApi {
  // Cineby base URL for movie lists
  static const String cinebyBaseUrl = 'https://db.cineby.app/3';
  // TMDB base URL for detailed information
  static const String tmdbBaseUrl = 'https://api.themoviedb.org/3';
  static const String apiKey = 'ad301b7cc82ffe19273e55e4d4206885';

  // Get popular movies from Cineby
  static Future<Map<String, dynamic>> getPopularMovies({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$cinebyBaseUrl/movie/popular?page=$page&api_key=$apiKey'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load popular movies');
    }
  }

  // Get top rated movies from Cineby
  static Future<Map<String, dynamic>> getTopRatedMovies({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$cinebyBaseUrl/movie/top_rated?page=$page&api_key=$apiKey'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load top rated movies');
    }
  }

  // Get movies by genre from Cineby
  static Future<Map<String, dynamic>> getMoviesByGenre(
    int genreId, {
    int page = 1,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$cinebyBaseUrl/discover/movie?with_genres=$genreId&page=$page&api_key=$apiKey',
      ),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load movies by genre');
    }
  }

  // Get detailed movie information including cast and crew from TMDB
  static Future<Map<String, dynamic>> getMovieDetails(int movieId) async {
    final response = await http.get(
      Uri.parse(
        '$tmdbBaseUrl/movie/$movieId?api_key=$apiKey&append_to_response=credits,videos',
      ),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load movie details');
    }
  }

  // Get movie trailer from TMDB
  static Future<String?> getMovieTrailer(int movieId) async {
    try {
      final response = await http.get(
        Uri.parse('$tmdbBaseUrl/movie/$movieId/videos?api_key=$apiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final videos = data['results'] as List<dynamic>;

        // Find the first trailer (usually YouTube)
        final trailer = videos.firstWhere(
          (video) => video['type'] == 'Trailer' && video['site'] == 'YouTube',
          orElse: () => null,
        );

        return trailer != null
            ? 'https://www.youtube.com/watch?v=${trailer['key']}'
            : null;
      }
    } catch (e) {
      print('Error fetching trailer: $e');
    }
    return null;
  }

  // Search movies from Cineby
  static Future<Map<String, dynamic>> searchMovies(
    String query, {
    int page = 1,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$cinebyBaseUrl/search/movie?query=$query&page=$page&api_key=$apiKey',
      ),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to search movies');
    }
  }

  // Get movie recommendations from Cineby
  static Future<Map<String, dynamic>> getMovieRecommendations(
    int movieId, {
    int page = 1,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$cinebyBaseUrl/movie/$movieId/recommendations?page=$page&api_key=$apiKey',
      ),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load movie recommendations');
    }
  }

  // Get genres list from Cineby
  static Future<Map<String, dynamic>> getGenres() async {
    final response = await http.get(
      Uri.parse('$cinebyBaseUrl/genre/movie/list?api_key=$apiKey'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load genres');
    }
  }

  // Get person details (for cast/crew) from TMDB
  static Future<Map<String, dynamic>> getPersonDetails(int personId) async {
    final response = await http.get(
      Uri.parse(
        '$tmdbBaseUrl/person/$personId?api_key=$apiKey&append_to_response=movie_credits',
      ),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load person details');
    }
  }
}
