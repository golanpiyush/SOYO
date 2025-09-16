import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soyo/Services/m3u8api.dart';
import 'package:soyo/Services/streams_cacher.dart';
import 'savedscreen.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoFetchSubtitles = true;
  String _defaultQuality = '1080';
  bool _darkTheme = true;
  bool _autoPlay = false;
  final M3U8Api _api = M3U8Api();
  bool _isTestingConnection = false;
  bool? _connectionStatus;
  bool _isClearingCache = false;
  String _cacheInfo = '';
  // Subtitle customization settings
  Color _subtitleBackgroundColor = Colors.black.withOpacity(0.7);
  Color _subtitleTextColor = Colors.yellow;
  double _subtitleFontSize = 16.0;
  String _subtitleFontFamily = 'Cinzel';
  bool _subtitleOutline = true;
  double _subtitleSpeed = 1.0;

  // Cinematic fonts list
  final List<String> _cinematicFonts = [
    'Cinzel',
    'Playfair Display',
    'Cormorant Garamond',
    'Crimson Text',
    'EB Garamond',
    'Libre Baskerville',
    'Merriweather',
    'Lora',
    'Caveat',
    'Vollkorn',
    'Spectral',
    'Old Standard TT',
  ];

  @override
  void initState() {
    super.initState();
    _loadSubtitleSettings();
    _getCacheInfo();
  }

  Future<void> _getCacheInfo() async {
    try {
      final cacheInfo = await StreamCacheService.getCacheInfo();
      final movieCount = cacheInfo.length;

      // Get TV show cache count
      final prefs = await SharedPreferences.getInstance();
      final tvShowKeys = prefs.getKeys().where(
        (key) => key.startsWith('tv_show_cache_'),
      );
      final tvShowCount = tvShowKeys.length;

      setState(() {
        _cacheInfo =
            'Movies: $movieCount cached\nTV Shows: $tvShowCount episodes cached';
      });
    } catch (e) {
      setState(() {
        _cacheInfo = 'Unable to load cache info';
      });
    }
  }

  Future<void> _clearAllCache() async {
    setState(() {
      _isClearingCache = true;
    });

    try {
      await StreamCacheService.clearAllCache();
      await _getCacheInfo();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All cache cleared successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear cache: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isClearingCache = false;
      });
    }
  }

  Future<void> _clearExpiredCache() async {
    setState(() {
      _isClearingCache = true;
    });

    try {
      await StreamCacheService.clearExpiredCache();
      await _getCacheInfo();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Expired cache cleared successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear expired cache: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isClearingCache = false;
      });
    }
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

  Future<void> _saveSubtitleSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('subtitle_bg_color', _subtitleBackgroundColor.value);
    await prefs.setInt('subtitle_text_color', _subtitleTextColor.value);
    await prefs.setDouble('subtitle_font_size', _subtitleFontSize);
    await prefs.setString('subtitle_font_family', _subtitleFontFamily);
    await prefs.setBool('subtitle_outline', _subtitleOutline);
    await prefs.setDouble('subtitle_speed', _subtitleSpeed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStreamingSection(),
            SizedBox(height: 20),
            _buildSubtitleEditorSection(),
            SizedBox(height: 20),
            _buildCacheSection(),
            SizedBox(height: 20),
            _buildAboutSection(),
            SizedBox(height: 20),
            _buildDisclaimerSection(),
            SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storage, color: Colors.orange),
              SizedBox(width: 12),
              Text(
                'Cache Management',
                style: GoogleFonts.cabin(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Cache Info
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white70, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Cache Information',
                      style: GoogleFonts.cabin(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  _cacheInfo.isNotEmpty ? _cacheInfo : 'Loading cache info...',
                  style: GoogleFonts.cabin(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 15),

          // Clear Expired Cache Button
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isClearingCache ? null : _clearExpiredCache,
                  icon: _isClearingCache
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Icons.auto_delete, size: 18),
                  label: Text(
                    'Clear Expired Cache',
                    style: GoogleFonts.cabin(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.withOpacity(0.8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 10),

          // Clear All Cache Button
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isClearingCache
                      ? null
                      : () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Colors.grey[900],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              title: Row(
                                children: [
                                  Icon(Icons.warning, color: Colors.orange),
                                  SizedBox(width: 10),
                                  Text(
                                    'Clear All Cache',
                                    style: GoogleFonts.cabin(
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              content: Text(
                                'This will clear all cached streams for movies and TV shows. You may need to wait longer for streams to load after clearing.',
                                style: GoogleFonts.cabin(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'Cancel',
                                    style: GoogleFonts.cabin(
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _clearAllCache();
                                  },
                                  child: Text(
                                    'Clear All',
                                    style: GoogleFonts.cabin(
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                  icon: _isClearingCache
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Icons.clear_all, size: 18),
                  label: Text(
                    'Clear All Cache',
                    style: GoogleFonts.cabin(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.withOpacity(0.8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitleEditorSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.subtitles, color: Colors.yellow),
              SizedBox(width: 12),
              Text(
                'Subtitle Editor',
                style: GoogleFonts.cabin(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Preview Container
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[700]!),
            ),
            child: Column(
              children: [
                Text(
                  'Preview',
                  style: GoogleFonts.cabin(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _subtitleBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: _subtitleOutline
                        ? Border.all(color: Colors.black, width: 1)
                        : null,
                  ),
                  child: Text(
                    'Sample subtitle text for preview',
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
              ],
            ),
          ),

          SizedBox(height: 20),

          // Text Color Picker
          _buildColorPickerSetting('Text Color', _subtitleTextColor, (color) {
            setState(() => _subtitleTextColor = color);
            _saveSubtitleSettings();
          }, Icons.format_color_text),

          SizedBox(height: 15),

          // Background Color Picker
          _buildColorPickerSetting(
            'Background Color',
            _subtitleBackgroundColor,
            (color) {
              setState(() => _subtitleBackgroundColor = color);
              _saveSubtitleSettings();
            },
            Icons.format_color_fill,
          ),

          SizedBox(height: 15),

          // Font Family Dropdown
          _buildFontFamilyDropdown(),

          SizedBox(height: 15),

          // Font Size Slider
          _buildSliderSetting(
            'Font Size',
            _subtitleFontSize,
            12.0,
            24.0,
            (value) {
              setState(() => _subtitleFontSize = value);
              _saveSubtitleSettings();
            },
            Icons.text_fields,
            '${_subtitleFontSize.round()}px',
          ),

          SizedBox(height: 15),

          // Subtitle Speed Slider
          _buildSliderSetting(
            'Subtitle Speed',
            _subtitleSpeed,
            0.5,
            2.0,
            (value) {
              setState(() => _subtitleSpeed = value);
              _saveSubtitleSettings();
            },
            Icons.speed,
            '${_subtitleSpeed.toStringAsFixed(1)}x',
          ),

          SizedBox(height: 15),

          // Outline Toggle
          _buildSwitchSetting(
            'Text Outline',
            'Add black outline to subtitle text',
            _subtitleOutline,
            (value) {
              setState(() => _subtitleOutline = value);
              _saveSubtitleSettings();
            },
            Icons.border_style,
          ),

          SizedBox(height: 20),

          // Reset Button
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _resetSubtitleSettings,
                  icon: Icon(Icons.restore, size: 18),
                  label: Text(
                    'Reset to Defaults',
                    style: GoogleFonts.cabin(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorPickerSetting(
    String title,
    Color currentColor,
    Function(Color) onChanged,
    IconData icon,
  ) {
    final List<Color> predefinedColors = [
      Colors.yellow,
      Colors.white,
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.cyan,
      Colors.lime,
      Colors.black.withOpacity(0.7),
      Colors.grey.withOpacity(0.8),
      Colors.transparent, // Add transparent option
    ];

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 20),
              SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.cabin(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: predefinedColors.map((color) {
              final isSelected = color.value == currentColor.value;
              final isTransparent = color == Colors.transparent;

              return GestureDetector(
                onTap: () => onChanged(color),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isTransparent ? Colors.white : color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.grey[600]!,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: isTransparent
                      ? Stack(
                          children: [
                            // Diagonal line to represent transparency
                            CustomPaint(
                              size: Size(32, 32),
                              painter: DiagonalLinePainter(),
                            ),
                            if (isSelected)
                              Center(
                                child: Icon(
                                  Icons.check,
                                  color: Colors.red,
                                  size: 16,
                                ),
                              ),
                          ],
                        )
                      : isSelected
                      ? Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFontFamilyDropdown() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.font_download, color: Colors.white70, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Font Family',
              style: GoogleFonts.cabin(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          DropdownButton<String>(
            value: _subtitleFontFamily,
            dropdownColor: Colors.grey[800],
            style: GoogleFonts.cabin(color: Colors.white),
            underline: Container(),
            items: _cinematicFonts.map((String font) {
              return DropdownMenuItem<String>(
                value: font,
                child: Text(
                  font,
                  style: GoogleFonts.getFont(
                    font,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _subtitleFontFamily = value);
                _saveSubtitleSettings();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSliderSetting(
    String title,
    double value,
    double min,
    double max,
    Function(double) onChanged,
    IconData icon,
    String valueText,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.cabin(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                valueText,
                style: GoogleFonts.cabin(
                  color: Colors.yellow,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.yellow,
              inactiveTrackColor: Colors.grey[700],
              thumbColor: Colors.yellow,
              overlayColor: Colors.yellow.withOpacity(0.2),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: title.contains('Size') ? 12 : 15,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  void _resetSubtitleSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.restore, color: Colors.yellow),
            SizedBox(width: 10),
            Text(
              'Reset Subtitle Settings',
              style: GoogleFonts.cabin(color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'This will reset all subtitle customization settings to their default values.',
          style: GoogleFonts.cabin(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.cabin(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              setState(() {
                _subtitleBackgroundColor = Colors.black.withOpacity(0.7);
                _subtitleTextColor = Colors.yellow;
                _subtitleFontSize = 16.0;
                _subtitleFontFamily = 'Cinzel';
                _subtitleOutline = true;
                _subtitleSpeed = 1.0;
              });
              await _saveSubtitleSettings();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Subtitle settings reset to defaults'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text(
              'Reset',
              style: GoogleFonts.cabin(color: Colors.yellow),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel, color: Colors.redAccent),
              SizedBox(width: 12),
              Text(
                'Disclaimer',
                style: GoogleFonts.cabin(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Text(
            'This app does not host or store any video files. It simply finds and aggregates content that is already publicly available on the internet.',
            style: GoogleFonts.cabin(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildStreamingSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.movie, color: Colors.red),
              SizedBox(width: 12),
              Text(
                'Streaming Settings',
                style: GoogleFonts.cabin(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Default Quality
          _buildDropdownSetting(
            'Default Quality',
            _defaultQuality,
            ['720', '1080', '4K'],
            (value) => setState(() => _defaultQuality = value!),
            Icons.hd,
          ),

          SizedBox(height: 15),

          // Auto fetch subtitles
          _buildSwitchSetting(
            'Auto Fetch Subtitles',
            'Automatically download subtitles when available',
            _autoFetchSubtitles,
            (value) => setState(() => _autoFetchSubtitles = value),
            Icons.subtitles,
          ),

          SizedBox(height: 15),

          // Auto play
          _buildSwitchSetting(
            'Auto Play',
            'Automatically open video player after finding stream',
            _autoPlay,
            (value) => setState(() => _autoPlay = value),
            Icons.play_arrow,
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: Colors.green),
              SizedBox(width: 12),
              Text(
                'About',
                style: GoogleFonts.cabin(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          _buildInfoRow('App Version', '2.2.0'),
          _buildInfoRow('Developer', 'Piyush Golan'),
          _buildInfoRow('API Version', 'v2.5'),

          SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showLicenses,
                  icon: Icon(Icons.description, size: 18),
                  label: Text(
                    'Licenses',
                    style: GoogleFonts.cabin(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.withOpacity(0.8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchSetting(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cabin(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.cabin(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: Colors.red),
        ],
      ),
    );
  }

  Widget _buildDropdownSetting(
    String title,
    String value,
    List<String> options,
    Function(String?) onChanged,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.cabin(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          DropdownButton<String>(
            value: value,
            dropdownColor: Colors.grey[800],
            style: GoogleFonts.cabin(color: Colors.white),
            underline: Container(),
            items: options.map((String option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(
                  option,
                  style: GoogleFonts.cabin(color: Colors.white),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.cabin(color: Colors.grey[400], fontSize: 14),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.cabin(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showLicenses() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          'Open Source Licenses',
          style: GoogleFonts.cabin(color: Colors.white),
        ),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: Text(
              '''Flutter SDK
Copyright 2014 The Flutter Authors. All rights reserved.

animated_bottom_navigation_bar
Copyright 2020 Pedromassango

http
Copyright 2014, the Dart project authors.

This app uses various open-source packages. All packages are subject to their respective licenses.''',
              style: GoogleFonts.cabin(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.cabin(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// Add this custom painter class for the transparent indicator
class DiagonalLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(4, 4),
      Offset(size.width - 4, size.height - 4),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
