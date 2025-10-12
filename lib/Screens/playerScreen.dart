import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soyo/Services/m3u8api.dart';
import 'package:soyo/models/subtitle_model.dart';
import 'package:video_player/video_player.dart';
import 'package:lottie/lottie.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';

class SimpleStreamPlayer extends StatefulWidget {
  final String streamUrl;
  final String movieTitle;
  final Duration? startPosition;
  final Function(Duration)? onPositionChanged;
  final List<String>? subtitleUrls;
  final bool isLocalFile;
  final bool isTvShow;
  final int? currentEpisode;
  final int? totalEpisodes;
  final Function()? onNextEpisode;
  final Function()? onPreviousEpisode;
  final bool autoPlay; // Add this parameter
  final bool resumeFromLastPosition;
  final Map<String, String>? customHeaders; // Add this line
  // Add these new parameters
  final int? tmdbId; // For TV shows
  final int? seasonNumber; // Current season
  final String? quality; // Quality preference

  const SimpleStreamPlayer({
    Key? key,
    required this.streamUrl,
    required this.movieTitle,
    this.startPosition,
    this.onPositionChanged,
    this.subtitleUrls,
    this.isLocalFile = false,
    this.isTvShow = false,
    this.currentEpisode,
    this.totalEpisodes,
    this.onNextEpisode,
    this.onPreviousEpisode,
    this.autoPlay = true, // Default to true
    this.resumeFromLastPosition = false,
    this.customHeaders, // Add this line
    this.tmdbId,
    this.seasonNumber,
    this.quality,
  }) : super(key: key);

  @override
  State<SimpleStreamPlayer> createState() => _SimpleStreamPlayerState();
}

class _SimpleStreamPlayerState extends State<SimpleStreamPlayer>
    with TickerProviderStateMixin {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _error;
  bool _showControls = true;
  Timer? _controlsTimer;
  bool _isActualPinch = false;
  bool _showEpisodeSelector = false;
  Timer? _autoNextTimer;
  int _autoNextCountdown = 10; // seconds
  bool _isAutoNextActive = false;
  bool _isControlsLocked = false;
  double _currentScale = 1.0; // Changed to 2.0x as requested
  Offset _focalPoint = Offset.zero;
  double _currentBrightness = 0.5;
  double _currentVolume = 0.5;
  bool _resumeFromLastPosition = false; // ADD THIS LINE
  bool _isDragging = false;
  String? _overlayText;
  Timer? _overlayTimer;
  double _previousScale = 1.0; // Changed to match initial scale
  double _systemVolume = 0.5; // Add this line
  bool _showSubtitleSourceSelector = false;
  // Add these new variables after the existing state variables (around line 60)
  bool _enableDoubleTapSeek = true;
  bool _enableExtraVolume = false;
  double _volumeBoostMultiplier = 2.0; // 2.0 = 200%, 3.0 = 300%, 4.0 = 400%
  int _tapCount = 0;
  Timer? _doubleTapTimer;
  Offset? _lastTapPosition;

  bool _isLoadingNextEpisode = false;
  String _nextEpisodeStatus = '';
  bool _nextEpisodeReady = false;
  String? _nextEpisodeUrl;
  String? _prefetchedStreamUrl;
  List<String>? _prefetchedSubtitles;

  // Subtitle-related fields
  List<SubtitleEntry> _subtitles = [];
  String? _currentSubtitle;
  bool _showSubtitles = true;
  int _selectedSubtitleIndex = 0;
  List<String> _availableSubtitles = [];
  Timer? _subtitleTimer;
  bool _isVerticalSwipe = false;
  double _initialPanY = 0.0;
  static const double _minSwipeDistance = 10.0;

  // Subtitle customization - loaded from SharedPreferences
  Color _subtitleBackgroundColor = Colors.black.withOpacity(0.7);
  Color _subtitleTextColor = Colors.yellow;
  double _subtitleFontSize = 16.0;
  String _subtitleFontFamily = 'Cinzel';
  bool _subtitleOutline = true;
  double _subtitleSpeed = 1.0;

  late AnimationController _overlayController;
  late Animation<double> _overlayAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Controls visibility tracking
  bool _controlsVisible = true;
  Timer? _hideControlsTimer;
  AudioSession? _audioSession;
  double _audioGain = 1.0;
  static const platform = MethodChannel('com.soyo.audio/boost');

  final M3U8Api _m3u8 = M3U8Api();
  @override
  void initState() {
    super.initState();
    _initAnimations();
    _setLandscapeMode();
    _initBrightnessAndVolume();
    _initAudioBoost();
    _loadSubtitles();
    _initializeEverything(); // This already loads everything
  }

  @override
  void didUpdateWidget(SimpleStreamPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if episode changed or stream URL changed
    if (widget.streamUrl != oldWidget.streamUrl ||
        widget.currentEpisode != oldWidget.currentEpisode) {
      print('Episode/Stream changed, reinitializing player...');

      // Reset prefetch status
      _isLoadingNextEpisode = false;
      _nextEpisodeReady = false;
      _prefetchedStreamUrl = null;
      _prefetchedSubtitles = null;

      // Reload subtitles if they changed
      if (widget.subtitleUrls != oldWidget.subtitleUrls) {
        print('Subtitles changed, reloading...');
        _subtitleTimer?.cancel();
        _subtitles.clear();
        _currentSubtitle = null;
        _availableSubtitles.clear();
        _selectedSubtitleIndex = 0;
        _loadSubtitles();
      }

      // Reinitialize player
      _videoController.removeListener(_onPositionChanged);
      _videoController.dispose();
      _chewieController?.dispose();
      _initializePlayer();
    }
  }

  Future<void> _initializeEverything() async {
    // Load all settings FIRST before initializing player
    await _loadPlayerSettings();
    await _loadSubtitleSettings();
    await _loadStreamingSettings();
    // _clearAllSavedPositions();
    // Now initialize the player with all settings loaded
    await _initializePlayer();
  }

  // Add this method after _loadSubtitleSettings()
  Future<void> _loadPlayerSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enableDoubleTapSeek = prefs.getBool('enable_double_tap_seek') ?? true;
      _enableExtraVolume = prefs.getBool('enable_extra_volume') ?? false;
      _volumeBoostMultiplier =
          prefs.getDouble('volume_boost_multiplier') ?? 2.0;
    });
  }

  Future<void> _loadStreamingSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _resumeFromLastPosition =
          prefs.getBool('resume_from_last_position') ?? false;
    });
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _overlayController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _overlayAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _overlayController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadSubtitleSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _subtitleBackgroundColor = Color(
        prefs.getInt('subtitle_bg_color') ??
            Colors.black.withOpacity(0.7).value,
      );
      _subtitleTextColor = Color(
        prefs.getInt('subtitle_text_color') ?? Colors.yellow.value,
      );
      _subtitleFontSize = prefs.getDouble('subtitle_font_size') ?? 16.0;
      _subtitleFontFamily = prefs.getString('subtitle_font_family') ?? 'Cinzel';
      _subtitleOutline = prefs.getBool('subtitle_outline') ?? true;
      _subtitleSpeed = prefs.getDouble('subtitle_speed') ?? 1.0;
    });
  }

  Future<void> _initAudioBoost() async {
    try {
      await platform.invokeMethod('initAudioBoost');
    } on PlatformException catch (e) {
      print("Failed to initialize audio boost: ${e.message}");
    }
  }

  Future<void> _setAudioBoost(double multiplier) async {
    try {
      await platform.invokeMethod('setAudioBoost', {'multiplier': multiplier});
    } on PlatformException catch (e) {
      print("Failed to set audio boost: ${e.message}");
    }
  }

  Future<void> _releaseAudioBoost() async {
    try {
      await platform.invokeMethod('releaseAudioBoost');
    } on PlatformException catch (e) {
      print("Failed to release audio boost: ${e.message}");
    }
  }

  void _startAutoNextEpisode() {
    if (!widget.isTvShow || widget.onNextEpisode == null) return;

    // Start pre-fetching next episode immediately when countdown starts
    if (!_isLoadingNextEpisode && !_nextEpisodeReady) {
      _prefetchNextEpisode();
    }

    setState(() {
      _isAutoNextActive = true;
      _autoNextCountdown = 10;
    });

    _autoNextTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _autoNextCountdown--;
      });

      if (_autoNextCountdown <= 0) {
        timer.cancel();
        setState(() {
          _isAutoNextActive = false;
          _isLoadingNextEpisode = false;
        });
        widget.onNextEpisode!();
      }
    });
  }

  void _cancelAutoNext() {
    _autoNextTimer?.cancel();
    setState(() {
      _isAutoNextActive = false;
      _autoNextCountdown = 10;
      _isLoadingNextEpisode = false;
      _nextEpisodeReady = false;
      _prefetchedStreamUrl = null;
      _prefetchedSubtitles = null;
    });
  }

  Future<void> _prefetchNextEpisode() async {
    if (!widget.isTvShow ||
        widget.currentEpisode == null ||
        widget.tmdbId == null) {
      return;
    }

    try {
      final nextEpisodeNumber = (widget.currentEpisode ?? 0) + 1;

      setState(() {
        _isLoadingNextEpisode = true;
        _nextEpisodeReady = false;
      });

      print('Pre-fetching Episode $nextEpisodeNumber...');

      // Use searchTvShowByTmdbId with status callback
      final result = await _m3u8.searchTvShowByTmdbId(
        tmdbId: widget.tmdbId!,
        season: widget.seasonNumber ?? 1,
        episode: nextEpisodeNumber,
        quality: widget.quality ?? '1080',
        fetchSubs: true,
        onStatusUpdate: (status) {
          print('Next episode status: $status');
          // Optional: Show status updates in the UI
          if (status == 'stream_ready' || status == 'completed') {
            if (mounted) {
              setState(() {
                _nextEpisodeReady = true;
              });
            }
          }
        },
        onStreamReady: (streamUrl) {
          print('Next episode stream ready: $streamUrl');
          if (mounted) {
            setState(() {
              _prefetchedStreamUrl = streamUrl;
              _nextEpisodeReady = true;
              _isLoadingNextEpisode = false;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _prefetchedStreamUrl = result['m3u8_link'];
          _prefetchedSubtitles = (result['subtitles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList();
          _nextEpisodeReady = true;
          _isLoadingNextEpisode = false;
        });

        print('Next episode ready: ${_prefetchedStreamUrl != null}');
        print('Subtitles available: ${_prefetchedSubtitles?.length ?? 0}');
      }
    } catch (e) {
      print('Error pre-fetching next episode: $e');
      if (mounted) {
        setState(() {
          _isLoadingNextEpisode = false;
          _nextEpisodeReady = false;
          _prefetchedStreamUrl = null;
          _prefetchedSubtitles = null;
        });

        // Optionally show error to user
        _showOverlay('⚠️ Failed to load next episode');
      }
    }
  }

  Future<void> _loadSubtitles() async {
    print(
      'Loading subtitles... Available: ${widget.subtitleUrls?.length ?? 0}',
    );

    if (widget.subtitleUrls == null || widget.subtitleUrls!.isEmpty) {
      setState(() {
        _availableSubtitles = ['None'];
        _selectedSubtitleIndex = 0;
        _showSubtitles = false;
        _subtitles.clear();
        _currentSubtitle = null;
      });
      return;
    }

    // Analyze subtitles to detect language and filter for English
    final List<String> filteredSubtitleUrls = [];
    final List<String> filteredSubtitleLabels = [];

    for (int i = 0; i < widget.subtitleUrls!.length; i++) {
      final subtitleUrl = widget.subtitleUrls![i];
      try {
        final language = await _detectSubtitleLanguage(subtitleUrl);
        print('Subtitle ${i + 1} language detected: $language');

        if (_isEnglishSubtitle(language, subtitleUrl)) {
          filteredSubtitleUrls.add(subtitleUrl);
          final languageName = _getLanguageName(
            language,
          ); // Get proper language name
          filteredSubtitleLabels.add(
            '$languageName ${filteredSubtitleUrls.length}',
          );
        }
      } catch (e) {
        print('Error detecting language for subtitle $i: $e');
        // If detection fails, include it but mark as unknown
        filteredSubtitleUrls.add(subtitleUrl);
        filteredSubtitleLabels.add('Unknown ${filteredSubtitleUrls.length}');
      }
    }

    print(
      'Filtered subtitles: ${filteredSubtitleUrls.length} English/Unknown found',
    );

    _availableSubtitles = ['None', ...filteredSubtitleLabels];

    try {
      // Auto-load first English subtitle by default
      if (filteredSubtitleUrls.isNotEmpty) {
        print(
          'Auto-loading first filtered subtitle: ${filteredSubtitleUrls[0]}',
        );
        setState(() {
          _selectedSubtitleIndex = 1; // Select first subtitle (not "None")
          _showSubtitles = true;
        });
        await _loadSubtitleTrack(filteredSubtitleUrls[0]);
      } else if (widget.subtitleUrls!.isNotEmpty) {
        // Fallback: if no English detected, load first available with warning
        print('No English subtitles detected, falling back to first available');
        _availableSubtitles = [
          'None',
          ...List.generate(
            widget.subtitleUrls!.length,
            (index) => 'Subtitle ${index + 1}',
          ),
        ];
        setState(() {
          _selectedSubtitleIndex = 1;
          _showSubtitles = true;
        });
        await _loadSubtitleTrack(widget.subtitleUrls![0]);
        _showOverlay('⚠️ No English subtitles detected');
      }
    } catch (e) {
      print('Error loading subtitles: $e');
      setState(() {
        _selectedSubtitleIndex = 0;
        _showSubtitles = false;
      });
    }
  }

  String _getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'sv':
        return 'Swedish';
      case 'es':
        return 'Spanish';
      case 'fr':
        return 'French';
      case 'de':
        return 'German';
      case 'it':
        return 'Italian';
      case 'pt':
        return 'Portuguese';
      case 'nl':
        return 'Dutch';
      case 'ru':
        return 'Russian';
      case 'ja':
        return 'Japanese';
      case 'zh':
        return 'Chinese';
      case 'ko':
        return 'Korean';
      case 'ar':
        return 'Arabic';
      case 'hi':
        return 'Hindi';
      default:
        return 'Unknown';
    }
  }

  Future<String> _detectSubtitleLanguage(String subtitleUrl) async {
    try {
      final response = await http.get(Uri.parse(subtitleUrl));
      if (response.statusCode == 200) {
        final content = response.body;

        // Sample first 1000 characters for language detection
        final sample = content.length > 1000
            ? content.substring(0, 1000)
            : content;

        return _analyzeLanguage(sample);
      }
      return 'unknown';
    } catch (e) {
      print('Error detecting language from URL $subtitleUrl: $e');
      return 'unknown';
    }
  }

  String _analyzeLanguage(String text) {
    // Normalize text for analysis
    final lowerText = text.toLowerCase();
    final words = lowerText.split(RegExp(r'\s+'));

    // Common English words and patterns
    final englishPatterns = [
      'the',
      'and',
      'is',
      'in',
      'to',
      'of',
      'a',
      'that',
      'it',
      'with',
      'for',
      'are',
      'as',
      'be',
      'this',
      'you',
      'we',
      'they',
      'what',
      'why',
      'how',
      'when',
      'where',
      'who',
      'which',
      'have',
      'has',
      'been',
      'but',
      'not',
      'all',
      'can',
      'will',
      'would',
      'could',
      'should',
      'may',
      'might',
      'must',
      'shall',
      'their',
      'there',
      'from',
    ];

    // Common Swedish words
    final swedishPatterns = [
      'är',
      'och',
      'det',
      'att',
      'en',
      'ett',
      'som',
      'på',
      'med',
      'för',
      'av',
      'om',
      'inte',
      'han',
      'hon',
      'den',
      'detta',
      'här',
      'där',
      'när',
      'var',
      'vem',
      'vilken',
      'mitt',
      'min',
      'din',
      'sin',
      'er',
      'oss',
      'dem',
      'deras',
      'hennes',
      'hans',
      'sig',
      'sitt',
      'sina',
      'också',
      'upp',
      'ut',
      'får',
      'går',
      'kan',
      'ska',
      'kommer',
      'blev',
    ];

    // Common Spanish words
    final spanishPatterns = [
      'el',
      'la',
      'los',
      'las',
      'de',
      'que',
      'y',
      'en',
      'un',
      'una',
      'es',
      'con',
      'por',
      'para',
      'del',
      'al',
      'se',
      'no',
      'su',
      'lo',
      'le',
      'les',
      'me',
      'te',
      'nos',
      'os',
      'mi',
      'tu',
      'sus',
      'qué',
      'cómo',
      'cuándo',
      'dónde',
      'quién',
      'por qué',
      'este',
      'esta',
      'más',
      'pero',
      'como',
      'están',
      'todo',
      'también',
      'muy',
      'hay',
    ];

    // Common French words
    final frenchPatterns = [
      'le',
      'la',
      'les',
      'de',
      'et',
      'en',
      'un',
      'une',
      'des',
      'du',
      'au',
      'aux',
      'avec',
      'pour',
      'dans',
      'par',
      'sur',
      'est',
      'son',
      'ses',
      'mon',
      'ton',
      'notre',
      'votre',
      'leur',
      'que',
      'qui',
      'quoi',
      'comment',
      'quand',
      'où',
      'pourquoi',
      'ce',
      'cet',
      'cette',
      'ces',
      'mais',
      'ou',
      'donc',
      'car',
      'ne',
      'pas',
      'plus',
      'très',
      'tout',
    ];

    // Common German words
    final germanPatterns = [
      'der',
      'die',
      'das',
      'und',
      'in',
      'den',
      'von',
      'zu',
      'mit',
      'sich',
      'des',
      'ist',
      'ein',
      'eine',
      'für',
      'im',
      'dem',
      'nicht',
      'auf',
      'auch',
      'es',
      'an',
      'werden',
      'aus',
      'er',
      'hat',
      'dass',
      'sie',
      'nach',
      'wird',
      'bei',
      'einer',
      'um',
      'am',
      'sind',
      'noch',
      'wie',
      'einem',
      'über',
      'einen',
      'so',
      'zum',
      'war',
      'zur',
    ];

    // Common Italian words
    final italianPatterns = [
      'il',
      'lo',
      'la',
      'i',
      'gli',
      'le',
      'di',
      'da',
      'a',
      'in',
      'con',
      'su',
      'per',
      'tra',
      'fra',
      'è',
      'e',
      'che',
      'un',
      'una',
      'uno',
      'del',
      'della',
      'dei',
      'degli',
      'delle',
      'al',
      'alla',
      'ai',
      'agli',
      'alle',
      'nel',
      'nella',
      'nei',
      'negli',
      'nelle',
      'sul',
      'sulla',
      'sui',
      'sugli',
      'sulle',
      'non',
      'si',
      'mi',
      'ti',
      'ci',
      'vi',
      'lo',
      'la',
      'li',
      'le',
      'anche',
      'come',
      'più',
    ];

    // Common Portuguese words
    final portuguesePatterns = [
      'o',
      'a',
      'os',
      'as',
      'de',
      'da',
      'do',
      'das',
      'dos',
      'em',
      'no',
      'na',
      'nos',
      'nas',
      'um',
      'uma',
      'para',
      'com',
      'por',
      'que',
      'é',
      'e',
      'se',
      'ao',
      'à',
      'aos',
      'às',
      'pelo',
      'pela',
      'pelos',
      'pelas',
      'não',
      'mais',
      'como',
      'mas',
      'ou',
      'quando',
      'muito',
      'também',
      'só',
      'já',
      'ser',
      'tem',
      'são',
      'está',
    ];

    // Common Dutch words
    final dutchPatterns = [
      'de',
      'het',
      'een',
      'en',
      'van',
      'in',
      'is',
      'op',
      'te',
      'dat',
      'die',
      'aan',
      'met',
      'voor',
      'hij',
      'zij',
      'er',
      'naar',
      'om',
      'bij',
      'ook',
      'niet',
      'als',
      'zijn',
      'worden',
      'heeft',
      'kan',
      'maar',
      'over',
      'uit',
      'deze',
      'dit',
      'door',
      'meer',
      'wordt',
    ];

    // Common Russian words (transliterated)
    final russianPatterns = [
      'и',
      'в',
      'не',
      'на',
      'я',
      'что',
      'то',
      'он',
      'с',
      'как',
      'а',
      'это',
      'по',
      'но',
      'они',
      'к',
      'у',
      'его',
      'за',
      'о',
      'от',
      'из',
      'до',
      'мы',
      'вы',
      'так',
      'же',
      'для',
      'все',
      'был',
    ];

    // Common Japanese patterns (Hiragana/Katakana)
    final japanesePatterns = [
      'は',
      'の',
      'に',
      'を',
      'と',
      'が',
      'で',
      'た',
      'て',
      'も',
      'です',
      'ます',
      'する',
      'これ',
      'それ',
      'あれ',
      'この',
      'その',
    ];

    // Common Chinese patterns (Simplified)
    final chinesePatterns = [
      '的',
      '了',
      '在',
      '是',
      '我',
      '有',
      '和',
      '人',
      '这',
      '中',
      '大',
      '为',
      '上',
      '个',
      '国',
      '一',
      '们',
      '到',
      '说',
      '他',
    ];

    // Common Korean patterns (Hangul)
    final koreanPatterns = [
      '이',
      '가',
      '은',
      '는',
      '을',
      '를',
      '의',
      '에',
      '와',
      '과',
      '하다',
      '있다',
      '되다',
      '하는',
      '있는',
      '그',
      '저',
      '이것',
      '그것',
    ];

    // Common Hindi patterns (Devanagari)
    final hindiPatterns = [
      'है',
      'का',
      'की',
      'के',
      'को',
      'से',
      'में',
      'और',
      'यह',
      'वह',
      'पर',
      'कि',
      'ने',
      'एक',
      'था',
      'थी',
      'थे',
      'हैं',
      'हो',
      'होता',
    ];

    // Common Arabic patterns
    final arabicPatterns = [
      'في',
      'من',
      'إلى',
      'على',
      'أن',
      'هذا',
      'هذه',
      'الذي',
      'التي',
      'كان',
      'ما',
      'لا',
      'هو',
      'هي',
      'عن',
      'مع',
      'كل',
      'قد',
      'له',
    ];

    // Count matches for each language
    Map<String, int> scores = {
      'en': _countMatches(words, englishPatterns),
      'sv': _countMatches(words, swedishPatterns),
      'es': _countMatches(words, spanishPatterns),
      'fr': _countMatches(words, frenchPatterns),
      'de': _countMatches(words, germanPatterns),
      'it': _countMatches(words, italianPatterns),
      'pt': _countMatches(words, portuguesePatterns),
      'nl': _countMatches(words, dutchPatterns),
      'ru': _countMatches(words, russianPatterns),
      'ja': _countMatches(words, japanesePatterns),
      'zh': _countMatches(words, chinesePatterns),
      'ko': _countMatches(words, koreanPatterns),
      'hi': _countMatches(words, hindiPatterns),
      'ar': _countMatches(words, arabicPatterns),
    };

    // Find language with highest score
    String detectedLang = 'en'; // default
    int maxScore = 0;

    scores.forEach((lang, score) {
      if (score > maxScore) {
        maxScore = score;
        detectedLang = lang;
      }
    });

    return detectedLang;
  }

  int _countMatches(List<String> words, List<String> patterns) {
    int count = 0;
    for (var word in words) {
      if (patterns.contains(word)) {
        count++;
      }
    }
    return count;
  }

  bool _isEnglishSubtitle(String detectedLanguage, String subtitleUrl) {
    // Check URL for language indicators
    final lowerUrl = subtitleUrl.toLowerCase();

    // English indicators in URL
    final hasEnglishInUrl =
        lowerUrl.contains('en') ||
        lowerUrl.contains('eng') ||
        lowerUrl.contains('english');

    // Other language indicators in URL (for filtering)
    final hasOtherLanguageInUrl =
        lowerUrl.contains('sv') ||
        lowerUrl.contains('swe') ||
        lowerUrl.contains('swedish') ||
        lowerUrl.contains('es') ||
        lowerUrl.contains('spa') ||
        lowerUrl.contains('spanish') ||
        lowerUrl.contains('fr') ||
        lowerUrl.contains('fre') ||
        lowerUrl.contains('french') ||
        lowerUrl.contains('de') ||
        lowerUrl.contains('ger') ||
        lowerUrl.contains('german') ||
        lowerUrl.contains('it') ||
        lowerUrl.contains('ita') ||
        lowerUrl.contains('italian') ||
        lowerUrl.contains('pt') ||
        lowerUrl.contains('por') ||
        lowerUrl.contains('portuguese') ||
        lowerUrl.contains('nl') ||
        lowerUrl.contains('dut') ||
        lowerUrl.contains('dutch') ||
        lowerUrl.contains('ru') ||
        lowerUrl.contains('rus') ||
        lowerUrl.contains('russian') ||
        lowerUrl.contains('ja') ||
        lowerUrl.contains('jpn') ||
        lowerUrl.contains('japanese') ||
        lowerUrl.contains('ko') ||
        lowerUrl.contains('kor') ||
        lowerUrl.contains('korean') ||
        lowerUrl.contains('ar') ||
        lowerUrl.contains('ara') ||
        lowerUrl.contains('arabic') ||
        lowerUrl.contains('hi') ||
        lowerUrl.contains('hin') ||
        lowerUrl.contains('hindi') ||
        lowerUrl.contains('zh') ||
        lowerUrl.contains('chi') ||
        lowerUrl.contains('chinese');

    // Priority: URL indicators > content analysis
    if (hasEnglishInUrl) return true;
    if (hasOtherLanguageInUrl) return false;

    // Fallback to content analysis
    return detectedLanguage == 'en'; // Changed from 'english' to 'en'
  }

  Future<void> _loadSubtitleTrack(String subtitleUrl) async {
    try {
      print('🔄 Loading subtitle track: $subtitleUrl');

      final response = await http.get(Uri.parse(subtitleUrl));

      if (response.statusCode == 200) {
        final content = response.body;

        // Debug: Show first 500 characters of content
        print('📄 Subtitle content preview (first 500 chars):');
        print(content.substring(0, math.min(500, content.length)));
        print('...');

        // Detect language for logging
        final language = _analyzeLanguage(content);
        print(
          '📝 Subtitle language: $language, format: ${content.trim().startsWith('WEBVTT') ? 'VTT' : 'SRT'}',
        );

        final parsedSubtitles = content.trim().startsWith('WEBVTT')
            ? _parseVTT(content)
            : _parseSRTFormat(content);

        if (mounted) {
          setState(() {
            _subtitles = parsedSubtitles;
            _currentSubtitle = null;
          });
        }

        _subtitleTimer?.cancel();
        _startSubtitleTimer();

        print('✅ Loaded ${_subtitles.length} subtitle entries ($language)');

        if (_subtitles.isEmpty) {
          print('⚠️ WARNING: No subtitles were parsed!');
          print('Full content length: ${content.length} characters');
        }
      } else {
        print('❌ Failed to load subtitles: HTTP ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('❌ Error loading subtitle track: $e');
      print('URL: $subtitleUrl');
    }
  }

  List<SubtitleEntry> _parseSRT(String content) {
    final List<SubtitleEntry> subtitles = [];

    // Clean up the content first
    final cleanedContent = content.trim().replaceAll('\r\n', '\n');

    // Check if it's VTT format (starts with WEBVTT)
    final isVTT = cleanedContent.startsWith('WEBVTT');

    if (isVTT) {
      print('Detected VTT subtitle format');
      return _parseVTT(cleanedContent);
    } else {
      print('Detected SRT subtitle format');
      return _parseSRTFormat(cleanedContent);
    }
  }

  // Replace your _parseVTT method with this fixed version:
  List<SubtitleEntry> _parseVTT(String vttContent) {
    final List<SubtitleEntry> subtitles = [];

    // Remove WEBVTT header and split by double newlines or single newlines
    var content = vttContent.trim();

    // Remove WEBVTT header if present
    if (content.startsWith('WEBVTT')) {
      final headerEnd = content.indexOf('\n');
      if (headerEnd != -1) {
        content = content.substring(headerEnd + 1);
      }
    }

    // Split into lines and process
    final lines = content.split('\n');

    String? currentTimecode;
    List<String> currentTextLines = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Skip empty lines and NOTE/STYLE blocks
      if (line.isEmpty) {
        // If we have accumulated text, process it
        if (currentTimecode != null && currentTextLines.isNotEmpty) {
          _processVTTCue(currentTimecode, currentTextLines, subtitles);
          currentTimecode = null;
          currentTextLines = [];
        }
        continue;
      }

      if (line.startsWith('NOTE') || line.startsWith('STYLE')) {
        continue;
      }

      // Check if this is a timecode line
      if (line.contains('-->')) {
        // Save previous cue if exists
        if (currentTimecode != null && currentTextLines.isNotEmpty) {
          _processVTTCue(currentTimecode, currentTextLines, subtitles);
        }

        currentTimecode = line;
        currentTextLines = [];
      } else if (currentTimecode != null) {
        // This is subtitle text
        // Skip cue identifier numbers (lines that are just digits)
        if (RegExp(r'^\d+$').hasMatch(line)) {
          continue;
        }
        currentTextLines.add(line);
      }
    }

    // Process last cue if exists
    if (currentTimecode != null && currentTextLines.isNotEmpty) {
      _processVTTCue(currentTimecode, currentTextLines, subtitles);
    }

    print('✅ Parsed ${subtitles.length} VTT subtitle entries');

    if (subtitles.isNotEmpty) {
      print('First subtitle: "${subtitles.first.text}"');
      print('Start: ${_formatDuration(subtitles.first.startTime)}');
      print('End: ${_formatDuration(subtitles.first.endTime)}');
    }

    return subtitles;
  }

  void _processVTTCue(
    String timecodeLine,
    List<String> textLines,
    List<SubtitleEntry> subtitles,
  ) {
    try {
      // Extract just the timecode part (remove any cue settings)
      final timeParts = timecodeLine.split(' --> ');
      if (timeParts.length != 2) return;

      // Remove any cue settings that follow the end time
      final startTimeStr = timeParts[0].trim();
      final endTimeStr = timeParts[1]
          .split(' ')[0]
          .trim(); // Take only time, ignore settings

      final startTime = _parseVTTTimeCode(startTimeStr);
      final endTime = _parseVTTTimeCode(endTimeStr);

      // Clean and join text lines
      final text = textLines
          .map(
            (line) => line
                .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
                .replaceAll(RegExp(r'&nbsp;'), ' ')
                .replaceAll(RegExp(r'&amp;'), '&')
                .replaceAll(RegExp(r'&lt;'), '<')
                .replaceAll(RegExp(r'&gt;'), '>')
                .replaceAll(RegExp(r'&quot;'), '"')
                .trim(),
          )
          .where((line) => line.isNotEmpty)
          .join('\n')
          .trim();

      if (text.isNotEmpty) {
        subtitles.add(
          SubtitleEntry(startTime: startTime, endTime: endTime, text: text),
        );
      }
    } catch (e) {
      print('⚠️ Error processing VTT cue: $e');
      print('Timecode: $timecodeLine');
    }
  }

  Duration _parseVTTTimeCode(String timeCode) {
    try {
      final cleanedTimeCode = timeCode.trim();

      // Handle formats: HH:MM:SS.mmm or MM:SS.mmm
      final parts = cleanedTimeCode.split(':');

      int hours = 0;
      int minutes = 0;
      int seconds = 0;
      int milliseconds = 0;

      if (parts.length == 3) {
        // HH:MM:SS.mmm format
        hours = int.parse(parts[0]);
        minutes = int.parse(parts[1]);

        final secondsPart = parts[2].replaceAll(',', '.');
        final secondsAndMs = secondsPart.split('.');
        seconds = int.parse(secondsAndMs[0]);

        if (secondsAndMs.length > 1) {
          final msStr = secondsAndMs[1].padRight(3, '0').substring(0, 3);
          milliseconds = int.parse(msStr);
        }
      } else if (parts.length == 2) {
        // MM:SS.mmm format (no hours)
        minutes = int.parse(parts[0]);

        final secondsPart = parts[1].replaceAll(',', '.');
        final secondsAndMs = secondsPart.split('.');
        seconds = int.parse(secondsAndMs[0]);

        if (secondsAndMs.length > 1) {
          final msStr = secondsAndMs[1].padRight(3, '0').substring(0, 3);
          milliseconds = int.parse(msStr);
        }
      } else {
        throw FormatException('Invalid VTT timecode format: $timeCode');
      }

      return Duration(
        hours: hours,
        minutes: minutes,
        seconds: seconds,
        milliseconds: milliseconds,
      );
    } catch (e) {
      print('⚠️ Error parsing VTT timecode "$timeCode": $e');
      return Duration.zero;
    }
  }

  List<SubtitleEntry> _parseSRTFormat(String srtContent) {
    final List<SubtitleEntry> subtitles = [];
    final blocks = srtContent.split('\n\n');

    print('Parsing SRT: Found ${blocks.length} blocks');

    for (final block in blocks) {
      final lines = block.trim().split('\n');
      if (lines.length >= 3) {
        try {
          // Skip the index number (first line)
          final timecodeLine = lines[1].trim();
          final textLines = lines.sublist(2);

          final times = timecodeLine.split(' --> ');
          if (times.length == 2) {
            final startTime = _parseTimeCode(times[0].trim());
            final endTime = _parseTimeCode(times[1].trim());
            final text = textLines
                .join('\n')
                .replaceAll(RegExp(r'<[^>]*>'), '')
                .trim();

            if (text.isNotEmpty) {
              subtitles.add(
                SubtitleEntry(
                  startTime: startTime,
                  endTime: endTime,
                  text: text,
                ),
              );

              // Debug first subtitle
              if (subtitles.length == 1) {
                print('First SRT subtitle parsed:');
                print(
                  '  Start: ${startTime.inMilliseconds}ms (${_formatDuration(startTime)})',
                );
                print(
                  '  End: ${endTime.inMilliseconds}ms (${_formatDuration(endTime)})',
                );
                print('  Text: $text');
              }
            }
          }
        } catch (e) {
          print('Error parsing SRT block: $e');
          continue;
        }
      }
    }

    print('Total SRT subtitles parsed: ${subtitles.length}');
    return subtitles;
  }

  // Keep the original SRT timecode parser but rename it
  Duration _parseTimeCode(String timeCode) {
    try {
      final parts = timeCode.trim().split(':');
      if (parts.length != 3) {
        throw FormatException('Invalid timecode format: $timeCode');
      }

      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);

      // Handle both comma and period as decimal separator
      final secondsPart = parts[2].replaceAll(',', '.');
      final secondsAndMs = secondsPart.split('.');

      final seconds = int.parse(secondsAndMs[0]);
      final milliseconds = secondsAndMs.length > 1
          ? int.parse(secondsAndMs[1].padRight(3, '0').substring(0, 3))
          : 0;

      return Duration(
        hours: hours,
        minutes: minutes,
        seconds: seconds,
        milliseconds: milliseconds,
      );
    } catch (e) {
      print('Error parsing timecode "$timeCode": $e');
      return Duration.zero;
    }
  }

  // Helper method for debug output
  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final milliseconds = (duration.inMilliseconds % 1000).toString().padLeft(
      3,
      '0',
    );
    return '$hours:$minutes:$seconds,$milliseconds';
  }

  void _startSubtitleTimer() {
    _subtitleTimer?.cancel();
    _subtitleTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_videoController.value.isInitialized &&
          _showSubtitles &&
          _subtitles.isNotEmpty) {
        final currentPosition = _videoController.value.position;
        String? newSubtitle;

        // Debug: Log timing occasionally
        if (_subtitles.isNotEmpty && currentPosition.inSeconds % 10 == 0) {
          print('Current position: ${_formatDuration(currentPosition)}');
          print('Looking for subtitle in ${_subtitles.length} entries');
        }

        for (final subtitle in _subtitles) {
          if (currentPosition >= subtitle.startTime &&
              currentPosition <= subtitle.endTime) {
            newSubtitle = subtitle.text;
            break;
          }
        }

        if (newSubtitle != _currentSubtitle) {
          if (mounted) {
            setState(() {
              _currentSubtitle = newSubtitle;
            });
            if (newSubtitle != null) {
              print(
                'Subtitle displayed at ${_formatDuration(currentPosition)}: $newSubtitle',
              );
            } else {
              print('Subtitle cleared at ${_formatDuration(currentPosition)}');
            }
          }
        }
      }
    });
  }

  void _setLandscapeMode() async {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Load immersive mode preference
    final prefs = await SharedPreferences.getInstance();
    final immersiveMode = prefs.getBool('immersive_mode') ?? false;

    if (immersiveMode) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive, overlays: []);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _initBrightnessAndVolume() async {
    try {
      _currentBrightness = await ScreenBrightness().current;
    } catch (e) {
      _currentBrightness = 0.5;
    }

    // Initialize audio session for volume boost
    try {
      _audioSession = await AudioSession.instance;
      await _audioSession!.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.duckOthers,
          avAudioSessionMode: AVAudioSessionMode.moviePlayback,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.movie,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        ),
      );
    } catch (e) {
      print('Error initializing audio session: $e');
    }

    // Initialize volume controller
    try {
      FlutterVolumeController.updateShowSystemUI(false);
      final volume = await FlutterVolumeController.getVolume();
      setState(() {
        _currentVolume = volume ?? 0.7;
        _systemVolume = volume ?? 0.7;
      });
    } catch (e) {
      _currentVolume = 0.7;
      _systemVolume = 0.7;
    }
  }

  // 1. Update the _initializePlayer method to set showControls based on lock state
  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      if (widget.isLocalFile) {
        _videoController = VideoPlayerController.file(File(widget.streamUrl));
      } else {
        // Extract base URL for resolving relative paths in M3U8
        final uri = Uri.parse(widget.streamUrl);
        final baseUrl =
            '${uri.scheme}://${uri.host}${uri.path.substring(0, uri.path.lastIndexOf('/') + 1)}';

        final headers = <String, String>{
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': '*/*',
          'Accept-Language': 'en-US,en;q=0.9',
          'Accept-Encoding': 'identity',
          'Connection': 'keep-alive',
          'Sec-Fetch-Dest': 'empty',
          'Sec-Fetch-Mode': 'cors',
          'Sec-Fetch-Site': 'cross-site',
        };

        // Add custom headers if provided, or use defaults
        if (widget.customHeaders != null) {
          headers.addAll(widget.customHeaders!);
        } else {
          // Default referer/origin for worker URLs
          if (uri.host.contains('workers.dev') ||
              uri.host.contains('wyzie.ru')) {
            headers['Referer'] = 'https://111movies.com/';
            headers['Origin'] = 'https://111movies.com';
          } else {
            headers['Referer'] = '${uri.scheme}://${uri.host}/';
            headers['Origin'] = '${uri.scheme}://${uri.host}';
          }
        }

        print('Initializing player with URL: ${widget.streamUrl}');
        print('Base URL: $baseUrl');
        print('Headers: $headers');

        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.streamUrl),
          httpHeaders: headers,
        );
      }

      await _videoController.initialize();

      await _loadSavedPosition();
      _videoController.addListener(_onPositionChanged);

      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: widget.autoPlay,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        showControls: !_isControlsLocked,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color.fromARGB(255, 189, 229, 9),
          handleColor: const Color.fromARGB(255, 9, 229, 27),
          backgroundColor: Colors.white.withOpacity(0.2),
          bufferedColor: Colors.white.withOpacity(0.4),
        ),
        placeholder: Container(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
          ),
        ),
        autoInitialize: true,
      );

      _showControlsTemporarily();

      setState(() {
        _isLoading = false;
      });

      _fadeController.forward();
    } catch (e) {
      print('Player initialization error: $e');
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadSavedPosition() async {
    print('DEBUG: _resumeFromLastPosition = $_resumeFromLastPosition');

    final prefs = await SharedPreferences.getInstance();

    // If resume is disabled, clear any saved positions and start fresh
    if (!_resumeFromLastPosition) {
      print(
        'DEBUG: Resume disabled, clearing saved positions and starting from beginning',
      );

      // Clear saved positions
      if (widget.isTvShow && widget.currentEpisode != null) {
        final episodeKey =
            '${widget.movieTitle}_ep${widget.currentEpisode}_position';
        await prefs.remove(episodeKey);
      } else {
        await prefs.remove('${widget.movieTitle}_position');
      }

      // Start from provided position or beginning
      if (widget.startPosition != null) {
        await _videoController.seekTo(widget.startPosition!);
      } else {
        await _videoController.seekTo(Duration.zero);
      }
      return;
    }

    print('DEBUG: Resume enabled, checking for saved position');

    // Only check saved positions if resume is enabled
    // For TV shows
    if (widget.isTvShow && widget.currentEpisode != null) {
      final episodeKey =
          '${widget.movieTitle}_ep${widget.currentEpisode}_position';
      final episodePosition = prefs.getInt(episodeKey) ?? 0;

      if (episodePosition > 10000) {
        await _videoController.seekTo(Duration(milliseconds: episodePosition));
        print(
          'Resumed TV show from position: ${Duration(milliseconds: episodePosition)}',
        );
        return;
      }
    } else {
      // For movies
      final savedPosition = prefs.getInt('${widget.movieTitle}_position') ?? 0;

      if (savedPosition > 10000) {
        final duration = _videoController.value.duration;
        if (duration.inMilliseconds > 0) {
          final percentage = savedPosition / duration.inMilliseconds;
          // Only resume if not near the end (less than 95%)
          if (percentage < 0.95) {
            await _videoController.seekTo(
              Duration(milliseconds: savedPosition),
            );
            print(
              'Resumed movie from position: ${Duration(milliseconds: savedPosition)}',
            );
            return;
          }
        }
      }
    }

    // If no valid saved position found, start from beginning or provided startPosition
    if (widget.startPosition != null) {
      await _videoController.seekTo(widget.startPosition!);
    } else {
      await _videoController.seekTo(Duration.zero);
    }
  }

  Future<void> _clearAllSavedPositions() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.contains('_position')) {
        await prefs.remove(key);
        print('Cleared: $key');
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('All saved positions cleared'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _savePosition(Duration position) async {
    final prefs = await SharedPreferences.getInstance();

    // Don't save anything if resume is disabled
    if (!_resumeFromLastPosition) {
      // Also clear any existing saved positions when disabled
      if (widget.isTvShow && widget.currentEpisode != null) {
        final episodeKey =
            '${widget.movieTitle}_ep${widget.currentEpisode}_position';
        await prefs.remove(episodeKey);
      } else {
        await prefs.remove('${widget.movieTitle}_position');
      }
      return;
    }

    // Don't save if near the end (last 5%)
    final duration = _videoController.value.duration;
    if (duration.inMilliseconds > 0) {
      final percentage = position.inMilliseconds / duration.inMilliseconds;
      if (percentage > 0.95) {
        // If near the end, clear the saved position
        if (widget.isTvShow && widget.currentEpisode != null) {
          final episodeKey =
              '${widget.movieTitle}_ep${widget.currentEpisode}_position';
          await prefs.remove(episodeKey);
        } else {
          await prefs.remove('${widget.movieTitle}_position');
        }
        return;
      }
    }

    // Save position every 5 seconds
    if (position.inSeconds % 5 == 0) {
      if (widget.isTvShow && widget.currentEpisode != null) {
        final episodeKey =
            '${widget.movieTitle}_ep${widget.currentEpisode}_position';
        await prefs.setInt(episodeKey, position.inMilliseconds);
      } else {
        await prefs.setInt(
          '${widget.movieTitle}_position',
          position.inMilliseconds,
        );
      }
    }
  }

  void _onPositionChanged() {
    if (_videoController.value.isInitialized) {
      final position = _videoController.value.position;
      final duration = _videoController.value.duration;

      if (widget.onPositionChanged != null) {
        widget.onPositionChanged!(position);
      }
      if (position.inSeconds % 10 == 0) {
        _savePosition(position);
      }

      // Pre-fetch next episode at 40 seconds remaining (before auto-next at 30s)
      if (widget.isTvShow &&
          widget.onNextEpisode != null &&
          duration.inSeconds > 0 &&
          !_nextEpisodeReady &&
          !_isLoadingNextEpisode) {
        final remainingSeconds = duration.inSeconds - position.inSeconds;
        if (remainingSeconds <= 40 && remainingSeconds > 30) {
          print('Starting pre-fetch at 40 seconds remaining');
          _prefetchNextEpisode();
        }
      }

      // Auto-next feature for TV shows
      if (widget.isTvShow &&
          widget.onNextEpisode != null &&
          duration.inSeconds > 0 &&
          !_isAutoNextActive) {
        final remainingSeconds = duration.inSeconds - position.inSeconds;
        if (remainingSeconds <= 30 && remainingSeconds > 0) {
          _startAutoNextEpisode();
        }
      }
    }
  }

  Widget _buildEpisodeSelector() {
    if (!widget.isTvShow || !_showEpisodeSelector) return SizedBox.shrink();

    return Positioned(
      top: MediaQuery.of(context).padding.top + 70,
      left: 16,
      right: 16,
      child: AnimatedOpacity(
        opacity: _showEpisodeSelector ? 1.0 : 0.0,
        duration: Duration(milliseconds: 300),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Episode Navigation',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _showEpisodeSelector = false),
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              if (widget.currentEpisode != null && widget.totalEpisodes != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Color(0xFF6366F1).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tv_rounded,
                        color: Color(0xFF6366F1),
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Episode ${widget.currentEpisode} of ${widget.totalEpisodes}',
                        style: GoogleFonts.inter(
                          color: Color(0xFF6366F1),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 16),
              Row(
                children: [
                  if (widget.onPreviousEpisode != null)
                    Expanded(
                      child: Container(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isLoadingNextEpisode = true;
                              _nextEpisodeReady = false;
                              _showEpisodeSelector = false;
                            });
                            widget.onPreviousEpisode!();
                          },
                          icon: Icon(Icons.skip_previous_rounded, size: 20),
                          label: Text(
                            'Previous',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[800],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                  if (widget.onPreviousEpisode != null &&
                      widget.onNextEpisode != null)
                    SizedBox(width: 12),
                  if (widget.onNextEpisode != null)
                    Expanded(
                      child: Container(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isLoadingNextEpisode = true;
                              _nextEpisodeReady = false;
                              _showEpisodeSelector = false;
                            });
                            widget.onNextEpisode!();
                          },
                          icon: Icon(Icons.skip_next_rounded, size: 20),
                          label: Text(
                            'Next',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutoNextOverlay() {
    // Show if auto-next is active OR if manually loading next episode
    if (!_isAutoNextActive && !_isLoadingNextEpisode) return SizedBox.shrink();

    return Positioned(
      bottom: 120,
      right: 16,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _nextEpisodeReady
                ? Colors.green.withOpacity(0.5)
                : _isLoadingNextEpisode
                ? Colors.orange.withOpacity(0.5)
                : Color(0xFF6366F1).withOpacity(0.5),
            width: 2,
          ),
        ),
        child: _isLoadingNextEpisode && !_isAutoNextActive
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Loading Next Episode...',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_nextEpisodeReady)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      margin: EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Episode ${(widget.currentEpisode ?? 0) + 1} Ready',
                            style: GoogleFonts.inter(
                              color: Colors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_isLoadingNextEpisode) // Show loading indicator even during auto-next
                    Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.orange,
                          ),
                        ),
                      ),
                    ),
                  Text(
                    'Next Episode in',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _nextEpisodeReady
                          ? Colors.green
                          : Color(0xFF6366F1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _autoNextCountdown.toString(),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  GestureDetector(
                    onTap: _cancelAutoNext,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.5)),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _handleManualEpisodeChange(VoidCallback episodeCallback) {
    setState(() {
      _isLoadingNextEpisode = true;
      _nextEpisodeReady = false;
      _showEpisodeSelector = false;
      _prefetchedStreamUrl = null;
      _prefetchedSubtitles = null;
    });

    // Show loading overlay
    _showOverlay('Loading episode...');

    // Call the episode change callback
    episodeCallback();
  }

  void _handleBrightnessPanStart(DragStartDetails details) {
    if (_isControlsLocked) return;
    _initialPanY = details.localPosition.dy;
    _isVerticalSwipe = false;
  }

  void _handleBrightnessPanUpdate(DragUpdateDetails details) {
    if (_isControlsLocked) return;

    final deltaY = details.delta.dy;
    final deltaX = details.delta.dx;
    final totalDeltaY = (details.localPosition.dy - _initialPanY).abs();

    if (!_isVerticalSwipe && totalDeltaY > _minSwipeDistance) {
      if (deltaY.abs() > deltaX.abs() * 2) {
        _isVerticalSwipe = true;
        setState(() {
          _isDragging = true;
        });
      }
    }

    if (_isVerticalSwipe && _isDragging) {
      _adjustBrightness(-deltaY / MediaQuery.of(context).size.height);
    }
  }

  void _handleBrightnessPanEnd(DragEndDetails details) {
    if (_isVerticalSwipe && _isDragging) {
      setState(() {
        _isDragging = false;
      });
      _hideOverlay();
    }
    _isVerticalSwipe = false;
  }

  void _handleVolumePanStart(DragStartDetails details) {
    if (_isControlsLocked) return;
    _initialPanY = details.localPosition.dy;
    _isVerticalSwipe = false;
  }

  void _handleVolumePanUpdate(DragUpdateDetails details) {
    if (_isControlsLocked) return;

    final deltaY = details.delta.dy;
    final deltaX = details.delta.dx;
    final totalDeltaY = (details.localPosition.dy - _initialPanY).abs();

    if (!_isVerticalSwipe && totalDeltaY > _minSwipeDistance) {
      if (deltaY.abs() > deltaX.abs() * 2) {
        _isVerticalSwipe = true;
        setState(() {
          _isDragging = true;
        });
      }
    }

    if (_isVerticalSwipe && _isDragging) {
      _adjustVolume(-deltaY / MediaQuery.of(context).size.height);
    }
  }

  void _handleVolumePanEnd(DragEndDetails details) {
    if (_isVerticalSwipe && _isDragging) {
      setState(() {
        _isDragging = false;
      });
      _hideOverlay();
    }
    _isVerticalSwipe = false;
  }

  void _adjustBrightness(double delta) async {
    _currentBrightness = (_currentBrightness + delta).clamp(0.0, 1.0);
    try {
      await ScreenBrightness().setApplicationScreenBrightness(
        _currentBrightness,
      );
    } catch (e) {
      // Handle error silently
    }
    _showOverlay('🔆 ${(_currentBrightness * 100).round()}%');
  }

  void _adjustVolume(double delta) async {
    _currentVolume = (_currentVolume + delta).clamp(0.0, 1.0);
    _systemVolume = _currentVolume;

    // Set system volume
    try {
      await FlutterVolumeController.setVolume(_systemVolume);
    } catch (e) {
      print('Error setting system volume: $e');
    }

    // Apply native audio boost
    if (_videoController.value.isInitialized) {
      await _videoController.setVolume(1.0); // Always max for video player

      if (_enableExtraVolume) {
        final boostMultiplier = _currentVolume * _volumeBoostMultiplier;
        await _setAudioBoost(boostMultiplier);
      } else {
        await _setAudioBoost(_currentVolume);
      }
    }

    final displayVolume = _enableExtraVolume
        ? (_currentVolume * _volumeBoostMultiplier * 100).round()
        : (_currentVolume * 100).round();
    _showOverlay('🔊 $displayVolume%');
  }

  void _showOverlay(String text) {
    setState(() {
      _overlayText = text;
    });

    _overlayController.forward();

    _overlayTimer?.cancel();
    _overlayTimer = Timer(Duration(milliseconds: 1000), () {
      _hideOverlay();
    });
  }

  void _hideOverlay() {
    _overlayController.reverse().then((_) {
      setState(() {
        _overlayText = null;
      });
    });
  }

  void _handleScaleStart(ScaleStartDetails details) {
    if (_isControlsLocked) return;
    _focalPoint = details.focalPoint;
    _previousScale = _currentScale;
    _isActualPinch = false;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_isControlsLocked) return;

    // Only respond to actual pinch gestures (scale significantly != 1.0)
    if ((details.scale - 1.0).abs() < 0.05) return;

    _isActualPinch = true;
    double newScale = _previousScale * details.scale;
    newScale = newScale.clamp(0.5, 2.0);
    setState(() {
      _currentScale = newScale;
    });
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    // Only process if it was an actual pinch gesture
    if (!_isActualPinch) return;

    // Snap to predefined zoom levels
    if (_currentScale > 1.875) {
      setState(() => _currentScale = 2.0);
    } else if (_currentScale > 1.625) {
      setState(() => _currentScale = 1.75);
    } else if (_currentScale > 1.375) {
      setState(() => _currentScale = 1.5);
    } else if (_currentScale > 1.125) {
      setState(() => _currentScale = 1.25);
    } else if (_currentScale > 0.875) {
      setState(() => _currentScale = 1.0);
    } else if (_currentScale > 0.625) {
      setState(() => _currentScale = 0.75);
    } else {
      setState(() => _currentScale = 0.5);
    }
    _showOverlay('Zoom: ${_currentScale.toStringAsFixed(2)}x');
    _isActualPinch = false;
  }

  Widget _buildBackButton() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      child: AnimatedOpacity(
        opacity: (_showControls || _isControlsLocked) ? 1.0 : 0.0,
        duration: Duration(milliseconds: 300),
        child: Row(
          children: [
            Material(
              color: Colors.transparent,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: _isControlsLocked
                      ? () => _showOverlay('🔒 Controls are locked')
                      : () {
                          _resetToPortraitMode();
                          Navigator.of(context).pop();
                        },
                  child: Center(
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
            if (widget.isTvShow && !_isControlsLocked) ...[
              SizedBox(width: 12),
              Material(
                color: Colors.transparent,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => setState(
                      () => _showEpisodeSelector = !_showEpisodeSelector,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.playlist_play_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Updated _buildSubtitleControls method
  Widget _buildSubtitleControls() {
    if (_availableSubtitles.isEmpty) {
      return SizedBox.shrink();
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: AnimatedOpacity(
        opacity: _showControls || _isControlsLocked ? 1.0 : 0.0,
        duration: Duration(milliseconds: 300),
        child: Row(
          children: [
            // Add source selector button - ONLY show when not locked
            if (!widget.isLocalFile && !_isControlsLocked)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    print('Settings button tapped!');
                    print('Current state: $_showSubtitleSourceSelector');
                    setState(() {
                      _showSubtitleSourceSelector =
                          !_showSubtitleSourceSelector;
                    });
                    print('New state: $_showSubtitleSourceSelector');
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: EdgeInsets.all(10),
                    margin: EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: _showSubtitleSourceSelector
                          ? Color(0xFF6366F1).withOpacity(0.3)
                          : Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _showSubtitleSourceSelector
                            ? Color(0xFF6366F1)
                            : Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.settings,
                      color: _showSubtitleSourceSelector
                          ? Color(0xFF6366F1)
                          : Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            // Existing subtitle dropdown
            Material(
              color: Colors.transparent,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.closed_caption,
                      color: _showSubtitles ? Color(0xFF6366F1) : Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _selectedSubtitleIndex,
                      dropdownColor: Color(0xFF1F1F1F),
                      underline: SizedBox.shrink(),
                      iconEnabledColor: Colors.white,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      items: _availableSubtitles.asMap().entries.map((entry) {
                        return DropdownMenuItem<int>(
                          value: entry.key,
                          child: Row(
                            children: [
                              if (entry.key == _selectedSubtitleIndex)
                                Icon(
                                  Icons.check,
                                  color: Color(0xFF6366F1),
                                  size: 16,
                                ),
                              if (entry.key == _selectedSubtitleIndex)
                                SizedBox(width: 8),
                              Text(entry.value),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: _isControlsLocked
                          ? null
                          : (value) async {
                              if (value != null) {
                                setState(() {
                                  _selectedSubtitleIndex = value;
                                  _currentSubtitle = null;
                                });

                                if (value == 0) {
                                  setState(() {
                                    _showSubtitles = false;
                                    _subtitles.clear();
                                  });
                                  _subtitleTimer?.cancel();
                                  _showOverlay('Subtitles Off');
                                } else {
                                  setState(() {
                                    _showSubtitles = true;
                                  });

                                  final subtitleIndex = value - 1;
                                  final subtitleUrl =
                                      widget.subtitleUrls![subtitleIndex];

                                  await _loadSubtitleTrack(subtitleUrl);

                                  final language =
                                      await _detectSubtitleLanguage(
                                        subtitleUrl,
                                      );
                                  final languageLabel = _getLanguageName(
                                    language,
                                  );

                                  _showOverlay(
                                    '$languageLabel Subtitle Selected',
                                  );
                                }
                              }
                            },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleLock() {
    setState(() {
      _isControlsLocked = !_isControlsLocked;
    });

    // Update Chewie controller to show/hide controls based on lock state
    if (_chewieController != null) {
      _chewieController!.dispose();
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        allowFullScreen: !_isControlsLocked,
        allowMuting: !_isControlsLocked,
        allowPlaybackSpeedChanging: !_isControlsLocked,
        showControls: !_isControlsLocked,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color.fromARGB(255, 181, 229, 9),
          handleColor: const Color.fromARGB(255, 170, 229, 9),
          backgroundColor: Colors.white.withOpacity(0.2),
          bufferedColor: Colors.white.withOpacity(0.4),
        ),
        placeholder: Container(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
          ),
        ),
        autoInitialize: true,
      );
    }

    // Show overlay with proper text
    final lockText = _isControlsLocked
        ? '🔒 Controls Locked'
        : '🔓 Controls Unlocked';
    _showOverlay(lockText);
  }

  // Add this new method to handle controls visibility
  void _showControlsTemporarily() {
    setState(() {
      _showControls = true;
    });

    _controlsTimer?.cancel();
    _controlsTimer = Timer(Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  Widget _buildSubtitleDisplay() {
    // More explicit visibility check
    final shouldShow =
        _showSubtitles &&
        _currentSubtitle != null &&
        _currentSubtitle!.isNotEmpty &&
        _videoController.value.isInitialized &&
        !_videoController.value.hasError;

    if (!shouldShow) {
      return SizedBox.shrink();
    }

    return Positioned(
      bottom: 40,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: _subtitleBackgroundColor != Colors.transparent
              ? BoxDecoration(
                  color: _subtitleBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: Text(
            _currentSubtitle!,
            textAlign: TextAlign.center,
            style: GoogleFonts.getFont(
              _subtitleFontFamily,
              color: _subtitleTextColor,
              fontSize: _subtitleFontSize,
              fontWeight: FontWeight.w500,
              height: 1.4,
              shadows: _subtitleOutline
                  ? [
                      Shadow(
                        offset: Offset(1, 1),
                        blurRadius: 2,
                        color: Colors.black,
                      ),
                      Shadow(
                        offset: Offset(-1, -1),
                        blurRadius: 2,
                        color: Colors.black,
                      ),
                      Shadow(
                        offset: Offset(1, -1),
                        blurRadius: 2,
                        color: Colors.black,
                      ),
                      Shadow(
                        offset: Offset(-1, 1),
                        blurRadius: 2,
                        color: Colors.black,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockButton() {
    return Positioned(
      bottom: 40, // Changed from 24 to 80 to move it up
      right: 24,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _isControlsLocked
              ? Color.fromARGB(255, 116, 23, 23).withOpacity(0.9)
              : Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isControlsLocked
                ? Color(0xFFEF4444).withOpacity(0.3)
                : Colors.white.withOpacity(0.2),
            width: 2,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: _toggleLock,
            child: Center(
              child: Icon(
                _isControlsLocked
                    ? Icons.lock_rounded
                    : Icons.lock_open_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGestureControls() {
    if (_isControlsLocked) return SizedBox.shrink();

    return Stack(
      children: [
        // Left side gesture area for brightness
        Positioned(
          left: 0,
          top: MediaQuery.of(context).padding.top + 80,
          width: MediaQuery.of(context).size.width * 0.3, // 30% of screen width
          bottom: 120, // Leave space for bottom controls
          child: GestureDetector(
            onPanStart: _handleBrightnessPanStart,
            onPanUpdate: _handleBrightnessPanUpdate,
            onPanEnd: _handleBrightnessPanEnd,
            child: Container(color: Colors.transparent),
          ),
        ),
        // Right side gesture area for volume
        Positioned(
          right: 0,
          top: MediaQuery.of(context).padding.top + 80,
          width: MediaQuery.of(context).size.width * 0.3, // 30% of screen width
          bottom: 120, // Leave space for bottom controls
          child: GestureDetector(
            onPanStart: _handleVolumePanStart,
            onPanUpdate: _handleVolumePanUpdate,
            onPanEnd: _handleVolumePanEnd,
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }

  Widget _buildControlsOverlay() {
    return Center(
      child: FadeTransition(
        opacity: _overlayAnimation,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: Text(
            _overlayText!,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // Add these methods before the build() method
  void _handleTap(TapDownDetails details) {
    if (_isControlsLocked) return;

    final position = details.localPosition;
    final screenWidth = MediaQuery.of(context).size.width;

    // Center zone is 40% of screen (30% from each edge)
    final leftSeekEnd = screenWidth * 0.3;
    final rightSeekStart = screenWidth * 0.7;

    _tapCount++;
    _lastTapPosition = position;

    if (_tapCount == 1) {
      _doubleTapTimer = Timer(Duration(milliseconds: 300), () {
        // Single tap - show/hide controls
        if (_tapCount == 1) {
          _showControlsTemporarily();
        }
        _tapCount = 0;
        _lastTapPosition = null;
      });
    } else if (_tapCount == 2) {
      _doubleTapTimer?.cancel();

      // Double tap detected
      if (position.dx >= leftSeekEnd && position.dx <= rightSeekStart) {
        // Center 40% area - play/pause
        _handleCenterDoubleTap();
      } else if (_enableDoubleTapSeek) {
        // Left/Right 30% areas - seek
        if (position.dx < leftSeekEnd) {
          _seekBackward();
        } else if (position.dx > rightSeekStart) {
          _seekForward();
        }
      }

      _tapCount = 0;
      _lastTapPosition = null;
    }
  }

  void _handleCenterDoubleTap() {
    if (_videoController.value.isInitialized) {
      if (_videoController.value.isPlaying) {
        _videoController.pause();
        _showOverlay('⏸️ Paused');
      } else {
        _videoController.play();
        _showOverlay('▶️ Playing');
      }
    }
  }

  void _seekForward() {
    if (_videoController.value.isInitialized) {
      final currentPosition = _videoController.value.position;
      final newPosition = currentPosition + Duration(seconds: 5);
      final maxPosition = _videoController.value.duration;

      if (newPosition < maxPosition) {
        _videoController.seekTo(newPosition);
        _showOverlay('⏩ +5s');
      }
    }
  }

  void _seekBackward() {
    if (_videoController.value.isInitialized) {
      final currentPosition = _videoController.value.position;
      final newPosition = currentPosition - Duration(seconds: 5);

      if (newPosition > Duration.zero) {
        _videoController.seekTo(newPosition);
        _showOverlay('⏪ -5s');
      } else {
        _videoController.seekTo(Duration.zero);
        _showOverlay('⏪ -5s');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          _buildBody(),
          if (_overlayText != null) _buildControlsOverlay(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_error != null) {
      return _buildErrorScreen();
    }

    if (_chewieController != null) {
      return Stack(
        children: [
          // Video player with gestures
          if (!_isControlsLocked)
            GestureDetector(
              onScaleStart: _handleScaleStart,
              onScaleUpdate: _handleScaleUpdate,
              onScaleEnd: _handleScaleEnd,
              onTapDown: _handleTap,
              child: _buildVideoPlayer(),
            )
          else
            _buildVideoPlayer(),

          // Side gesture areas (brightness/volume only)
          _buildGestureControls(),

          // UI Controls - Back button (always show when controls visible)
          _buildBackButton(),

          // Subtitle controls (always show, even when locked)
          _buildSubtitleControls(),

          // Subtitle display
          _buildSubtitleDisplay(),

          // Episode selector
          _buildEpisodeSelector(),

          // Auto-next overlay
          _buildAutoNextOverlay(),

          // Lock button
          _buildLockButton(),

          // Subtitle source selector - MOVED AFTER lock button to be on top
          if (_showSubtitleSourceSelector && !_isControlsLocked)
            _buildSubtitleSourceSelector(),

          // Locked tap feedback - at the very top
          if (_isControlsLocked)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  _showOverlay('🔒 Controls are locked');
                },
                child: Container(color: Colors.transparent),
              ),
            ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildVideoPlayer() {
    return Transform.scale(
      scale: _currentScale,
      alignment: Alignment.center,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          child: Chewie(controller: _chewieController!),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      color: const Color(0xFF000000),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 150,
              height: 150,
              child: Lottie.asset(
                'assets/animations/loading.json', // Add your Lottie file here
                width: 150,
                height: 150,
                fit: BoxFit.contain,
                repeat: true,
                animate: true,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to CircularProgressIndicator if Lottie fails
                  return CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF6366F1),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Buffering...',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                widget.movieTitle,
                style: GoogleFonts.inter(
                  color: Colors.grey[400],
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Container(
      color: const Color(0xFF000000),
      padding: const EdgeInsets.all(24),
      child: Center(
        // Fixed: Properly centered now
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFEF4444),
              size: 64,
            ),
            const SizedBox(height: 32),
            Text(
              'Playback Error',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[900]?.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _error!,
                style: GoogleFonts.inter(
                  color: Colors.grey[300],
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                _videoController.dispose();
                _chewieController?.dispose();
                _initializePlayer();
              },
              icon: Icon(Icons.refresh_rounded),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _applySubtitleSources() async {
    print('🔄 _applySubtitleSources called');

    // Show loading indicator
    _showOverlay('🔄 Loading subtitles...');

    try {
      print('🎬 isTvShow: ${widget.isTvShow}');
      print('🎬 tmdbId: ${widget.tmdbId}');

      // For movies: Use primary source (Subtitle API) first, then fallback to secondary (movie page via API)
      if (!widget.isTvShow) {
        print('📽️ Loading movie subtitles with fallback...');
        await _loadMovieSubtitlesWithFallback();
      } else {
        // For TV shows: Use the existing logic (page source via API)
        print('📺 Loading TV subtitles...');
        await _loadTVSubtitles();
      }

      _hideSubtitleSourceSelector();
      _showOverlay('✅ Subtitles loaded');
    } catch (e) {
      print('❌ Error in _applySubtitleSources: $e');
      print('Stack trace: ${StackTrace.current}');
      _showOverlay('❌ Failed to load subtitles');
    }
  }

  // Update _loadMovieSubtitlesWithFallback with more logging:
  Future<void> _loadMovieSubtitlesWithFallback() async {
    print('🎯 _loadMovieSubtitlesWithFallback called');

    if (widget.tmdbId == null) {
      print('❌ No TMDB ID available');
      _showOverlay('❌ No TMDB ID available');
      return;
    }

    print('🔍 Fetching from Primary API for TMDB ID: ${widget.tmdbId}');

    // Try primary source (Subtitle API) first
    final primarySubtitles = await _fetchSubtitlesFromAPI(widget.tmdbId!);

    print('📊 Primary API returned ${primarySubtitles.length} subtitles');

    if (primarySubtitles.isNotEmpty) {
      print('✅ Loaded ${primarySubtitles.length} subtitles from API (Primary)');
      print('📎 First subtitle URL: ${primarySubtitles.first}');
      await _loadSubtitleTrack(primarySubtitles.first);
      return;
    }

    // If primary fails, try secondary source (movie page subtitles via API)
    print('⚠️ Primary source failed, trying secondary source...');
    final secondarySubtitles = await _fetchMoviePageSubtitles(widget.tmdbId!);

    print(
      '📊 Secondary source returned ${secondarySubtitles.length} subtitles',
    );

    if (secondarySubtitles.isNotEmpty) {
      print(
        '✅ Loaded ${secondarySubtitles.length} subtitles from movie page (Secondary)',
      );
      print('📎 First subtitle URL: ${secondarySubtitles.first}');
      await _loadSubtitleTrack(secondarySubtitles.first);
    } else {
      print('⚠️ No subtitles found from any source');
      _showOverlay('⚠️ No subtitles found from any source');
    }
  }

  Future<List<String>> _fetchMoviePageSubtitles(int tmdbId) async {
    print('🎬 _fetchMoviePageSubtitles called for TMDB ID: $tmdbId');

    try {
      print('🌐 Using M3U8 API to fetch movie page subtitles...');

      // Use the search API to get subtitles from the movie page
      final result = await _m3u8.searchMovieByTmdbId(
        tmdbId: tmdbId,
        fetchSubs: true,
        onStatusUpdate: (status) {
          print('📊 Secondary source status: $status');
        },
      );

      print('📦 API result keys: ${result.keys.toList()}');
      print('📦 Subtitles field type: ${result['subtitles'].runtimeType}');

      final subtitles =
          (result['subtitles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((url) => url.startsWith('http'))
              .toList() ??
          [];

      print('🎯 Secondary source found ${subtitles.length} subtitle URLs');

      if (subtitles.isNotEmpty) {
        print('📎 Sample URLs:');
        for (var i = 0; i < subtitles.length && i < 3; i++) {
          print('  $i: ${subtitles[i]}');
        }
      }

      // Filter for English subtitles
      print('🔍 Filtering secondary source subtitles for English...');
      final englishSubtitles = await _filterEnglishSubtitles(subtitles);
      print(
        '✅ Secondary source: ${englishSubtitles.length} English subtitles after filtering',
      );

      return englishSubtitles;
    } catch (e) {
      print('❌ Error fetching from movie page via API: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Update _fetchSubtitlesFromAPI with more detailed logging:
  Future<List<String>> _fetchSubtitlesFromAPI(int tmdbId) async {
    try {
      final apiUrl = 'https://nigzie.ru/subs/movie/$tmdbId';
      print('🌐 Fetching subtitles from Primary API: $apiUrl');

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'application/json',
        },
      );

      print('📡 API Response Status: ${response.statusCode}');
      print(
        '📄 API Response Body (first 500 chars): ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🔍 Decoded JSON type: ${data.runtimeType}');

        final subtitleUrls = _extractSubtitleUrlsFromAPI(data);
        print('📋 Extracted ${subtitleUrls.length} subtitle URLs');

        if (subtitleUrls.isNotEmpty) {
          print('📎 First URL: ${subtitleUrls.first}');
        }

        // Filter for English subtitles
        print('🔍 Filtering for English subtitles...');
        final englishSubtitles = await _filterEnglishSubtitles(subtitleUrls);
        print('✅ Found ${englishSubtitles.length} English subtitles');

        return englishSubtitles;
      } else {
        print('❌ Primary API returned status: ${response.statusCode}');
        print('❌ Response body: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching from Primary API: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Update _extractSubtitleUrlsFromAPI with better logging:
  List<String> _extractSubtitleUrlsFromAPI(dynamic data) {
    final List<String> subtitleUrls = [];

    try {
      print('🔍 Extracting URLs from data type: ${data.runtimeType}');

      if (data is List) {
        print('📋 Data is a List with ${data.length} items');
        for (var i = 0; i < data.length; i++) {
          var item = data[i];
          print('  Item $i type: ${item.runtimeType}');

          if (item is Map) {
            print('  Item $i keys: ${item.keys.toList()}');
            // Try common subtitle URL fields
            final possibleFields = [
              'url',
              'file',
              'subtitle_url',
              'download_url',
              'link',
            ];
            for (var field in possibleFields) {
              if (item[field] is String && item[field].startsWith('http')) {
                print('  ✅ Found URL in field "$field": ${item[field]}');
                subtitleUrls.add(item[field]);
                break;
              }
            }
          } else if (item is String && item.startsWith('http')) {
            print('  ✅ Found URL string: $item');
            subtitleUrls.add(item);
          }
        }
      } else if (data is Map) {
        print('📋 Data is a Map with keys: ${data.keys.toList()}');
        data.forEach((key, value) {
          print('  Key: $key, Value type: ${value.runtimeType}');
          if (value is String &&
              value.startsWith('http') &&
              value.toLowerCase().contains('.vtt')) {
            print('  ✅ Found VTT URL in key "$key": $value');
            subtitleUrls.add(value);
          }
        });
      } else {
        print('⚠️ Unexpected data type: ${data.runtimeType}');
      }
    } catch (e) {
      print('❌ Error parsing API response: $e');
      print('Stack trace: ${StackTrace.current}');
    }

    print('📄 Extracted ${subtitleUrls.length} subtitle URLs from API');
    return subtitleUrls;
  }

  // Update _filterEnglishSubtitles with logging:
  Future<List<String>> _filterEnglishSubtitles(
    List<String> subtitleUrls,
  ) async {
    print('🔍 Filtering ${subtitleUrls.length} subtitle URLs for English...');
    final List<String> englishSubtitles = [];

    for (var i = 0; i < subtitleUrls.length; i++) {
      final url = subtitleUrls[i];
      print('  Checking subtitle ${i + 1}/${subtitleUrls.length}: $url');

      try {
        final language = await _detectSubtitleLanguage(url);
        print('  Detected language: $language');

        if (_isEnglishSubtitle(language, url)) {
          print('  ✅ English subtitle found!');
          englishSubtitles.add(url);
        } else {
          print('  ❌ Not English, skipping');
        }
      } catch (e) {
        print('  ⚠️ Error filtering subtitle $url: $e');
      }
    }

    print('✅ Filtered to ${englishSubtitles.length} English subtitles');
    return englishSubtitles;
  }

  Future<void> _loadTVSubtitles() async {
    print('📺 _loadTVSubtitles called');
    print('📺 TMDB ID: ${widget.tmdbId}');
    print('📺 Season: ${widget.seasonNumber}');
    print('📺 Episode: ${widget.currentEpisode}');
    print('📺 Title: ${widget.movieTitle}');

    // TV shows use the API to get subtitles from fullhdmovies.me
    if (widget.tmdbId != null &&
        widget.seasonNumber != null &&
        widget.currentEpisode != null) {
      try {
        print('🌐 Fetching TV subtitles from API...');

        final subtitles = await _m3u8.fetchTvSubtitles(
          tmdbId: widget.tmdbId!,
          seasonNumber: widget.seasonNumber!,
          episodeNumber: widget.currentEpisode!,
          showTitle: widget.movieTitle,
        );

        print('📊 API returned ${subtitles.length} TV subtitle URLs');

        if (subtitles.isNotEmpty) {
          print('📎 Sample TV subtitle URLs:');
          for (var i = 0; i < subtitles.length && i < 3; i++) {
            print('  $i: ${subtitles[i]}');
          }

          print('🔍 Filtering TV subtitles for English...');
          final englishSubtitles = await _filterEnglishSubtitles(subtitles);

          print('✅ Found ${englishSubtitles.length} English TV subtitles');

          if (englishSubtitles.isNotEmpty) {
            print(
              '📎 Loading first English TV subtitle: ${englishSubtitles.first}',
            );
            await _loadSubtitleTrack(englishSubtitles.first);
          } else {
            print('⚠️ No English subtitles found for TV show');
            _showOverlay('⚠️ No English subtitles found for TV show');
          }
        } else {
          print('⚠️ API returned no subtitles for TV show');
          _showOverlay('⚠️ No subtitles found for TV show');
        }
      } catch (e) {
        print('❌ Error loading TV subtitles: $e');
        print('Stack trace: ${StackTrace.current}');
        _showOverlay('❌ Failed to load TV subtitles');
      }
    } else {
      print('⚠️ Missing required parameters for TV subtitle fetch');
      print('  - tmdbId: ${widget.tmdbId}');
      print('  - seasonNumber: ${widget.seasonNumber}');
      print('  - currentEpisode: ${widget.currentEpisode}');
      _showOverlay('❌ Missing TV show information');
    }
  }

  // Update the source option widget to show API endpoints
  Widget _buildSourceOption({
    required String title,
    required String subtitle,
    required String value,
    required bool isSelected,
  }) {
    String sourceDescription = '';

    if (value == 'api') {
      sourceDescription = 'nigzie.ru/subs/movie (Fastest)';
    } else if (value == 'page') {
      sourceDescription = 'Movie Page → API (Fallback)';
    }

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected
            ? Color(0xFF6366F1).withOpacity(0.2)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? Color(0xFF6366F1).withOpacity(0.5)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? Color(0xFF6366F1)
                    : Colors.white.withOpacity(0.3),
                width: 2,
              ),
              color: isSelected ? Color(0xFF6366F1) : Colors.transparent,
            ),
            child: isSelected
                ? Icon(Icons.check, size: 12, color: Colors.white)
                : SizedBox.shrink(),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  sourceDescription,
                  style: GoogleFonts.inter(
                    color: isSelected
                        ? Color(0xFF6366F1)
                        : Colors.white.withOpacity(0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Update the selector widget title and description
  Widget _buildSubtitleSourceSelector() {
    // Don't show when controls are locked
    if (_isControlsLocked ||
        !_videoController.value.isInitialized ||
        !_showSubtitleSourceSelector) {
      return SizedBox.shrink();
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 280,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Color(0xFF6366F1).withOpacity(0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.7),
                blurRadius: 20,
                spreadRadius: 5,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Subtitle Sources',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Choose your preferred source',
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _showSubtitleSourceSelector = false;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _buildSourceOption(
                title: 'Primary Source',
                subtitle: 'Direct Subtitle API',
                value: 'api',
                isSelected: true,
              ),
              SizedBox(height: 12),
              _buildSourceOption(
                title: 'Secondary Source',
                subtitle: 'Movie Page Extraction',
                value: 'page',
                isSelected: false,
              ),
              SizedBox(height: 16),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    print('Apply button tapped!');
                    _applySubtitleSources();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Apply Sources',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Primary will be tried first, then Secondary as fallback',
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Update _hideSubtitleSourceSelector method:
  void _hideSubtitleSourceSelector() {
    setState(() {
      _showSubtitleSourceSelector = false;
    });
  }

  double _calculateOptimalZoom() {
    if (!_videoController.value.isInitialized)
      return 1.0; // Changed default to 1.0

    final screenSize = MediaQuery.of(context).size;
    final videoSize = _videoController.value.size;

    if (videoSize.width == 0 || videoSize.height == 0) return 1.0;

    final scaleX = screenSize.width / videoSize.width;
    final scaleY = screenSize.height / videoSize.height;
    final optimalScale = math.min(scaleX, scaleY);

    return optimalScale.clamp(0.5, 2.0);
  }

  void _resetToPortraitMode() async {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Restore system UI based on immersive mode preference
    final prefs = await SharedPreferences.getInstance();
    final immersiveMode = prefs.getBool('immersive_mode') ?? false;

    if (immersiveMode) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive, overlays: []);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  void dispose() {
    if (_videoController.value.isInitialized) {
      _savePosition(_videoController.value.position);
    }

    _releaseAudioBoost();
    FlutterVolumeController.updateShowSystemUI(true);

    _videoController.removeListener(_onPositionChanged);
    _videoController.dispose();
    _chewieController?.dispose();
    _fadeController.dispose();
    _overlayController.dispose();
    _overlayTimer?.cancel();
    _subtitleTimer?.cancel();
    _controlsTimer?.cancel();
    _autoNextTimer?.cancel();
    _doubleTapTimer?.cancel();

    // Clear prefetch data
    _prefetchedStreamUrl = null;
    _prefetchedSubtitles = null;
    _nextEpisodeReady = false;
    _isLoadingNextEpisode = false;

    _resetToPortraitMode();
    super.dispose();
  }
}
