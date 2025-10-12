import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:soyo/models/moviecollections.dart';

class CollectionsApiService {
  static const String _baseUrl = 'https://db.cineby.app/3';
  static const String _apiKey = 'ad301b7cc82ffe19273e55e4d4206885';
  static const String _imageBaseUrl = 'https://image.tmdb.org/t/p';

  // Cache duration: 3 days
  static const Duration _cacheDuration = Duration(days: 3);

  // Popular collection IDs
  static const Map<int, String> popularCollections = {
    528: 'The Terminator Collection',
    295: 'Pirates of the Caribbean Collection',
    87359: 'Mission: Impossible Collection',
    645: 'James Bond Collection',
    2980: 'The Godfather Collection',
    10: 'Star Wars Collection',
    328: 'Jurassic Park Collection',
    263: 'The Dark Knight Collection',
    556: 'Spider-Man Collection',
    119: 'The Lord of the Rings Collection',
    9485: 'The Fast and the Furious Collection',
    86066: 'The Avengers Collection',
    313086: 'The Conjuring Collection',
    151: 'Rocky Collection',
    121938: 'The Hunger Games Collection',
    131296: 'X-Men Collection',
    1570: 'Die Hard Collection',
    1241: 'Harry Potter Collection',
  };

  // Cache helper methods
  static Future<String> _getCacheDir() async {
    final directory = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${directory.path}/collections_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir.path;
  }

  static Future<File> _getCacheFile(String key) async {
    final cacheDir = await _getCacheDir();
    return File('$cacheDir/$key.json');
  }

  static Future<bool> _isCacheValid(File cacheFile) async {
    if (!await cacheFile.exists()) return false;

    final stat = await cacheFile.stat();
    final age = DateTime.now().difference(stat.modified);
    return age < _cacheDuration;
  }

  static Future<T?> _getCachedData<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final cacheFile = await _getCacheFile(key);

      if (await _isCacheValid(cacheFile)) {
        final content = await cacheFile.readAsString();
        final jsonData = json.decode(content) as Map<String, dynamic>;
        return fromJson(jsonData);
      }
    } catch (e) {
      print('Error reading cache for $key: $e');
    }
    return null;
  }

  static Future<List<T>?> _getCachedList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final cacheFile = await _getCacheFile(key);

      if (await _isCacheValid(cacheFile)) {
        final content = await cacheFile.readAsString();
        final jsonData = json.decode(content) as List<dynamic>;
        return jsonData
            .map((item) => fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('Error reading cache list for $key: $e');
    }
    return null;
  }

  static Future<void> _cacheData(String key, dynamic data) async {
    try {
      final cacheFile = await _getCacheFile(key);
      final jsonData = json.encode(data);
      await cacheFile.writeAsString(jsonData);
    } catch (e) {
      print('Error caching data for $key: $e');
    }
  }

  static Future<List<MovieCollection>> searchCollectionsByName(
    String query,
  ) async {
    if (query.trim().isEmpty) return [];

    final cacheKey = 'search_${query.toLowerCase().replaceAll(' ', '_')}';

    // Try to get from cache first
    final cached = await _getCachedList(
      cacheKey,
      (json) => MovieCollection.fromJson(json),
    );
    if (cached != null) {
      print('Using cached search results for: $query');
      return cached;
    }

    try {
      final url = Uri.parse(
        '$_baseUrl/search/collection?api_key=$_apiKey&query=${Uri.encodeComponent(query)}',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final List<dynamic> results = jsonData['results'] ?? [];

        List<MovieCollection> collections = [];

        // Fetch detailed information for each collection found
        for (var result in results) {
          final collectionId = result['id'];
          final detailedCollection = await getCollection(collectionId);
          if (detailedCollection != null) {
            collections.add(detailedCollection);
          }
        }

        // Cache the results
        await _cacheData(cacheKey, collections.map((c) => c.toJson()).toList());
        print('Cached search results for: $query');

        return collections;
      } else {
        print('Failed to search collections: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error searching collections: $e');
      return [];
    }
  }

  // Get a specific collection by ID
  static Future<MovieCollection?> getCollection(int collectionId) async {
    final cacheKey = 'collection_$collectionId';

    // Try to get from cache first
    final cached = await _getCachedData(
      cacheKey,
      (json) => MovieCollection.fromJson(json),
    );
    if (cached != null) {
      print('Using cached collection: $collectionId');
      return cached;
    }

    try {
      final url = Uri.parse(
        '$_baseUrl/collection/$collectionId?api_key=$_apiKey',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final collection = MovieCollection.fromJson(jsonData);

        // Cache the result
        await _cacheData(cacheKey, jsonData);
        print('Cached collection: $collectionId');

        return collection;
      } else {
        print('Failed to load collection: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching collection: $e');
      return null;
    }
  }

  // Get multiple collections by IDs
  static Future<List<MovieCollection>> getCollections(
    List<int> collectionIds,
  ) async {
    final List<MovieCollection> collections = [];

    for (final id in collectionIds) {
      final collection = await getCollection(id);
      if (collection != null) {
        collections.add(collection);
      }
    }

    return collections;
  }

  // Get all popular collections
  static Future<List<MovieCollection>> getPopularCollections() async {
    const cacheKey = 'popular_collections';

    // Try to get from cache first
    final cached = await _getCachedList(
      cacheKey,
      (json) => MovieCollection.fromJson(json),
    );
    if (cached != null) {
      print('Using cached popular collections');
      return cached;
    }

    final collections = await getCollections(popularCollections.keys.toList());

    // Cache the results
    if (collections.isNotEmpty) {
      await _cacheData(cacheKey, collections.map((c) => c.toJson()).toList());
      print('Cached popular collections');
    }

    return collections;
  }

  // Get collections by genre (based on movies in collection)
  static Future<List<MovieCollection>> getCollectionsByGenre(
    List<int> genreIds,
  ) async {
    final cacheKey = 'genre_${genreIds.join('_')}';

    // Try to get from cache first
    final cached = await _getCachedList(
      cacheKey,
      (json) => MovieCollection.fromJson(json),
    );
    if (cached != null) {
      print('Using cached genre collections: ${genreIds.join(', ')}');
      return cached;
    }

    final allCollections = await getPopularCollections();

    final filteredCollections = allCollections.where((collection) {
      return collection.parts.any(
        (movie) => movie.genreIds.any((genreId) => genreIds.contains(genreId)),
      );
    }).toList();

    // Cache the results
    if (filteredCollections.isNotEmpty) {
      await _cacheData(
        cacheKey,
        filteredCollections.map((c) => c.toJson()).toList(),
      );
      print('Cached genre collections: ${genreIds.join(', ')}');
    }

    return filteredCollections;
  }

  // Search collections by name
  static Future<List<MovieCollection>> searchCollections(String query) async {
    final cacheKey = 'local_search_${query.toLowerCase().replaceAll(' ', '_')}';

    // Try to get from cache first
    final cached = await _getCachedList(
      cacheKey,
      (json) => MovieCollection.fromJson(json),
    );
    if (cached != null) {
      print('Using cached local search: $query');
      return cached;
    }

    final allCollections = await getPopularCollections();

    final results = allCollections
        .where(
          (collection) =>
              collection.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();

    // Cache the results
    if (results.isNotEmpty) {
      await _cacheData(cacheKey, results.map((c) => c.toJson()).toList());
      print('Cached local search: $query');
    }

    return results;
  }

  // Get trending collections (sorted by average popularity of movies)
  static Future<List<MovieCollection>> getTrendingCollections() async {
    const cacheKey = 'trending_collections';

    // Try to get from cache first
    final cached = await _getCachedList(
      cacheKey,
      (json) => MovieCollection.fromJson(json),
    );
    if (cached != null) {
      print('Using cached trending collections');
      return cached;
    }

    final collections = await getPopularCollections();

    collections.sort((a, b) {
      final aAvgPopularity = a.parts.isEmpty
          ? 0.0
          : a.parts.fold(0.0, (sum, movie) => sum + movie.popularity) /
                a.parts.length;
      final bAvgPopularity = b.parts.isEmpty
          ? 0.0
          : b.parts.fold(0.0, (sum, movie) => sum + movie.popularity) /
                b.parts.length;

      return bAvgPopularity.compareTo(aAvgPopularity);
    });

    // Cache the results
    if (collections.isNotEmpty) {
      await _cacheData(cacheKey, collections.map((c) => c.toJson()).toList());
      print('Cached trending collections');
    }

    return collections;
  }

  // Get top rated collections
  static Future<List<MovieCollection>> getTopRatedCollections() async {
    const cacheKey = 'top_rated_collections';

    // Try to get from cache first
    final cached = await _getCachedList(
      cacheKey,
      (json) => MovieCollection.fromJson(json),
    );
    if (cached != null) {
      print('Using cached top rated collections');
      return cached;
    }

    final collections = await getPopularCollections();

    collections.sort((a, b) => b.averageRating.compareTo(a.averageRating));

    // Cache the results
    if (collections.isNotEmpty) {
      await _cacheData(cacheKey, collections.map((c) => c.toJson()).toList());
      print('Cached top rated collections');
    }

    return collections;
  }

  // Get recently updated collections (collections with recent movie releases)
  static Future<List<MovieCollection>> getRecentlyUpdatedCollections() async {
    const cacheKey = 'recently_updated_collections';

    // Try to get from cache first
    final cached = await _getCachedList(
      cacheKey,
      (json) => MovieCollection.fromJson(json),
    );
    if (cached != null) {
      print('Using cached recently updated collections');
      return cached;
    }

    final collections = await getPopularCollections();

    final results = collections
        .where(
          (collection) =>
              collection.parts.any((movie) => movie.isRecentRelease),
        )
        .toList();

    // Cache the results
    if (results.isNotEmpty) {
      await _cacheData(cacheKey, results.map((c) => c.toJson()).toList());
      print('Cached recently updated collections');
    }

    return results;
  }

  // Get collection details with additional movie information
  static Future<MovieCollection?> getCollectionWithDetails(
    int collectionId,
  ) async {
    final collection = await getCollection(collectionId);
    if (collection == null) return null;

    // You can extend this to fetch additional details for each movie
    // such as runtime, detailed cast, etc. from individual movie endpoints

    return collection;
  }

  // Utility method to get image URL
  static String getImageUrl(String imagePath, {String size = 'w500'}) {
    if (imagePath.isEmpty) {
      return 'https://via.placeholder.com/500x750/333/fff?text=No+Image';
    }
    return '$_imageBaseUrl/$size$imagePath';
  }

  // Get collection statistics
  static Map<String, dynamic> getCollectionStats(MovieCollection collection) {
    final movies = collection.parts;
    if (movies.isEmpty) {
      return {
        'totalMovies': 0,
        'totalRuntime': 0,
        'averageRating': 0.0,
        'highestRated': null,
        'lowestRated': null,
        'firstRelease': null,
        'latestRelease': null,
      };
    }

    final sortedByRating = List<CollectionMovie>.from(movies)
      ..sort((a, b) => b.voteAverage.compareTo(a.voteAverage));

    final sortedByDate = List<CollectionMovie>.from(movies)
      ..sort((a, b) {
        if (a.releaseDate.isEmpty || b.releaseDate.isEmpty) return 0;
        return DateTime.parse(
          a.releaseDate,
        ).compareTo(DateTime.parse(b.releaseDate));
      });

    return {
      'totalMovies': movies.length,
      'totalRuntime': collection.totalRuntime,
      'averageRating': collection.averageRating,
      'highestRated': sortedByRating.first,
      'lowestRated': sortedByRating.last,
      'firstRelease': sortedByDate.first,
      'latestRelease': sortedByDate.last,
    };
  }

  // Cache management methods
  static Future<void> clearCache() async {
    try {
      final cacheDir = await _getCacheDir();
      final directory = Directory(cacheDir);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
        print('Cache cleared successfully');
      }
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  static Future<void> clearExpiredCache() async {
    try {
      final cacheDir = await _getCacheDir();
      final directory = Directory(cacheDir);

      if (await directory.exists()) {
        final files = directory.listSync();
        for (final file in files) {
          if (file is File) {
            final stat = await file.stat();
            final age = DateTime.now().difference(stat.modified);
            if (age >= _cacheDuration) {
              await file.delete();
              print('Deleted expired cache file: ${file.path}');
            }
          }
        }
      }
    } catch (e) {
      print('Error clearing expired cache: $e');
    }
  }

  static Future<Map<String, dynamic>> getCacheInfo() async {
    try {
      final cacheDir = await _getCacheDir();
      final directory = Directory(cacheDir);

      if (!await directory.exists()) {
        return {
          'totalFiles': 0,
          'totalSize': 0,
          'oldestFile': null,
          'newestFile': null,
        };
      }

      final files = directory.listSync().whereType<File>().toList();
      int totalSize = 0;
      DateTime? oldest, newest;

      for (final file in files) {
        final stat = await file.stat();
        totalSize += stat.size;

        if (oldest == null || stat.modified.isBefore(oldest)) {
          oldest = stat.modified;
        }

        if (newest == null || stat.modified.isAfter(newest)) {
          newest = stat.modified;
        }
      }

      return {
        'totalFiles': files.length,
        'totalSize': totalSize,
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
        'oldestFile': oldest?.toIso8601String(),
        'newestFile': newest?.toIso8601String(),
      };
    } catch (e) {
      print('Error getting cache info: $e');
      return {'error': e.toString()};
    }
  }
}
