class PondoVideo {
  final String id;
  final String title;
  final List<String> actressNames;
  final String releaseDate;
  final double rating;
  final int duration;
  final bool canStream;
  final Map<String, String> thumbnails;
  final List<VideoFile> memberFiles;
  final List<VideoFile> sampleFiles;
  final List<String> tags;
  final String series;
  final String description;
  final String movieThumb;

  PondoVideo({
    required this.id,
    required this.title,
    required this.actressNames,
    required this.releaseDate,
    required this.rating,
    required this.duration,
    required this.canStream,
    required this.thumbnails,
    required this.memberFiles,
    required this.sampleFiles,
    required this.tags,
    required this.series,
    required this.description,
    required this.movieThumb,
  });

  String get primaryThumbnail =>
      thumbnails['high'] ?? thumbnails['medium'] ?? movieThumb;

  String get bestQualityThumbnail => thumbnails['ultra'] ?? primaryThumbnail;

  bool get hasClosedCaptions => tags.any(
    (tag) =>
        tag.toLowerCase().contains('subtitle') ||
        tag.toLowerCase().contains('cc'),
  );

  String get formattedDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }
}

class VideoFile {
  final String fileName;
  final int fileSize;
  final String url;
  final String quality;

  VideoFile({
    required this.fileName,
    required this.fileSize,
    required this.url,
    required this.quality,
  });

  String get formattedSize {
    if (fileSize >= 1073741824) {
      return '${(fileSize / 1073741824).toStringAsFixed(1)} GB';
    } else {
      return '${(fileSize / 1048576).toStringAsFixed(1)} MB';
    }
  }
}
