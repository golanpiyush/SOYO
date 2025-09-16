// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:soyo/models/moviemodel.dart';

// class CollectionsApi {
//   static const String baseUrl =
//       'https://themoviedb.hexa.watch/api/tmdb/collection';
//   static const String streamDbUrl = 'https://streamdb.online/api/content';

//   // Collection IDs and their names for TMDB
//   static const Map<int, String> collectionIds = {
//     528: 'The Terminator Collection',
//     295: 'Pirates of the Caribbean Collection',
//     87359: 'Mission: Impossible Collection',
//     645: 'James Bond Collection',
//     2980: 'The Godfather Collection',
//     10: 'Star Wars Collection',
//     328: 'Jurassic Park Collection',
//     263: 'The Dark Knight Collection',
//     556: 'Spider-Man Collection',
//     119: 'The Lord of the Rings Collection',
//     9485: 'The Fast and the Furious Collection',
//     86066: 'The Avengers Collection',
//     313086: 'The Conjuring Collection',
//     151: 'Rocky Collection',
//     121938: 'The Hunger Games Collection',
//     131296: 'X-Men Collection',
//     1570: 'Die Hard Collection',
//     1241: 'Harry Potter Collection',
//   };

//   // StreamDB Categories
//   static const Map<String, String> streamDbCategories = {
//     'hindi-movies': 'Hindi Movies',
//     'english-movies': 'English Movies',
//     'punjabi-movies': 'Punjabi Movies',
//     'tamil-movies': 'Tamil Movies',
//     'telugu-movies': 'Telugu Movies',
//     'malayalam-movies': 'Malayalam Movies',
//     'bengali-movies': 'Bengali Movies',
//     'gujarati-movies': 'Gujarati Movies',
//     'marathi-movies': 'Marathi Movies',
//   };

//   // TMDB Collection Methods
//   Future<Map<String, dynamic>?> getCollection(int collectionId) async {
//     try {
//       final response = await http.get(
//         Uri.parse('$baseUrl/$collectionId'),
//         headers: {
//           'Accept': 'application/json',
//           'Content-Type': 'application/json',
//         },
//       );

//       if (response.statusCode == 200) {
//         return json.decode(response.body);
//       } else {
//         print(
//           'Failed to fetch collection $collectionId: ${response.statusCode}',
//         );
//         return null;
//       }
//     } catch (e) {
//       print('Error fetching collection $collectionId: $e');
//       return null;
//     }
//   }

//   Future<List<Movie>> getCollectionMovies(int collectionId) async {
//     try {
//       final collectionData = await getCollection(collectionId);
//       if (collectionData == null) return [];

//       final parts = collectionData['parts'] as List<dynamic>? ?? [];

//       return parts.map((part) {
//         return Movie(
//           id: part['id'] ?? 0,
//           title: part['title'] ?? part['original_title'] ?? 'Unknown Title',
//           overview: part['overview'] ?? '',
//           releaseDate: part['release_date'] ?? '',
//           posterPath: part['poster_path'] ?? '',
//           backdropPath: part['backdrop_path'] ?? '',
//           voteAverage: (part['vote_average'] ?? 0.0).toDouble(),
//           voteCount: part['vote_count'] ?? 0,
//           popularity: (part['popularity'] ?? 0.0).toDouble(),
//           genreIds: List<int>.from(part['genre_ids'] ?? []),
//         );
//       }).toList();
//     } catch (e) {
//       print('Error processing collection $collectionId movies: $e');
//       return [];
//     }
//   }

//   Future<Map<String, List<Movie>>> getAllCollections() async {
//     Map<String, List<Movie>> collections = {};

//     // Process collections in batches to avoid overwhelming the API
//     final collectionEntries = collectionIds.entries.toList();

//     for (int i = 0; i < collectionEntries.length; i += 3) {
//       final batch = collectionEntries.skip(i).take(3);

//       final futures = batch.map((entry) async {
//         final movies = await getCollectionMovies(entry.key);
//         if (movies.isNotEmpty) {
//           collections[entry.value] = movies;
//         }
//       });

//       await Future.wait(futures);

//       // Small delay between batches to be respectful to the API
//       if (i + 3 < collectionEntries.length) {
//         await Future.delayed(Duration(milliseconds: 500));
//       }
//     }

//     return collections;
//   }

//   Future<Map<String, dynamic>?> getCollectionDetails(int collectionId) async {
//     return await getCollection(collectionId);
//   }

//   // Get featured collections (subset of all collections)
//   Future<Map<String, List<Movie>>> getFeaturedCollections() async {
//     final featuredIds = [
//       86066,
//       313086,
//       1241,
//       87359,
//       10,
//       328,
//     ]; // Avengers, Conjuring, Harry Potter, Mission Impossible, Star Wars, Jurassic Park
//     Map<String, List<Movie>> featuredCollections = {};

//     for (int collectionId in featuredIds) {
//       final collectionName = collectionIds[collectionId];
//       if (collectionName != null) {
//         final movies = await getCollectionMovies(collectionId);
//         if (movies.isNotEmpty) {
//           featuredCollections[collectionName] = movies;
//         }
//       }
//     }

//     return featuredCollections;
//   }

//   // Search collections by name
//   Future<Map<String, List<Movie>>> searchCollections(String query) async {
//     final allCollections = await getAllCollections();
//     final filteredCollections = <String, List<Movie>>{};

//     for (final entry in allCollections.entries) {
//       if (entry.key.toLowerCase().contains(query.toLowerCase())) {
//         filteredCollections[entry.key] = entry.value;
//       }
//     }

//     return filteredCollections;
//   }

//   // StreamDB Methods
//   Future<Map<String, dynamic>?> getStreamDbContent({
//     String? category,
//     bool published = true,
//     int limit = 10,
//     int page = 1,
//     String sortBy = 'created_at',
//     String sortOrder = 'desc',
//     String? search,
//   }) async {
//     try {
//       final queryParams = <String, String>{
//         'published': published.toString(),
//         'limit': limit.toString(),
//         'page': page.toString(),
//         'sort_by': sortBy,
//         'sort_order': sortOrder,
//       };

//       if (category != null) {
//         queryParams['category'] = category;
//       }

//       if (search != null && search.isNotEmpty) {
//         queryParams['search'] = search;
//       }

//       final uri = Uri.parse(streamDbUrl).replace(queryParameters: queryParams);

//       final response = await http.get(
//         uri,
//         headers: {
//           'Accept': 'application/json',
//           'Content-Type': 'application/json',
//         },
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         if (data['success'] == true) {
//           return data;
//         } else {
//           print('StreamDB API returned success: false');
//           return null;
//         }
//       } else {
//         print('Failed to fetch StreamDB content: ${response.statusCode}');
//         return null;
//       }
//     } catch (e) {
//       print('Error fetching StreamDB content: $e');
//       return null;
//     }
//   }

//   Future<List<Movie>> getStreamDbMovies({
//     String? category,
//     bool published = true,
//     int limit = 10,
//     int page = 1,
//     String sortBy = 'created_at',
//     String sortOrder = 'desc',
//     String? search,
//   }) async {
//     try {
//       final response = await getStreamDbContent(
//         category: category,
//         published: published,
//         limit: limit,
//         page: page,
//         sortBy: sortBy,
//         sortOrder: sortOrder,
//         search: search,
//       );

//       if (response == null) return [];

//       final data = response['data'] as List<dynamic>? ?? [];

//       return data.map((item) {
//         return Movie(
//           id: int.tryParse(item['tmdbId']?.toString() ?? '0') ?? 0,
//           title: item['title'] ?? 'Unknown Title',
//           overview: item['description'] ?? '',
//           releaseDate: item['year']?.toString() ?? '',
//           posterPath: _extractImagePath(
//             item['posterUrl'] ?? item['image'] ?? '',
//           ),
//           backdropPath: _extractImagePath(
//             item['coverImage'] ?? item['cover_image'] ?? '',
//           ),
//           voteAverage:
//               double.tryParse(item['imdbRating']?.toString() ?? '0') ?? 0.0,
//           voteCount: 0, // Not available in StreamDB
//           popularity: 0.0, // Not available in StreamDB
//           genreIds: _parseGenres(item['genres']),
//           // Additional StreamDB specific fields could be stored in a custom field
//           // or you could extend the Movie model to include them
//         );
//       }).toList();
//     } catch (e) {
//       print('Error processing StreamDB movies: $e');
//       return [];
//     }
//   }

//   Future<Map<String, List<Movie>>> getStreamDbCollections() async {
//     Map<String, List<Movie>> collections = {};

//     for (final entry in streamDbCategories.entries) {
//       final movies = await getStreamDbMovies(category: entry.value, limit: 20);

//       if (movies.isNotEmpty) {
//         collections[entry.value] = movies;
//       }

//       // Small delay between requests
//       await Future.delayed(Duration(milliseconds: 300));
//     }

//     return collections;
//   }

//   Future<List<Movie>> getLatestStreamDbMovies({int limit = 10}) async {
//     return await getStreamDbMovies(
//       limit: limit,
//       sortBy: 'created_at',
//       sortOrder: 'desc',
//     );
//   }

//   Future<List<Movie>> getPopularStreamDbMovies({int limit = 10}) async {
//     return await getStreamDbMovies(
//       limit: limit,
//       sortBy: 'imdb_rating',
//       sortOrder: 'desc',
//     );
//   }

//   Future<List<Movie>> searchStreamDbMovies(
//     String query, {
//     int limit = 20,
//   }) async {
//     return await getStreamDbMovies(search: query, limit: limit);
//   }

//   // Combined Methods (TMDB + StreamDB)
//   Future<Map<String, List<Movie>>> getCombinedCollections() async {
//     final tmdbCollections = await getAllCollections();
//     final streamDbCollections = await getStreamDbCollections();

//     // Merge both collections
//     final combined = <String, List<Movie>>{};
//     combined.addAll(tmdbCollections);
//     combined.addAll(streamDbCollections);

//     return combined;
//   }

//   Future<List<Movie>> getCombinedLatestMovies({int limit = 20}) async {
//     final streamDbMovies = await getLatestStreamDbMovies(limit: limit ~/ 2);
//     final tmdbMovies = await getCollectionMovies(86066); // Avengers as example

//     final combined = <Movie>[];
//     combined.addAll(streamDbMovies);
//     combined.addAll(tmdbMovies.take(limit ~/ 2));

//     return combined.take(limit).toList();
//   }

//   // Helper methods
//   String _extractImagePath(String fullUrl) {
//     if (fullUrl.isEmpty) return '';

//     // Extract the path from full TMDB URL
//     if (fullUrl.startsWith('https://image.tmdb.org/t/p/')) {
//       final parts = fullUrl.split('/');
//       if (parts.length >= 2) {
//         return '/${parts.last}';
//       }
//     }

//     return fullUrl;
//   }

//   List<int> _parseGenres(dynamic genres) {
//     if (genres == null) return [];

//     if (genres is List) {
//       // If it's already a list of genre names, we'd need a genre mapping
//       // For now, return empty list since we don't have genre ID mapping for StreamDB
//       return [];
//     }

//     return [];
//   }

//   // Pagination support for StreamDB
//   Future<Map<String, dynamic>> getStreamDbContentWithPagination({
//     String? category,
//     bool published = true,
//     int limit = 10,
//     int page = 1,
//     String sortBy = 'created_at',
//     String sortOrder = 'desc',
//     String? search,
//   }) async {
//     final response = await getStreamDbContent(
//       category: category,
//       published: published,
//       limit: limit,
//       page: page,
//       sortBy: sortBy,
//       sortOrder: sortOrder,
//       search: search,
//     );

//     if (response == null) {
//       return {
//         'movies': <Movie>[],
//         'pagination': {
//           'page': page,
//           'limit': limit,
//           'total': 0,
//           'totalPages': 0,
//           'hasNext': false,
//           'hasPrev': false,
//         },
//       };
//     }

//     final movies = await getStreamDbMovies(
//       category: category,
//       published: published,
//       limit: limit,
//       page: page,
//       sortBy: sortBy,
//       sortOrder: sortOrder,
//       search: search,
//     );

//     return {'movies': movies, 'pagination': response['pagination'] ?? {}};
//   }
// }
