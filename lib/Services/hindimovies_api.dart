import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:soyo/models/moviemodel.dart';

class HindiMoviesApi {
  static const String streamDbUrl = 'https://streamdb.online/api/content';
  static const String hindiCategory = 'Hindi Movies';

  Future<Map<String, dynamic>?> getHindiMoviesContent({
    bool published = true,
    int limit = 1000,
    int page = 1,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{
        'category': hindiCategory,
        'published': published.toString(),
        'limit': limit.toString(),
        'page': page.toString(),
        'sort_by': sortBy,
        'sort_order': sortOrder,
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final uri = Uri.parse(streamDbUrl).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          print('StreamDB API returned success: false');
          return null;
        }
      } else {
        print('Failed to fetch Hindi movies: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching Hindi movies: $e');
      return null;
    }
  }

  Future<List<Movie>> getHindiMovies({
    bool published = true,
    int limit = 1000,
    int page = 1,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
    String? search,
  }) async {
    try {
      final response = await getHindiMoviesContent(
        published: published,
        limit: limit,
        page: page,
        sortBy: sortBy,
        sortOrder: sortOrder,
        search: search,
      );

      if (response == null) return [];

      final data = response['data'] as List<dynamic>? ?? [];

      return data.map((item) {
        return Movie(
          id: int.tryParse(item['tmdbId']?.toString() ?? '0') ?? 0,
          title: item['title'] ?? 'Unknown Title',
          overview: item['description'] ?? '',
          releaseDate: item['year']?.toString() ?? '',
          posterPath: _extractImagePath(
            item['posterUrl'] ?? item['image'] ?? '',
          ),
          backdropPath: _extractImagePath(
            item['coverImage'] ?? item['cover_image'] ?? '',
          ),
          voteAverage:
              double.tryParse(item['imdbRating']?.toString() ?? '0') ?? 0.0,
          voteCount: 0,
          popularity: 0.0,
          genreIds: [],
        );
      }).toList();
    } catch (e) {
      print('Error processing Hindi movies: $e');
      return [];
    }
  }

  Future<List<Movie>> getLatestHindiMovies({int limit = 50}) async {
    return await getHindiMovies(
      limit: limit,
      sortBy: 'created_at',
      sortOrder: 'desc',
    );
  }

  Future<List<Movie>> getPopularHindiMovies({int limit = 50}) async {
    return await getHindiMovies(
      limit: limit,
      sortBy: 'imdb_rating',
      sortOrder: 'desc',
    );
  }

  Future<List<Movie>> searchHindiMovies(String query, {int limit = 100}) async {
    return await getHindiMovies(search: query, limit: limit);
  }

  Future<Map<String, dynamic>> getHindiMoviesWithPagination({
    bool published = true,
    int limit = 50,
    int page = 1,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
    String? search,
  }) async {
    final response = await getHindiMoviesContent(
      published: published,
      limit: limit,
      page: page,
      sortBy: sortBy,
      sortOrder: sortOrder,
      search: search,
    );

    if (response == null) {
      return {
        'movies': <Movie>[],
        'pagination': {
          'page': page,
          'limit': limit,
          'total': 0,
          'totalPages': 0,
          'hasNext': false,
          'hasPrev': false,
        },
      };
    }

    final movies = await getHindiMovies(
      published: published,
      limit: limit,
      page: page,
      sortBy: sortBy,
      sortOrder: sortOrder,
      search: search,
    );

    return {'movies': movies, 'pagination': response['pagination'] ?? {}};
  }

  // Helper method
  String _extractImagePath(String fullUrl) {
    if (fullUrl.isEmpty) return '';

    // Extract the path from full TMDB URL
    if (fullUrl.startsWith('https://image.tmdb.org/t/p/')) {
      final parts = fullUrl.split('/');
      if (parts.length >= 2) {
        return '/${parts.last}';
      }
    }

    return fullUrl;
  }
}
