import 'dart:convert';
import 'package:http/http.dart' as http;

class ExploreTvApi {
  static const String baseUrl = 'https://cinemaos.me/api/tmdb';

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
}
