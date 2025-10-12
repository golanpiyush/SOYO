import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:soyo/models/javData.dart';

class JAVScraper {
  static const String baseUrl = 'https://javhd.today';
  // IMPORTANT: Update this to your actual server URL
  static const String serverUrl = 'https://0nnf7qzl-5000.inc1.devtunnels.ms/';

  // Popular pages with pagination
  static String getPopularPageUrl(int page) {
    return '$baseUrl/popular/${page > 1 ? '$page/' : ''}';
  }

  // Search URL
  static String getSearchUrl(String query, int page) {
    final encodedQuery = Uri.encodeComponent(query);
    final pageParam = page > 1 ? '&page=$page' : '';
    return '$baseUrl/search/video/?s=$encodedQuery$pageParam';
  }

  Future<List<JAVVideo>> scrapePage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Failed to load page: ${response.statusCode}');
      }

      final document = parser.parse(response.body);
      final videoElements = document.querySelectorAll(
        'li.video-item, li[id^="video-"]',
      );

      final List<JAVVideo> videos = [];

      for (final element in videoElements) {
        try {
          final video = _parseVideoElement(element);
          if (video != null) {
            videos.add(video);
          }
        } catch (e) {
          print('Error parsing video element: $e');
          continue;
        }
      }

      return videos;
    } catch (e) {
      print('Error scraping page: $e');
      return [];
    }
  }

  JAVVideo? _parseVideoElement(element) {
    try {
      // Get video ID
      final id = element.attributes['id']?.replaceAll('video-', '') ?? '';

      // Find thumbnail and title elements
      final thumbnail = element.querySelector('.thumbnail');
      if (thumbnail == null) return null;

      // Get poster URL
      final img = thumbnail.querySelector('img');
      final posterUrl = img?.attributes['src'] ?? '';

      // Get title
      final titleElement = thumbnail.querySelector('.video-title');
      final title = titleElement?.text.trim() ?? '';

      // Get duration
      final durationElement = thumbnail.querySelector('.video-overlay.badge');
      final duration =
          durationElement?.text.trim().replaceAll('HD', '').trim() ?? '';

      // Get upload date
      final dateElement = thumbnail.querySelector('.badgetime .left');
      final uploadDate = dateElement?.text.trim() ?? '';

      // Get video code from overlay badge
      final codeElement = thumbnail.querySelector('.video-overlay1.badge');
      String code = codeElement?.text.trim() ?? '';

      // Clean up code (remove -engsub, -uncensored, etc.)
      code = code
          .replaceAll('-engsub', '')
          .replaceAll('-uncensored', '')
          .replaceAll('-mosaic', '')
          .trim();

      // Get page URL
      final pageUrl = thumbnail.attributes['href'] ?? '';
      final fullPageUrl = pageUrl.isNotEmpty ? '$baseUrl$pageUrl' : '';

      return JAVVideo(
        id: id,
        title: title,
        posterUrl: posterUrl,
        duration: duration,
        uploadDate: uploadDate,
        code: code,
        pageUrl: fullPageUrl,
      );
    } catch (e) {
      print('Error in _parseVideoElement: $e');
      return null;
    }
  }

  // Get total pages for pagination
  Future<int> getTotalPages(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return 1;

      final document = parser.parse(response.body);
      final pagination = document.querySelector('.pagination');
      if (pagination == null) return 1;

      final pageLinks = pagination.querySelectorAll('a');
      int maxPage = 1;

      for (final link in pageLinks) {
        final href = link.attributes['href'];
        if (href != null) {
          // Extract page number from URL
          final pageMatch = RegExp(r'/(\d+)/?$').firstMatch(href);
          if (pageMatch != null) {
            final pageNum = int.tryParse(pageMatch.group(1)!) ?? 1;
            if (pageNum > maxPage) maxPage = pageNum;
          }
        }
      }

      return maxPage;
    } catch (e) {
      print('Error getting total pages: $e');
      return 1;
    }
  }

  // Get popular videos with pagination
  Future<JAVResponse> getPopularVideos({int page = 1, int limit = 20}) async {
    try {
      final url = getPopularPageUrl(page);
      final videos = await scrapePage(url);
      final totalPages = await getTotalPages(getPopularPageUrl(1));

      return JAVResponse(
        videos: videos.take(limit).toList(),
        currentPage: page,
        totalPages: totalPages,
        hasNextPage: page < totalPages,
        hasPrevPage: page > 1,
      );
    } catch (e) {
      print('Error getting popular videos: $e');
      return JAVResponse(
        videos: [],
        currentPage: page,
        totalPages: 1,
        hasNextPage: false,
        hasPrevPage: false,
      );
    }
  }

  // Search videos with pagination
  Future<JAVResponse> searchVideos(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      if (query.isEmpty) {
        return await getPopularVideos(page: page, limit: limit);
      }

      final url = getSearchUrl(query, page);
      final videos = await scrapePage(url);
      final totalPages = await getTotalPages(getSearchUrl(query, 1));

      return JAVResponse(
        videos: videos.take(limit).toList(),
        currentPage: page,
        totalPages: totalPages,
        hasNextPage: page < totalPages,
        hasPrevPage: page > 1,
        searchQuery: query,
      );
    } catch (e) {
      print('Error searching videos: $e');
      return JAVResponse(
        videos: [],
        currentPage: page,
        totalPages: 1,
        hasNextPage: false,
        hasPrevPage: false,
        searchQuery: query,
      );
    }
  }

  // Get multiple pages for initial load
  Future<List<JAVVideo>> scrapeMultiplePages({int maxPages = 3}) async {
    final List<JAVVideo> allVideos = [];

    try {
      for (int page = 1; page <= maxPages; page++) {
        print('Scraping popular page $page...');
        final response = await getPopularVideos(page: page);
        allVideos.addAll(response.videos);

        // Add delay to be respectful to the server
        await Future.delayed(Duration(seconds: 1));
      }
    } catch (e) {
      print('Error scraping multiple pages: $e');
    }

    return allVideos;
  }

  // NEW: Get M3U8 stream for a specific JAV video
  // Get M3U8 stream for a specific JAV video
  Future<JAVStreamResponse> getVideoStream(
    String videoUrl, {
    Function(String)? onStatusUpdate,
  }) async {
    try {
      print('Requesting stream for: $videoUrl');

      // Start the stream extraction
      final startResponse = await http.post(
        Uri.parse('${serverUrl}jav/stream'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': videoUrl}),
      );

      if (startResponse.statusCode != 200) {
        throw Exception(
          'Failed to start stream extraction: ${startResponse.statusCode}',
        );
      }

      final startData = jsonDecode(startResponse.body);
      final searchId = startData['search_id'];

      if (searchId == null) {
        throw Exception('No search ID received from server');
      }

      // Poll for results
      String? m3u8Link;
      String status = 'pending';
      int maxAttempts = 60;
      int attempts = 0;

      while (attempts < maxAttempts &&
          status != 'completed' &&
          status != 'error') {
        await Future.delayed(Duration(seconds: 1));
        attempts++;

        try {
          final statusResponse = await http.get(
            Uri.parse('${serverUrl}search/status/$searchId'),
          );

          if (statusResponse.statusCode == 200) {
            final statusData = jsonDecode(statusResponse.body);
            status = statusData['status'] ?? 'unknown';

            if (onStatusUpdate != null && status != 'pending') {
              onStatusUpdate(status);
            }

            if (status == 'stream_ready' || status == 'completed') {
              final data = statusData['data'];
              if (data != null && data['m3u8_link'] != null) {
                final String m3u8Link =
                    data['m3u8_link']; // Explicitly typed as non-null

                // Create proxied URL
                final proxiedUrl =
                    '${serverUrl}proxy/m3u8?url=${Uri.encodeComponent(m3u8Link)}&referer=${Uri.encodeComponent(videoUrl)}';

                print('Stream found: $m3u8Link');
                print('Proxied URL: $proxiedUrl');

                return JAVStreamResponse(
                  success: true,
                  m3u8Url: proxiedUrl,
                  originalUrl: m3u8Link,
                  message: 'Stream found successfully',
                );
              }
            } else if (status == 'error') {
              final errorMsg = statusData['error'] ?? 'Unknown error occurred';
              print('Stream extraction error: $errorMsg');
              return JAVStreamResponse(success: false, message: errorMsg);
            }
          }
        } catch (e) {
          print('Error polling status (attempt $attempts): $e');
        }
      }

      return JAVStreamResponse(
        success: false,
        message: 'Timeout waiting for stream (${attempts}s)',
      );
    } catch (e) {
      print('Error getting video stream: $e');
      return JAVStreamResponse(success: false, message: 'Error: $e');
    }
  }
}

// Response model for paginated results
class JAVResponse {
  final List<JAVVideo> videos;
  final int currentPage;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;
  final String? searchQuery;

  JAVResponse({
    required this.videos,
    required this.currentPage,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPrevPage,
    this.searchQuery,
  });
}

// Stream response model
class JAVStreamResponse {
  final bool success;
  final String? m3u8Url;
  final String? originalUrl; // Add this
  final String message;

  JAVStreamResponse({
    required this.success,
    this.m3u8Url,
    this.originalUrl, // Add this
    required this.message,
  });

  @override
  String toString() {
    return 'JAVStreamResponse(success: $success, m3u8Url: $m3u8Url, originalUrl: $originalUrl, message: $message)';
  }
}
