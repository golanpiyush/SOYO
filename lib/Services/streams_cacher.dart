import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StreamCacheService {
  static const String _cachePrefix = 'stream_cache_';
  // 5 hrs movies
  static const int _cacheExpiryMinutes = 450;

  // TV Show specific caching (2 hours)
  static const int _tvShowCacheExpiryMinutes = 120;
  static const String _tvShowCachePrefix = 'tv_show_cache_';

  // Cache key structure: stream_cache_{movieName}
  static String _getCacheKey(String movieName) {
    return '$_cachePrefix${movieName.toLowerCase().replaceAll(' ', '_')}';
  }

  static String _getTvShowCacheKey(int showId, int season, int episode) {
    return '${_tvShowCachePrefix}${showId}_s${season}_e${episode}';
  }

  // Cache a stream result
  static Future<void> cacheStreamResult(
    String movieName,
    Map<String, dynamic> streamResult,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getCacheKey(movieName);

      final cacheData = {
        'streamResult': streamResult,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
        'movieName': movieName,
      };

      await prefs.setString(cacheKey, jsonEncode(cacheData));

      print('✅ Cached stream for: $movieName');
    } catch (e) {
      print('❌ Error caching stream for $movieName: $e');
    }
  }

  // Cache a TV show stream result
  static Future<void> cacheTvShowStreamResult(
    int showId,
    int season,
    int episode,
    Map<String, dynamic> streamResult,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getTvShowCacheKey(showId, season, episode);

      final cacheData = {
        'streamResult': streamResult,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
        'showId': showId,
        'season': season,
        'episode': episode,
      };

      await prefs.setString(cacheKey, jsonEncode(cacheData));

      print('✅ Cached TV show stream for: Show $showId S${season}E${episode}');
    } catch (e) {
      print(
        '❌ Error caching TV show stream for Show $showId S${season}E${episode}: $e',
      );
    }
  }

  // Get cached TV show stream result if it exists and is not expired
  static Future<Map<String, dynamic>?> getCachedTvShowStreamResult(
    int showId,
    int season,
    int episode,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getTvShowCacheKey(showId, season, episode);

      final cachedString = prefs.getString(cacheKey);
      if (cachedString == null) {
        print('📭 No cache found for: Show $showId S${season}E${episode}');
        return null;
      }

      final cacheData = jsonDecode(cachedString);
      final cachedAt = DateTime.fromMillisecondsSinceEpoch(
        cacheData['cachedAt'],
      );
      final now = DateTime.now();

      // Check if cache is expired (older than 120 minutes) 2 hrs
      if (now.difference(cachedAt).inMinutes >= _tvShowCacheExpiryMinutes) {
        print('⏰ Cache expired for: Show $showId S${season}E${episode}');
        await clearCachedTvShowStreamResult(showId, season, episode);
        return null;
      }

      print(
        '✅ Using cached TV show stream for: Show $showId S${season}E${episode}',
      );
      return Map<String, dynamic>.from(cacheData['streamResult']);
    } catch (e) {
      print(
        '❌ Error reading TV show cache for Show $showId S${season}E${episode}: $e',
      );
      return null;
    }
  }

  // Clear specific cached TV show stream result
  static Future<void> clearCachedTvShowStreamResult(
    int showId,
    int season,
    int episode,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getTvShowCacheKey(showId, season, episode);
      await prefs.remove(cacheKey);
      print(
        '🗑️ Cleared TV show cache for: Show $showId S${season}E${episode}',
      );
    } catch (e) {
      print(
        '❌ Error clearing TV show cache for Show $showId S${season}E${episode}: $e',
      );
    }
  }

  // Clear all TV show cache for a specific show
  static Future<void> clearAllTvShowCache(int showId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where(
        (key) =>
            key.startsWith(_tvShowCachePrefix) && key.contains('${showId}_'),
      );

      for (final key in keys) {
        await prefs.remove(key);
      }

      print('🗑️ Cleared all TV show cache for Show $showId');
    } catch (e) {
      print('❌ Error clearing all TV show cache for Show $showId: $e');
    }
  }

  // Get cached stream result if it exists and is not expired
  static Future<Map<String, dynamic>?> getCachedStreamResult(
    String movieName,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getCacheKey(movieName);

      final cachedString = prefs.getString(cacheKey);
      if (cachedString == null) {
        print('📭 No cache found for: $movieName');
        return null;
      }

      final cacheData = jsonDecode(cachedString);
      final cachedAt = DateTime.fromMillisecondsSinceEpoch(
        cacheData['cachedAt'],
      );
      final now = DateTime.now();

      // Check if cache is expired (older than 450 minutes) 5 hrs
      if (now.difference(cachedAt).inMinutes >= _cacheExpiryMinutes) {
        print('⏰ Cache expired for: $movieName');
        await clearCachedStreamResult(movieName);
        return null;
      }

      print('✅ Using cached stream for: $movieName');
      return Map<String, dynamic>.from(cacheData['streamResult']);
    } catch (e) {
      print('❌ Error reading cache for $movieName: $e');
      return null;
    }
  }

  // Clear specific cached stream result
  static Future<void> clearCachedStreamResult(String movieName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getCacheKey(movieName);
      await prefs.remove(cacheKey);
      print('🗑️ Cleared cache for: $movieName');
    } catch (e) {
      print('❌ Error clearing cache for $movieName: $e');
    }
  }

  // Clear all expired cache entries
  static Future<void> clearExpiredCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_cachePrefix));

      for (final key in keys) {
        final cachedString = prefs.getString(key);
        if (cachedString != null) {
          final cacheData = jsonDecode(cachedString);
          final cachedAt = DateTime.fromMillisecondsSinceEpoch(
            cacheData['cachedAt'],
          );
          final now = DateTime.now();

          if (now.difference(cachedAt).inMinutes >= _cacheExpiryMinutes) {
            await prefs.remove(key);
            print('🗑️ Cleared expired cache: ${cacheData['movieName']}');
          }
        }
      }
    } catch (e) {
      print('❌ Error clearing expired cache: $e');
    }
  }

  // Clear all stream cache
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_cachePrefix));

      for (final key in keys) {
        await prefs.remove(key);
      }

      print('🗑️ Cleared all stream cache');
    } catch (e) {
      print('❌ Error clearing all cache: $e');
    }
  }

  // Get cache info for debugging
  static Future<Map<String, dynamic>> getCacheInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_cachePrefix));

      final cacheInfo = <String, dynamic>{};
      final now = DateTime.now();

      for (final key in keys) {
        final cachedString = prefs.getString(key);
        if (cachedString != null) {
          final cacheData = jsonDecode(cachedString);
          final cachedAt = DateTime.fromMillisecondsSinceEpoch(
            cacheData['cachedAt'],
          );
          final minutesAgo = now.difference(cachedAt).inMinutes;
          final isExpired = minutesAgo >= _cacheExpiryMinutes;

          cacheInfo[cacheData['movieName']] = {
            'cachedAt': cachedAt.toIso8601String(),
            'minutesAgo': minutesAgo,
            'isExpired': isExpired,
            'expiresIn': isExpired ? 0 : _cacheExpiryMinutes - minutesAgo,
          };
        }
      }

      return cacheInfo;
    } catch (e) {
      print('❌ Error getting cache info: $e');
      return {};
    }
  }
}
