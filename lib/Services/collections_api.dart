import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:soyo/models/moviemodel.dart';

class CollectionsApi {
  static const String baseUrl =
      'https://themoviedb.hexa.watch/api/tmdb/collection';

  // Collection IDs and their names
  static const Map<int, String> collectionIds = {
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

  Future<Map<String, dynamic>?> getCollection(int collectionId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$collectionId'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print(
          'Failed to fetch collection $collectionId: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      print('Error fetching collection $collectionId: $e');
      return null;
    }
  }

  Future<List<Movie>> getCollectionMovies(int collectionId) async {
    try {
      final collectionData = await getCollection(collectionId);
      if (collectionData == null) return [];

      final parts = collectionData['parts'] as List<dynamic>? ?? [];

      return parts.map((part) {
        return Movie(
          id: part['id'] ?? 0,
          title: part['title'] ?? part['original_title'] ?? 'Unknown Title',
          overview: part['overview'] ?? '',
          releaseDate: part['release_date'] ?? '',
          posterPath: part['poster_path'] ?? '',
          backdropPath: part['backdrop_path'] ?? '',
          voteAverage: (part['vote_average'] ?? 0.0).toDouble(),
          voteCount: part['vote_count'] ?? 0,
          popularity: (part['popularity'] ?? 0.0).toDouble(),
          genreIds: List<int>.from(part['genre_ids'] ?? []),
        );
      }).toList();
    } catch (e) {
      print('Error processing collection $collectionId movies: $e');
      return [];
    }
  }

  Future<Map<String, List<Movie>>> getAllCollections() async {
    Map<String, List<Movie>> collections = {};

    // Process collections in batches to avoid overwhelming the API
    final collectionEntries = collectionIds.entries.toList();

    for (int i = 0; i < collectionEntries.length; i += 3) {
      final batch = collectionEntries.skip(i).take(3);

      final futures = batch.map((entry) async {
        final movies = await getCollectionMovies(entry.key);
        if (movies.isNotEmpty) {
          collections[entry.value] = movies;
        }
      });

      await Future.wait(futures);

      // Small delay between batches to be respectful to the API
      if (i + 3 < collectionEntries.length) {
        await Future.delayed(Duration(milliseconds: 500));
      }
    }

    return collections;
  }

  Future<Map<String, dynamic>?> getCollectionDetails(int collectionId) async {
    return await getCollection(collectionId);
  }

  // Get featured collections (subset of all collections)
  Future<Map<String, List<Movie>>> getFeaturedCollections() async {
    final featuredIds = [
      86066,
      313086,
      1241,
      87359,
      10,
      328,
    ]; // Avengers, Conjuring, Harry Potter, Mission Impossible, Star Wars, Jurassic Park
    Map<String, List<Movie>> featuredCollections = {};

    for (int collectionId in featuredIds) {
      final collectionName = collectionIds[collectionId];
      if (collectionName != null) {
        final movies = await getCollectionMovies(collectionId);
        if (movies.isNotEmpty) {
          featuredCollections[collectionName] = movies;
        }
      }
    }

    return featuredCollections;
  }

  // Search collections by name
  Future<Map<String, List<Movie>>> searchCollections(String query) async {
    final allCollections = await getAllCollections();
    final filteredCollections = <String, List<Movie>>{};

    for (final entry in allCollections.entries) {
      if (entry.key.toLowerCase().contains(query.toLowerCase())) {
        filteredCollections[entry.key] = entry.value;
      }
    }

    return filteredCollections;
  }
}
