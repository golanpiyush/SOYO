import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:brotli/brotli.dart';
import 'dart:typed_data';

class XHamsterVideo {
  final String title;
  final String thumbnail;
  final String url;
  final String duration;
  final String views;
  final String uploader;
  final String uploaderAvatar;
  final String videoId;
  final String? description;
  final double? rating;
  final String? uploadDate;
  final String? quality;

  XHamsterVideo({
    required this.title,
    required this.thumbnail,
    required this.url,
    required this.duration,
    required this.views,
    required this.uploader,
    required this.uploaderAvatar,
    required this.videoId,
    this.description,
    this.rating,
    this.uploadDate,
    this.quality,
  });

  @override
  String toString() {
    return 'Video{title: $title, duration: $duration, views: $views, rating: $rating}';
  }
}

class XHamsterService {
  static const String baseUrl = 'https://xhamster44.desi';
  static const String categoriesUrl = '$baseUrl/categories';

  // Headers to mimic a real browser request
  static final Map<String, String> headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
    // REMOVE THIS LINE: 'Accept-Encoding': 'gzip, deflate, br',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
  };
  // Add to your XHamsterService class
  Future<Map<String, dynamic>?> getVideoStream(String videoUrl) async {
    try {
      final response = await http.post(
        Uri.parse('https://0nnf7qzl-5000.inc1.devtunnels.ms/hamster/stream'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'url': videoUrl}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final searchId = data['search_id'];

        // Poll for status
        while (true) {
          await Future.delayed(const Duration(milliseconds: 500));

          final statusResponse = await http.get(
            Uri.parse(
              'https://0nnf7qzl-5000.inc1.devtunnels.ms/search/status/$searchId',
            ),
          );

          if (statusResponse.statusCode == 200) {
            final statusData = json.decode(statusResponse.body);
            final status = statusData['status'];

            if (status == 'stream_ready' || status == 'completed') {
              return statusData['data'];
            } else if (status == 'error') {
              throw Exception(
                statusData['error'] ?? 'Failed to extract stream',
              );
            }
          }
        }
      } else {
        throw Exception('Failed to start stream extraction');
      }
    } catch (e) {
      print('Error getting video stream: $e');
      rethrow;
    }
  }

  Future<List<XHamsterCategory>> getCategories() async {
    print('=== getCategories() called ===');
    try {
      print('Making HTTP request to: $categoriesUrl');
      final response = await http.get(
        Uri.parse(categoriesUrl),
        headers: headers,
      );

      print('Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        String body;

        // Check if response is Brotli compressed
        if (response.headers['content-encoding'] == 'br') {
          print('Decompressing Brotli data...');
          final decompressed = brotli.decode(response.bodyBytes);
          body = utf8.decode(decompressed);
        } else {
          body = response.body;
        }

        print('Body length after decompression: ${body.length}');
        print('Status 200 - Starting to parse...');
        return _parseCategories(body);
      } else {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      print('ERROR in getCategories: $e');
      throw Exception('Error fetching categories: $e');
    }
  }

  // Get videos from a category
  Future<List<XHamsterVideo>> getVideosFromCategory(String categoryUrl) async {
    print('=== getVideosFromCategory() called ===');
    print('Category URL: $categoryUrl');

    try {
      final response = await http.get(Uri.parse(categoryUrl), headers: headers);

      print('Response status code: ${response.statusCode}');
      print('Content-Encoding: ${response.headers['content-encoding']}');

      if (response.statusCode == 200) {
        String body;

        // Check if response is Brotli compressed
        if (response.headers['content-encoding'] == 'br') {
          print('Decompressing Brotli data...');
          final decompressed = brotli.decode(response.bodyBytes);
          body = utf8.decode(decompressed);
        } else {
          body = response.body;
        }

        print('Body length: ${body.length}');
        print('Starting to parse videos...');
        return _parseVideos(body);
      } else {
        throw Exception('Failed to load videos: ${response.statusCode}');
      }
    } catch (e) {
      print('ERROR in getVideosFromCategory: $e');
      throw Exception('Error fetching videos: $e');
    }
  }

  // Search videos
  Future<List<XHamsterVideo>> searchVideos(String query) async {
    print('=== searchVideos() called ===');
    print('Query: $query');

    try {
      final searchUrl = '$baseUrl/search/$query';
      print('Search URL: $searchUrl');

      final response = await http.get(Uri.parse(searchUrl), headers: headers);

      print('Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        String body;

        // Check if response is Brotli compressed
        if (response.headers['content-encoding'] == 'br') {
          print('Decompressing Brotli data...');
          final decompressed = brotli.decode(response.bodyBytes);
          body = utf8.decode(decompressed);
        } else {
          body = response.body;
        }

        print('Body length: ${body.length}');
        return _parseVideos(body);
      } else {
        throw Exception('Failed to search videos: ${response.statusCode}');
      }
    } catch (e) {
      print('ERROR in searchVideos: $e');
      throw Exception('Error searching videos: $e');
    }
  }

  // Parse videos from HTML
  List<XHamsterVideo> _parseVideos(String html) {
    final document = parser.parse(html);
    final videos = <XHamsterVideo>[];

    final videoElements = document.querySelectorAll(
      '.thumb-list__item.video-thumb[data-video-type="video"]',
    );

    for (final element in videoElements) {
      try {
        // Extract video ID
        final videoId = element.attributes['data-video-id'] ?? '';

        // Extract title
        final titleElement = element.querySelector('.video-thumb-info__name');
        final title = titleElement?.text.trim() ?? 'Unknown Title';

        // Extract description (if available in thumb view)
        final descElement = element.querySelector(
          '.video-thumb__description, .thumb-description',
        );
        final description = descElement?.text.trim();

        // Extract thumbnail
        final imgElement = element.querySelector(
          '.thumb-image-container__image',
        );
        String? thumbnail = imgElement?.attributes['src'];

        if (thumbnail == null || thumbnail.isEmpty) {
          final srcset = imgElement?.attributes['srcset'];
          if (srcset != null) {
            final urls = srcset.split(',').map((e) => e.trim().split(' ')[0]);
            thumbnail = urls.first;
          }
        }

        if (thumbnail != null && !thumbnail.startsWith('http')) {
          thumbnail =
              baseUrl + (thumbnail.startsWith('/') ? '' : '/') + thumbnail;
        }

        // Extract duration
        final durationElement = element.querySelector(
          '[data-role="video-duration"]',
        );
        final duration = durationElement?.text.trim() ?? 'N/A';

        // Extract views
        final viewsElement = element.querySelector('.video-thumb-views');
        final views = viewsElement?.text.trim() ?? 'N/A';

        // Extract rating
        double? rating;
        final ratingElement = element.querySelector(
          '.video-thumb__rating, [data-role="rating"], .thumb-rating',
        );
        if (ratingElement != null) {
          final ratingText = ratingElement.text.trim();
          final ratingMatch = RegExp(r'(\d+\.?\d*)').firstMatch(ratingText);
          if (ratingMatch != null) {
            rating = double.tryParse(ratingMatch.group(1) ?? '');
            if (ratingText.contains('%') && rating != null) {
              rating = rating / 10;
            }
          }
        }
        rating ??= double.tryParse(element.attributes['data-rating'] ?? '');

        // Extract upload date
        String? uploadDate;
        final dateElement = element.querySelector(
          '.video-thumb__upload-date, .video-thumb-info__date, [data-role="upload-date"], .thumb-date',
        );
        uploadDate = dateElement?.text.trim();
        uploadDate ??= element.attributes['data-upload-date'];

        // Extract quality
        String? quality;
        final qualityElement = element.querySelector(
          '.video-thumb__quality, .thumb-quality',
        );
        quality = qualityElement?.text.trim();

        final hdBadge = element.querySelector(
          '.thumb-image-container__badge, .video-badge',
        );
        if (hdBadge != null) {
          quality = hdBadge.text.trim();
        }

        // Extract uploader info
        final uploaderElement = element.querySelector('.video-uploader__name');
        final uploader = uploaderElement?.text.trim() ?? 'Unknown';

        // Extract uploader avatar
        final avatarElement = element.querySelector('.video-uploader-logo');
        String? uploaderAvatar =
            avatarElement?.attributes['data-background-image'] ??
            avatarElement?.attributes['style']
                ?.split('url("')
                .last
                .split('"')
                .first;

        if (uploaderAvatar != null && !uploaderAvatar.startsWith('http')) {
          uploaderAvatar =
              baseUrl +
              (uploaderAvatar.startsWith('/') ? '' : '/') +
              uploaderAvatar;
        }

        // Extract video URL
        final urlElement = element.querySelector('a[data-role="thumb-link"]');
        String? url = urlElement?.attributes['href'];
        if (url != null && !url.startsWith('http')) {
          url = baseUrl + (url.startsWith('/') ? '' : '/') + url;
        }

        // Only add if we have valid data
        if (title.isNotEmpty && thumbnail != null && thumbnail.isNotEmpty) {
          videos.add(
            XHamsterVideo(
              title: title,
              thumbnail: thumbnail,
              url: url ?? '',
              duration: duration,
              views: views,
              uploader: uploader,
              uploaderAvatar: uploaderAvatar ?? '',
              videoId: videoId,
              description: description,
              rating: rating,
              uploadDate: uploadDate,
              quality: quality,
            ),
          );
        }
      } catch (e) {
        print('Error parsing video element: $e');
        continue;
      }
    }

    return videos;
  }

  // Alternative video parsing method
  List<XHamsterVideo> _parseVideosAlternative(String html) {
    final document = parser.parse(html);
    final videos = <XHamsterVideo>[];

    // Try different selectors for video elements
    final selectors = [
      '.video-thumb[data-video-id]',
      '.thumb-list__item[data-video-type="video"]',
      '[data-player="true"]',
    ];

    for (final selector in selectors) {
      final elements = document.querySelectorAll(selector);
      if (elements.isNotEmpty) {
        for (final element in elements) {
          try {
            final titleElement = element.querySelector(
              '.video-thumb-info__name, .title',
            );
            final title = titleElement?.text.trim() ?? 'Unknown Title';

            final imgElement = element.querySelector('img');
            String? thumbnail =
                imgElement?.attributes['src'] ??
                imgElement?.attributes['data-src'];

            if (thumbnail != null && !thumbnail.startsWith('http')) {
              thumbnail =
                  baseUrl + (thumbnail.startsWith('/') ? '' : '/') + thumbnail;
            }

            final durationElement = element.querySelector(
              '.thumb-image-container__duration, [data-role="video-duration"]',
            );
            final duration = durationElement?.text.trim() ?? 'N/A';

            final viewsElement = element.querySelector(
              '.video-thumb-views, .views',
            );
            final views = viewsElement?.text.trim() ?? 'N/A';

            final urlElement = element.querySelector('a');
            String? url = urlElement?.attributes['href'];
            if (url != null && !url.startsWith('http')) {
              url = baseUrl + (url.startsWith('/') ? '' : '/') + url;
            }

            if (title.isNotEmpty && thumbnail != null && thumbnail.isNotEmpty) {
              videos.add(
                XHamsterVideo(
                  title: title,
                  thumbnail: thumbnail,
                  url: url ?? '',
                  duration: duration,
                  views: views,
                  uploader: 'Unknown',
                  uploaderAvatar: '',
                  videoId: element.attributes['data-video-id'] ?? '',
                ),
              );
            }
          } catch (e) {
            continue;
          }
        }
        break; // Stop after first successful selector
      }
    }

    return videos;
  }

  // Your existing category parsing methods...
  List<XHamsterCategory> _parseCategories(String html) {
    print('=== Starting to parse categories (Alternative) ===');
    final document = parser.parse(html);
    final categories = <XHamsterCategory>[];

    final selectors = [
      'section#actions a.thumbItem-f658a',
      'a.thumbItem-f658a',
      '.thumbItem-f658a',
      'a[href*="/categories/"]',
    ];

    for (final selector in selectors) {
      print('\nTrying selector: $selector');
      final elements = document.querySelectorAll(selector);
      print('Found ${elements.length} elements');

      if (elements.isNotEmpty) {
        for (int i = 0; i < elements.length; i++) {
          final element = elements[i];
          print(
            '\n--- Processing element ${i + 1} with selector: $selector ---',
          );

          try {
            final imgElement = element.querySelector('img');
            final h3Element = element.querySelector('h3');

            print('Image element: ${imgElement != null}');
            print('H3 element: ${h3Element != null}');

            final title =
                imgElement?.attributes['alt']?.trim() ??
                h3Element?.text.trim() ??
                'Unknown Category';

            print('Title: $title');

            String? coverImage = imgElement?.attributes['src'];
            print('Cover image: $coverImage');

            if (coverImage != null && !coverImage.startsWith('http')) {
              coverImage =
                  baseUrl +
                  (coverImage.startsWith('/') ? '' : '/') +
                  coverImage;
            }

            String? url = element.attributes['href'];
            print('URL: $url');

            if (url != null && !url.startsWith('http')) {
              url = baseUrl + (url.startsWith('/') ? '' : '/') + url;
            }

            if (title.isNotEmpty &&
                coverImage != null &&
                coverImage.isNotEmpty) {
              categories.add(
                XHamsterCategory(
                  title: title.trim(),
                  coverImage: coverImage,
                  url: url ?? '',
                ),
              );
              print('✓ Added');
            } else {
              print('✗ Skipped');
            }
          } catch (e) {
            print('✗ Error: $e');
            continue;
          }
        }
        print('\n✓ Successfully parsed with selector: $selector');
        break;
      }
    }

    print('\n=== Total categories: ${categories.length} ===\n');
    return categories;
  }

  List<XHamsterCategory> _parseCategoriesAlternative(String html) {
    final document = parser.parse(html);
    final categories = <XHamsterCategory>[];

    final selectors = [
      'section#actions a[href*="/categories/"]',
      '.thumbItem-f658a',
      '.item-f658a',
      'a[class*="thumbItem"]',
      'a[href^="/categories/"]',
    ];

    for (final selector in selectors) {
      final elements = document.querySelectorAll(selector);
      if (elements.isNotEmpty) {
        for (final element in elements) {
          try {
            final imgElement = element.querySelector('img');
            final title =
                imgElement?.attributes['alt'] ??
                element.text.trim() ??
                'Unknown Category';

            String? coverImage = imgElement?.attributes['src'];
            if (coverImage != null && !coverImage.startsWith('http')) {
              coverImage =
                  baseUrl +
                  (coverImage.startsWith('/') ? '' : '/') +
                  coverImage;
            }

            String? url = element.attributes['href'];
            if (url != null && !url.startsWith('http')) {
              url = baseUrl + (url.startsWith('/') ? '' : '/') + url;
            }

            if (title.isNotEmpty &&
                coverImage != null &&
                coverImage.isNotEmpty) {
              categories.add(
                XHamsterCategory(
                  title: title.trim(),
                  coverImage: coverImage,
                  url: url ?? '',
                ),
              );
            }
          } catch (e) {
            continue;
          }
        }
        break;
      }
    }

    return categories;
  }
}

class XHamsterCategory {
  final String title;
  final String coverImage;
  final String url;

  XHamsterCategory({
    required this.title,
    required this.coverImage,
    required this.url,
  });

  @override
  String toString() {
    return 'Category{title: $title, coverImage: $coverImage, url: $url}';
  }
}
