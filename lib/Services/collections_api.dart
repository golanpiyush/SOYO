import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:soyo/models/moviemodel.dart';
import 'dart:async';

class CollectionsApi {
  static const String _baseUrl = 'https://fed-airdate.pstream.mov';
  static const String _apiKey = 'ad301b7cc82ffe19273e55e4d4206885';

  final Map<String, String> _collections = {
    'apple': '$_baseUrl/appletv',
    'prime': '$_baseUrl/prime',
    'netflix': '$_baseUrl/netflixmovies',
    'disney': '$_baseUrl/disney',
  };

  // Cache for collections with 3-day expiration
  static final Map<String, List<Movie>> _collectionCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const int _cacheValidityHours = 72; // 3 days

  Future<List<int>> getCollectionTmdbIds(String collectionName) async {
    try {
      final response = await http
          .get(
            Uri.parse(_collections[collectionName]!),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<int>.from(data['tmdb_ids'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error fetching $collectionName collection: $e');
      return [];
    }
  }

  // Streaming method that yields movies as they become available
  Stream<Movie> getCollectionMoviesStream(String collectionName) async* {
    // Check cache first
    if (_collectionCache.containsKey(collectionName) &&
        _cacheTimestamps.containsKey(collectionName)) {
      final cacheAge = DateTime.now().difference(
        _cacheTimestamps[collectionName]!,
      );
      if (cacheAge.inHours < _cacheValidityHours) {
        // Yield cached movies immediately
        for (final movie in _collectionCache[collectionName]!) {
          yield movie;
        }
        return;
      }
    }

    final tmdbIds = await getCollectionTmdbIds(collectionName);
    if (tmdbIds.isEmpty) return;

    final movies = <Movie>[];
    // Limit to 40 movies for performance
    final idsToFetch = tmdbIds.take(40).toList();

    // Process movies in batches for better performance
    const batchSize = 5;
    for (int i = 0; i < idsToFetch.length; i += batchSize) {
      final batch = idsToFetch.skip(i).take(batchSize);
      final futures = batch.map((id) => getMovieDetails(id));

      try {
        final results = await Future.wait(
          futures,
          eagerError: false,
        ).timeout(Duration(seconds: 15));

        for (final movie in results) {
          if (movie != null) {
            movies.add(movie);
            yield movie; // Stream each movie as it becomes available
          }
        }
      } catch (e) {
        print('Error in batch processing: $e');
        // Continue with next batch even if current batch fails
      }
    }

    // Update cache after all movies are fetched
    _collectionCache[collectionName] = movies;
    _cacheTimestamps[collectionName] = DateTime.now();
  }

  // Traditional method for backward compatibility
  Future<List<Movie>> getCollectionMovies(String collectionName) async {
    // Check cache first
    if (_collectionCache.containsKey(collectionName) &&
        _cacheTimestamps.containsKey(collectionName)) {
      final cacheAge = DateTime.now().difference(
        _cacheTimestamps[collectionName]!,
      );
      if (cacheAge.inHours < _cacheValidityHours) {
        return _collectionCache[collectionName]!;
      }
    }

    final movies = <Movie>[];
    await for (final movie in getCollectionMoviesStream(collectionName)) {
      movies.add(movie);
    }

    return movies;
  }

  Future<Movie?> getMovieDetails(int tmdbId) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.themoviedb.org/3/movie/$tmdbId?api_key=$_apiKey&append_to_response=credits',
            ),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
          )
          .timeout(Duration(seconds: 8));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return Movie.fromJson(jsonData);
      }
      return null;
    } catch (e) {
      print('Error fetching movie details for $tmdbId: $e');
      return null;
    }
  }

  // Get cache info
  Map<String, dynamic> getCacheInfo() {
    return {
      'cached_collections': _collectionCache.keys.toList(),
      'cache_timestamps': _cacheTimestamps.map(
        (key, value) => MapEntry(key, value.toIso8601String()),
      ),
      'cache_validity_hours': _cacheValidityHours,
    };
  }

  // Clear specific collection cache
  void clearCollectionCache(String collectionName) {
    _collectionCache.remove(collectionName);
    _cacheTimestamps.remove(collectionName);
  }

  // Clear all cache
  static void clearCache() {
    _collectionCache.clear();
    _cacheTimestamps.clear();
  }

  // Check if collection is cached and valid
  bool isCollectionCached(String collectionName) {
    if (!_collectionCache.containsKey(collectionName) ||
        !_cacheTimestamps.containsKey(collectionName)) {
      return false;
    }

    final cacheAge = DateTime.now().difference(
      _cacheTimestamps[collectionName]!,
    );
    return cacheAge.inHours < _cacheValidityHours;
  }

  // Get cached collection size
  int getCachedCollectionSize(String collectionName) {
    return _collectionCache[collectionName]?.length ?? 0;
  }
}
