import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  bool _nsfwEnabled = false;
  bool _autoFetchSubtitles = true;
  bool _autoPlay = true;
  String _defaultQuality = 'Adaptive';
  bool _resumeFromLastPosition = false;

  // Getters
  bool get nsfwEnabled => _nsfwEnabled;
  bool get autoFetchSubtitles => _autoFetchSubtitles;
  bool get autoPlay => _autoPlay;
  String get defaultQuality => _defaultQuality;
  bool get resumeFromLastPosition => _resumeFromLastPosition;

  // Initialize and load all settings
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _nsfwEnabled = prefs.getBool('nsfw_enabled') ?? false;
    _autoFetchSubtitles = prefs.getBool('auto_fetch_subtitles') ?? true;
    _autoPlay = prefs.getBool('auto_play') ?? true;
    _defaultQuality = prefs.getString('default_quality') ?? 'Adaptive';
    _resumeFromLastPosition =
        prefs.getBool('resume_from_last_position') ?? false;
    notifyListeners();
  }

  // Set NSFW enabled
  Future<void> setNsfwEnabled(bool value) async {
    _nsfwEnabled = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('nsfw_enabled', value);
  }

  // Set auto fetch subtitles
  Future<void> setAutoFetchSubtitles(bool value) async {
    _autoFetchSubtitles = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_fetch_subtitles', value);
  }

  // Set auto play
  Future<void> setAutoPlay(bool value) async {
    _autoPlay = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_play', value);
  }

  // Set default quality
  Future<void> setDefaultQuality(String value) async {
    _defaultQuality = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_quality', value);
  }

  // Set resume from last position
  Future<void> setResumeFromLastPosition(bool value) async {
    _resumeFromLastPosition = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('resume_from_last_position', value);
  }
}
