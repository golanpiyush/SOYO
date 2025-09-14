import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DownloadStatus {
  pending,
  downloading,
  completed,
  failed,
  cancelled,
  paused,
}

class DownloadItem {
  final String id;
  final String movieName;
  final String m3u8Url;
  final String outputPath;
  final List<String>? subtitles;
  DownloadStatus status;
  double progress;
  int downloadedSize;
  int totalSize;
  String? errorMessage;
  DateTime createdAt;
  DateTime? completedAt;
  int? sessionId;
  int retryCount;

  DownloadItem({
    required this.id,
    required this.movieName,
    required this.m3u8Url,
    required this.outputPath,
    this.subtitles,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.downloadedSize = 0,
    this.totalSize = 0,
    this.errorMessage,
    DateTime? createdAt,
    this.completedAt,
    this.sessionId,
    this.retryCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'movieName': movieName,
      'm3u8Url': m3u8Url,
      'outputPath': outputPath,
      'subtitles': subtitles,
      'status': status.index,
      'progress': progress,
      'downloadedSize': downloadedSize,
      'totalSize': totalSize,
      'errorMessage': errorMessage,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'sessionId': sessionId,
      'retryCount': retryCount,
    };
  }

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['id'],
      movieName: json['movieName'],
      m3u8Url: json['m3u8Url'],
      outputPath: json['outputPath'],
      subtitles: json['subtitles']?.cast<String>(),
      status: DownloadStatus.values[json['status'] ?? 0],
      progress: (json['progress'] ?? 0.0).toDouble(),
      downloadedSize: json['downloadedSize'] ?? 0,
      totalSize: json['totalSize'] ?? 0,
      errorMessage: json['errorMessage'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      completedAt: json['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['completedAt'])
          : null,
      sessionId: json['sessionId'],
      retryCount: json['retryCount'] ?? 0,
    );
  }
}

class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  final Map<String, DownloadItem> _downloads = {};
  final Map<String, StreamController<DownloadItem>> _progressControllers = {};
  final Map<String, Timer> _progressTimers = {};

  // Stream controller for download list updates
  final StreamController<Map<String, DownloadItem>> _downloadsController =
      StreamController<Map<String, DownloadItem>>.broadcast();

  Stream<Map<String, DownloadItem>> get downloadsStream =>
      _downloadsController.stream;
  Stream<DownloadItem> getDownloadProgress(String downloadId) {
    if (!_progressControllers.containsKey(downloadId)) {
      _progressControllers[downloadId] =
          StreamController<DownloadItem>.broadcast();
    }
    return _progressControllers[downloadId]!.stream;
  }

  Map<String, DownloadItem> get downloads => Map.unmodifiable(_downloads);

  Future<void> initialize() async {
    await _loadDownloads();
  }

  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+), we need different permissions
      final androidInfo = await _getAndroidInfo();

      if (androidInfo >= 33) {
        // Android 13+ - Request MANAGE_EXTERNAL_STORAGE or scoped storage
        final manageStoragePermission = await Permission.manageExternalStorage
            .request();
        if (manageStoragePermission.isGranted) {
          return true;
        }

        // Fallback to scoped storage permissions
        final videoPermission = await Permission.videos.request();
        return videoPermission.isGranted;
      } else if (androidInfo >= 30) {
        // Android 11-12 - Request MANAGE_EXTERNAL_STORAGE
        final manageStoragePermission = await Permission.manageExternalStorage
            .request();
        if (manageStoragePermission.isGranted) {
          return true;
        }

        // Fallback to legacy storage
        final storagePermission = await Permission.storage.request();
        return storagePermission.isGranted;
      } else {
        // Below Android 11 - Use legacy storage permission
        final storagePermission = await Permission.storage.request();
        return storagePermission.isGranted;
      }
    }
    return true; // iOS doesn't need explicit storage permission for app documents
  }

  Future<int> _getAndroidInfo() async {
    try {
      return Platform.version.contains('API')
          ? int.parse(Platform.version.split('API ')[1].split(')')[0])
          : 30; // Default to API 30 if we can't parse
    } catch (e) {
      return 30; // Default fallback
    }
  }

  Future<String> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // Try to get the public Downloads directory first
      try {
        final androidInfo = await _getAndroidInfo();
        if (androidInfo >= 30) {
          // For Android 11+, use app-specific external storage
          final directory = await getExternalStorageDirectory();
          if (directory != null) {
            final downloadsDir = Directory('${directory.path}/Downloads');
            if (!await downloadsDir.exists()) {
              await downloadsDir.create(recursive: true);
            }
            return downloadsDir.path;
          }
        } else {
          // For older Android versions, try public Downloads
          final directory = Directory('/storage/emulated/0/Download/Soyo');
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }
          return directory.path;
        }
      } catch (e) {
        print('Failed to access public downloads directory: $e');
      }

      // Fallback to app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${directory.path}/Downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      return downloadsDir.path;
    } else {
      // iOS
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${directory.path}/Downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      return downloadsDir.path;
    }
  }

  String _sanitizeFileName(String fileName) {
    // Remove or replace invalid characters
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_{2,}'), '_')
        .trim();
  }

  Future<String> startDownload({
    required String movieName,
    required String m3u8Url,
    List<String>? subtitles,
    String? quality,
  }) async {
    final hasPermission = await requestStoragePermission();
    if (!hasPermission) {
      throw Exception('Storage permission denied');
    }

    final downloadsDir = await _getDownloadsDirectory();
    final sanitizedName = _sanitizeFileName(movieName);
    final fileName =
        '${sanitizedName}_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final outputPath = '$downloadsDir/$fileName';

    final downloadId = '${movieName}_${DateTime.now().millisecondsSinceEpoch}';

    final downloadItem = DownloadItem(
      id: downloadId,
      movieName: movieName,
      m3u8Url: m3u8Url,
      outputPath: outputPath,
      subtitles: subtitles,
      status: DownloadStatus.pending,
    );

    _downloads[downloadId] = downloadItem;
    await _saveDownloads();
    _notifyDownloadsUpdate();

    // Start the actual download
    _executeDownload(downloadId);

    return downloadId;
  }

  Future<void> _executeDownload(String downloadId) async {
    final downloadItem = _downloads[downloadId];
    if (downloadItem == null) return;

    try {
      downloadItem.status = DownloadStatus.downloading;
      await _saveDownloads();
      _notifyDownloadsUpdate();
      _notifyProgressUpdate(downloadId, downloadItem);

      // Build FFmpeg command with enhanced error handling
      final command = _buildFFmpegCommand(
        downloadItem.m3u8Url,
        downloadItem.outputPath,
        downloadItem.retryCount,
      );

      print('Starting FFmpeg with command: $command');

      // Start progress timer
      _startProgressTimer(downloadId);

      final session = await FFmpegKit.executeAsync(
        command,
        (session) async {
          final returnCode = await session.getReturnCode();
          await _handleDownloadComplete(downloadId, returnCode);
        },
        (log) {
          final message = log.getMessage();
          print('FFmpeg Log: $message');

          // Check for specific error patterns and handle them
          if (message.contains('Invalid data found when processing input') ||
              message.contains('is not in allowed_extensions')) {
            print(
              'Detected M3U8 parsing error, will retry with different settings',
            );
          }
        },
        (statistics) {
          _handleStatistics(downloadId, statistics);
        },
      );

      downloadItem.sessionId = await session.getSessionId();
      await _saveDownloads();
    } catch (e) {
      downloadItem.status = DownloadStatus.failed;
      downloadItem.errorMessage = e.toString();
      await _saveDownloads();
      _notifyDownloadsUpdate();
      _notifyProgressUpdate(downloadId, downloadItem);
      _stopProgressTimer(downloadId);
      print('Download failed: $e');
    }
  }

  String _buildFFmpegCommand(
    String m3u8Url,
    String outputPath,
    int retryCount,
  ) {
    // Base command with enhanced HLS handling
    List<String> commandParts = [
      // Input options - more robust HLS handling
      '-user_agent',
      '"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"',
      '-headers', '"Referer: https://nebulavault823.xyz/"',
      '-reconnect', '1',
      '-reconnect_streamed', '1',
      '-reconnect_delay_max', '5',
      '-timeout', '30000000',
      '-rw_timeout', '30000000',

      // Protocol options for better HLS compatibility
      '-protocol_whitelist', 'file,http,https,tcp,tls,crypto',
      '-allowed_extensions', 'ALL',
      '-max_reload', '3000',

      // Input
      '-i', '"$m3u8Url"',

      // Output options
      '-c', 'copy',
      '-avoid_negative_ts', 'make_zero',
    ];

    // Add audio bitstream filter for AAC if needed
    if (retryCount == 0) {
      commandParts.addAll(['-bsf:a', 'aac_adtstoasc']);
    }

    // For retry attempts, try different approaches
    if (retryCount > 0) {
      commandParts.addAll(['-f', 'mp4', '-movflags', 'faststart']);
    }

    // Output file
    commandParts.add('"$outputPath"');

    return commandParts.join(' ');
  }

  void _handleStatistics(String downloadId, Statistics statistics) {
    final downloadItem = _downloads[downloadId];
    if (downloadItem == null ||
        downloadItem.status != DownloadStatus.downloading)
      return;

    final time = statistics.getTime();
    final size = statistics.getSize();

    if (time > 0) {
      // Better progress estimation using bitrate
      final bitrate = statistics.getBitrate();
      if (bitrate > 0) {
        // Estimate based on typical video lengths and bitrates
        final estimatedDurationMs = _estimateVideoDuration(bitrate);
        double progress = (time / estimatedDurationMs).clamp(0.0, 0.98);
        downloadItem.progress = progress;
      } else {
        // Fallback to time-based estimation
        final estimatedDurationMs = 7200000; // 2 hours default
        double progress = (time / estimatedDurationMs).clamp(0.0, 0.98);
        downloadItem.progress = progress;
      }

      downloadItem.downloadedSize = (size / 1024 / 1024).round(); // MB
      _notifyProgressUpdate(downloadId, downloadItem);
    }
  }

  int _estimateVideoDuration(double bitrate) {
    // Estimate video duration based on bitrate
    // This is a rough estimate - higher bitrate usually means higher quality/longer content
    if (bitrate > 5000) return 7200000; // High bitrate: ~2 hours
    if (bitrate > 2000) return 5400000; // Medium bitrate: ~1.5 hours
    return 3600000; // Low bitrate: ~1 hour
  }

  Future<void> _handleDownloadComplete(
    String downloadId,
    ReturnCode? returnCode,
  ) async {
    final downloadItem = _downloads[downloadId];
    if (downloadItem == null) return;

    _stopProgressTimer(downloadId);

    if (ReturnCode.isSuccess(returnCode)) {
      downloadItem.status = DownloadStatus.completed;
      downloadItem.progress = 1.0;
      downloadItem.completedAt = DateTime.now();

      // Verify file exists and get size
      final file = File(downloadItem.outputPath);
      if (await file.exists()) {
        final fileSize = await file.length();
        downloadItem.totalSize = (fileSize / 1024 / 1024).round(); // MB
        downloadItem.downloadedSize = downloadItem.totalSize;
      }
    } else {
      // Check if we should retry with different settings
      if (downloadItem.retryCount < 2 && _shouldRetryDownload(downloadItem)) {
        print(
          'Retrying download with different settings (attempt ${downloadItem.retryCount + 1})',
        );
        downloadItem.retryCount++;
        downloadItem.status = DownloadStatus.pending;
        downloadItem.errorMessage = null;
        await _saveDownloads();

        // Wait a bit before retrying
        await Future.delayed(const Duration(seconds: 3));
        _executeDownload(downloadId);
        return;
      }

      downloadItem.status = DownloadStatus.failed;
      downloadItem.errorMessage =
          'FFmpeg process failed with return code: $returnCode';
    }

    await _saveDownloads();
    _notifyDownloadsUpdate();
    _notifyProgressUpdate(downloadId, downloadItem);
  }

  bool _shouldRetryDownload(DownloadItem downloadItem) {
    final errorMessage = downloadItem.errorMessage?.toLowerCase() ?? '';
    return errorMessage.contains('invalid data') ||
        errorMessage.contains('allowed_extensions') ||
        errorMessage.contains('connection') ||
        errorMessage.contains('timeout');
  }

  void _startProgressTimer(String downloadId) {
    _progressTimers[downloadId] = Timer.periodic(const Duration(seconds: 2), (
      timer,
    ) {
      final downloadItem = _downloads[downloadId];
      if (downloadItem != null &&
          downloadItem.status == DownloadStatus.downloading) {
        _notifyProgressUpdate(downloadId, downloadItem);
      }
    });
  }

  void _stopProgressTimer(String downloadId) {
    _progressTimers[downloadId]?.cancel();
    _progressTimers.remove(downloadId);
  }

  void _notifyProgressUpdate(String downloadId, DownloadItem downloadItem) {
    if (_progressControllers.containsKey(downloadId)) {
      _progressControllers[downloadId]!.add(downloadItem);
    }
  }

  void _notifyDownloadsUpdate() {
    _downloadsController.add(Map.unmodifiable(_downloads));
  }

  Future<void> pauseDownload(String downloadId) async {
    final downloadItem = _downloads[downloadId];
    if (downloadItem == null ||
        downloadItem.status != DownloadStatus.downloading)
      return;

    if (downloadItem.sessionId != null) {
      await FFmpegKit.cancel(downloadItem.sessionId!);
    }

    downloadItem.status = DownloadStatus.paused;
    await _saveDownloads();
    _notifyDownloadsUpdate();
    _notifyProgressUpdate(downloadId, downloadItem);
    _stopProgressTimer(downloadId);
  }

  Future<void> resumeDownload(String downloadId) async {
    final downloadItem = _downloads[downloadId];
    if (downloadItem == null || downloadItem.status != DownloadStatus.paused)
      return;

    downloadItem.status = DownloadStatus.pending;
    await _saveDownloads();
    _executeDownload(downloadId);
  }

  Future<void> cancelDownload(String downloadId) async {
    final downloadItem = _downloads[downloadId];
    if (downloadItem == null) return;

    if (downloadItem.sessionId != null &&
        downloadItem.status == DownloadStatus.downloading) {
      await FFmpegKit.cancel(downloadItem.sessionId!);
    }

    // Delete partial file if exists
    final file = File(downloadItem.outputPath);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (e) {
        print('Failed to delete partial file: $e');
      }
    }

    downloadItem.status = DownloadStatus.cancelled;
    await _saveDownloads();
    _notifyDownloadsUpdate();
    _notifyProgressUpdate(downloadId, downloadItem);
    _stopProgressTimer(downloadId);
  }

  Future<void> deleteDownload(String downloadId) async {
    final downloadItem = _downloads[downloadId];
    if (downloadItem == null) return;

    // Cancel if downloading
    if (downloadItem.status == DownloadStatus.downloading) {
      await cancelDownload(downloadId);
    }

    // Delete file if exists
    final file = File(downloadItem.outputPath);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (e) {
        print('Failed to delete file: $e');
      }
    }

    // Remove from downloads
    _downloads.remove(downloadId);
    _progressControllers[downloadId]?.close();
    _progressControllers.remove(downloadId);
    _stopProgressTimer(downloadId);

    await _saveDownloads();
    _notifyDownloadsUpdate();
  }

  Future<void> retryDownload(String downloadId) async {
    final downloadItem = _downloads[downloadId];
    if (downloadItem == null || downloadItem.status != DownloadStatus.failed)
      return;

    downloadItem.status = DownloadStatus.pending;
    downloadItem.progress = 0.0;
    downloadItem.errorMessage = null;
    downloadItem.retryCount = 0; // Reset retry count for manual retry
    await _saveDownloads();

    _executeDownload(downloadId);
  }

  Future<void> _saveDownloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloadsJson = _downloads.map(
        (key, value) => MapEntry(key, value.toJson()),
      );
      await prefs.setString('downloads', jsonEncode(downloadsJson));
    } catch (e) {
      print('Failed to save downloads: $e');
    }
  }

  Future<void> _loadDownloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloadsString = prefs.getString('downloads');

      if (downloadsString != null) {
        final downloadsJson =
            jsonDecode(downloadsString) as Map<String, dynamic>;
        _downloads.clear();

        for (final entry in downloadsJson.entries) {
          final downloadItem = DownloadItem.fromJson(entry.value);

          // Reset downloading status to failed on app restart
          if (downloadItem.status == DownloadStatus.downloading) {
            downloadItem.status = DownloadStatus.failed;
            downloadItem.errorMessage = 'Download interrupted by app restart';
          }

          _downloads[entry.key] = downloadItem;
        }

        await _saveDownloads(); // Save the status updates
        _notifyDownloadsUpdate();
      }
    } catch (e) {
      print('Failed to load downloads: $e');
    }
  }

  String getDownloadedSize(String downloadId) {
    final downloadItem = _downloads[downloadId];
    if (downloadItem == null) return '0 MB';

    if (downloadItem.downloadedSize > 1024) {
      return '${(downloadItem.downloadedSize / 1024).toStringAsFixed(1)} GB';
    }
    return '${downloadItem.downloadedSize} MB';
  }

  String getFileSize(String downloadId) {
    final downloadItem = _downloads[downloadId];
    if (downloadItem == null || downloadItem.totalSize == 0) return 'Unknown';

    if (downloadItem.totalSize > 1024) {
      return '${(downloadItem.totalSize / 1024).toStringAsFixed(1)} GB';
    }
    return '${downloadItem.totalSize} MB';
  }

  bool isMovieDownloaded(String movieName) {
    return _downloads.values.any(
      (download) =>
          download.movieName == movieName &&
          download.status == DownloadStatus.completed,
    );
  }

  bool isMovieDownloading(String movieName) {
    return _downloads.values.any(
      (download) =>
          download.movieName == movieName &&
          (download.status == DownloadStatus.downloading ||
              download.status == DownloadStatus.pending),
    );
  }

  DownloadItem? getDownloadForMovie(String movieName) {
    try {
      return _downloads.values.firstWhere(
        (download) => download.movieName == movieName,
      );
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _downloadsController.close();
    for (final controller in _progressControllers.values) {
      controller.close();
    }
    _progressControllers.clear();

    for (final timer in _progressTimers.values) {
      timer.cancel();
    }
    _progressTimers.clear();
  }
}
