import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:soyo/models/pondo_models.dart';

class PondoScraper {
  static const String baseUrl = 'https://en.1pondo.tv';
  static const String apiUrl = '$baseUrl/dyn/phpauto/movie_lists';

  // Get newest videos with pagination
  static String getNewestUrl(int page) {
    return '$apiUrl/list_newest_${page - 1}.json';
  }

  Future<List<PondoVideo>> getNewestVideos({
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final response = await http.get(Uri.parse(getNewestUrl(page)));

      if (response.statusCode != 200) {
        throw Exception('Failed to load API: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final List<dynamic> rows = data['Rows'] ?? [];
      final int totalRows = data['TotalRows'] ?? 0;
      final int splitSize = data['SplitSize'] ?? 50;

      final List<PondoVideo> videos = [];

      for (final row in rows.take(limit)) {
        try {
          final video = _parseVideoRow(row);
          if (video != null) {
            videos.add(video);
          }
        } catch (e) {
          print('Error parsing video row: $e');
          continue;
        }
      }

      return videos;
    } catch (e) {
      print('Error getting newest videos: $e');
      return [];
    }
  }

  PondoVideo? _parseVideoRow(Map<String, dynamic> row) {
    try {
      // Extract basic info
      final String id = row['MovieID']?.toString() ?? '';
      final String title =
          row['TitleEn']?.toString() ?? row['Title']?.toString() ?? '';
      final String releaseDate = row['Release']?.toString() ?? '';
      final double rating = (row['AvgRating'] as num?)?.toDouble() ?? 0.0;
      final int duration = row['Duration'] as int? ?? 0;
      final bool canStream = row['CanStream'] as bool? ?? false;

      // Extract actress information
      final List<String> actressNames = _extractActressNames(row);

      // Extract thumbnail URLs
      final Map<String, String> thumbnails = _extractThumbnails(row);

      // Extract video URLs
      final List<VideoFile> memberFiles = _extractVideoFiles(
        row['MemberFiles'],
      );
      final List<VideoFile> sampleFiles = _extractVideoFiles(
        row['SampleFiles'],
      );

      // Extract tags in English
      final List<String> tags = _extractEnglishTags(row);

      // Extract series information
      final String series =
          row['SeriesEn']?.toString() ?? row['Series']?.toString() ?? '';

      return PondoVideo(
        id: id,
        title: title,
        actressNames: actressNames,
        releaseDate: releaseDate,
        rating: rating,
        duration: duration,
        canStream: canStream,
        thumbnails: thumbnails,
        memberFiles: memberFiles,
        sampleFiles: sampleFiles,
        tags: tags,
        series: series,
        description: row['DescEn']?.toString() ?? row['Desc']?.toString() ?? '',
        movieThumb: row['MovieThumb']?.toString() ?? '',
      );
    } catch (e) {
      print('Error in _parseVideoRow: $e');
      return null;
    }
  }

  List<String> _extractActressNames(Map<String, dynamic> row) {
    final List<String> names = [];

    // Try English names first
    final List<dynamic>? actressesEn = row['ActressesEn'];
    if (actressesEn != null && actressesEn.isNotEmpty) {
      for (final name in actressesEn) {
        if (name != null && name.toString().isNotEmpty) {
          names.add(name.toString());
        }
      }
    }

    // If no English names, try Japanese names
    if (names.isEmpty) {
      final List<dynamic>? actressesJa = row['ActressesJa'];
      if (actressesJa != null && actressesJa.isNotEmpty) {
        for (final name in actressesJa) {
          if (name != null && name.toString().isNotEmpty) {
            names.add(name.toString());
          }
        }
      }
    }

    // If still no names, try Actor field
    if (names.isEmpty) {
      final String? actor = row['Actor']?.toString();
      if (actor != null && actor.isNotEmpty) {
        names.add(actor);
      }
    }

    return names;
  }

  Map<String, String> _extractThumbnails(Map<String, dynamic> row) {
    final Map<String, String> thumbs = {};

    // Add different quality thumbnails
    final thumbUrls = {
      'ultra': row['ThumbUltra']?.toString(),
      'high': row['ThumbHigh']?.toString(),
      'medium': row['ThumbMed']?.toString(),
      'low': row['ThumbLow']?.toString(),
      'movie': row['MovieThumb']?.toString(),
    };

    for (final entry in thumbUrls.entries) {
      if (entry.value != null && entry.value!.isNotEmpty) {
        thumbs[entry.key] = entry.value!;
      }
    }

    return thumbs;
  }

  List<VideoFile> _extractVideoFiles(dynamic filesData) {
    final List<VideoFile> files = [];

    if (filesData is List) {
      for (final fileData in filesData) {
        try {
          final String fileName = fileData['FileName']?.toString() ?? '';
          final int fileSize = fileData['FileSize'] as int? ?? 0;
          final String url = fileData['URL']?.toString() ?? '';

          if (fileName.isNotEmpty && url.isNotEmpty) {
            files.add(
              VideoFile(
                fileName: fileName,
                fileSize: fileSize,
                url: url,
                quality: _extractQualityFromFileName(fileName),
              ),
            );
          }
        } catch (e) {
          print('Error parsing video file: $e');
          continue;
        }
      }
    }

    return files;
  }

  String _extractQualityFromFileName(String fileName) {
    if (fileName.contains('1080p')) return '1080p';
    if (fileName.contains('720p')) return '720p';
    if (fileName.contains('480p')) return '480p';
    if (fileName.contains('360p')) return '360p';
    if (fileName.contains('240p')) return '240p';
    return 'unknown';
  }

  List<String> _extractEnglishTags(Map<String, dynamic> row) {
    final List<String> tags = [];

    // Try English tags first
    final List<dynamic>? ucNameEn = row['UCNAMEEn'];
    if (ucNameEn != null) {
      for (final tag in ucNameEn) {
        if (tag != null && tag.toString().isNotEmpty) {
          tags.add(tag.toString());
        }
      }
    }

    // If no English tags, try to get from UcNameList
    if (tags.isEmpty) {
      final Map<String, dynamic>? ucNameList = row['UcNameList'];
      if (ucNameList != null) {
        for (final entry in ucNameList.entries) {
          final Map<String, dynamic>? tagInfo = entry.value;
          final String? nameEn = tagInfo?['NameEn']?.toString();
          if (nameEn != null && nameEn.isNotEmpty) {
            tags.add(nameEn);
          }
        }
      }
    }

    return tags.toSet().toList(); // Remove duplicates
  }

  // Get total pages available
  Future<int> getTotalPages() async {
    try {
      final response = await http.get(Uri.parse(getNewestUrl(1)));
      if (response.statusCode != 200) return 1;

      final data = jsonDecode(response.body);
      final int totalRows = data['TotalRows'] ?? 0;
      final int splitSize = data['SplitSize'] ?? 50;

      return (totalRows / splitSize).ceil();
    } catch (e) {
      print('Error getting total pages: $e');
      return 1;
    }
  }

  // Search functionality (you might need to find the search API endpoint)
  Future<List<PondoVideo>> searchVideos(String query, {int page = 1}) async {
    // Note: You'll need to find the actual search API endpoint
    // This is a placeholder that searches within the newest videos
    final allVideos = await getNewestVideos(page: page);

    if (query.isEmpty) return allVideos;

    final searchTerm = query.toLowerCase();
    return allVideos.where((video) {
      return video.title.toLowerCase().contains(searchTerm) ||
          video.actressNames.any(
            (actress) => actress.toLowerCase().contains(searchTerm),
          ) ||
          video.tags.any((tag) => tag.toLowerCase().contains(searchTerm)) ||
          video.series.toLowerCase().contains(searchTerm);
    }).toList();
  }
}

// Response model for paginated results
class PondoResponse {
  final List<PondoVideo> videos;
  final int currentPage;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;
  final String? searchQuery;

  PondoResponse({
    required this.videos,
    required this.currentPage,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPrevPage,
    this.searchQuery,
  });
}
