import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class UpdateCheckerWrapper extends StatefulWidget {
  final Widget child;
  final String githubRepo; // e.g., "golanpiyush/SOYO"

  const UpdateCheckerWrapper({
    Key? key,
    required this.child,
    required this.githubRepo,
  }) : super(key: key);

  @override
  _UpdateCheckerWrapperState createState() => _UpdateCheckerWrapperState();
}

class _UpdateCheckerWrapperState extends State<UpdateCheckerWrapper>
    with TickerProviderStateMixin {
  bool _checked = false;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _shimmerController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shimmerAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _checkForUpdate() async {
    if (_checked) return;
    _checked = true;

    try {
      debugPrint("🔍 Starting update check...");

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final appName = packageInfo.appName;
      debugPrint("📱 Current version: $currentVersion");

      final url =
          'https://api.github.com/repos/${widget.githubRepo}/releases/latest';
      debugPrint("🌐 Checking URL: $url");

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/vnd.github.v3+json',
              'User-Agent': '$appName-Update-Checker',
            },
          )
          .timeout(Duration(seconds: 10));

      debugPrint("📡 Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final latestVersion = data['tag_name'] ?? '';
        final releaseTitle = data['name'] ?? '';
        final releaseNotes = data['body'] ?? '';
        final releaseDate = data['published_at'] ?? '';
        final downloadUrl = data['html_url'] ?? '';
        final assets = data['assets'] ?? [];

        debugPrint("🚀 Latest version: $latestVersion");

        if (_isNewerVersion(currentVersion, latestVersion)) {
          debugPrint("✨ Update available: $currentVersion -> $latestVersion");
          _showBeautifulUpdateDialog(
            appName: appName,
            releaseTitle: releaseTitle,
            fromVersion: currentVersion,
            toVersion: latestVersion,
            releaseNotes: releaseNotes,
            releaseDate: releaseDate,
            downloadUrl: downloadUrl,
            assets: assets,
          );
        } else {
          debugPrint("✅ App is up to date");
        }
      } else {
        debugPrint("❌ GitHub API error: ${response.statusCode}");
      }
    } catch (e, stackTrace) {
      debugPrint("💥 Update check failed: $e");
      debugPrint("Stack trace: $stackTrace");
    }
  }

  bool _isNewerVersion(String current, String latest) {
    try {
      String cleanCurrent = current.replaceAll(RegExp(r'^v'), '');
      String cleanLatest = latest.replaceAll(RegExp(r'^v'), '');

      final currentParts = cleanCurrent.split('.').map(int.parse).toList();
      final latestParts = cleanLatest.split('.').map(int.parse).toList();

      final maxLength = math.max(currentParts.length, latestParts.length);

      while (currentParts.length < maxLength) currentParts.add(0);
      while (latestParts.length < maxLength) latestParts.add(0);

      for (int i = 0; i < maxLength; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (e) {
      debugPrint("⚠️ Version comparison error: $e");
      return false;
    }
  }

  void _showBeautifulUpdateDialog({
    required String appName,
    required String releaseTitle,
    required String fromVersion,
    required String toVersion,
    required String releaseNotes,
    required String releaseDate,
    required String downloadUrl,
    required List assets,
  }) {
    HapticFeedback.lightImpact();

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black87,
      transitionDuration: Duration(milliseconds: 400),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: Offset(0.0, -1.0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.elasticOut),
              ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.elasticOut),
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Container(
            margin: EdgeInsets.all(20),
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1a1a2e),
                  Color(0xFF16213e),
                  Color(0xFF0f3460),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: _UpdateDialogContent(
                appName: appName,
                releaseTitle: releaseTitle,
                fromVersion: fromVersion,
                toVersion: toVersion,
                releaseNotes: releaseNotes,
                releaseDate: releaseDate,
                downloadUrl: downloadUrl,
                assets: assets,
                pulseAnimation: _pulseAnimation,
                shimmerAnimation: _shimmerAnimation,
                onUpdate: () => _launchURL(downloadUrl),
                onLater: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchURL(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        HapticFeedback.selectionClick();
      } else {
        debugPrint("❌ Could not launch URL: $url");
      }
    } catch (e) {
      debugPrint("💥 Error launching URL: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _UpdateDialogContent extends StatefulWidget {
  final String appName;
  final String releaseTitle;
  final String fromVersion;
  final String toVersion;
  final String releaseNotes;
  final String releaseDate;
  final String downloadUrl;
  final List assets;
  final Animation<double> pulseAnimation;
  final Animation<double> shimmerAnimation;
  final VoidCallback onUpdate;
  final VoidCallback onLater;

  const _UpdateDialogContent({
    required this.appName,
    required this.releaseTitle,
    required this.fromVersion,
    required this.toVersion,
    required this.releaseNotes,
    required this.releaseDate,
    required this.downloadUrl,
    required this.assets,
    required this.pulseAnimation,
    required this.shimmerAnimation,
    required this.onUpdate,
    required this.onLater,
  });

  @override
  _UpdateDialogContentState createState() => _UpdateDialogContentState();
}

class _UpdateDialogContentState extends State<_UpdateDialogContent>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _showReleaseNotes = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today at ${DateFormat.jm().format(date)}';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return DateFormat.yMMMMd().format(date);
      }
    } catch (e) {
      return 'Recently';
    }
  }

  String _getInstallSize() {
    if (widget.assets.isNotEmpty) {
      final apkAsset = widget.assets.firstWhere(
        (asset) =>
            asset['name']?.toString().toLowerCase().contains('.apk') == true,
        orElse: () => null,
      );
      if (apkAsset != null) {
        final size = apkAsset['size'] ?? 0;
        return _formatBytes(size);
      }
    }
    return 'Unknown size';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (math.log(bytes) / math.log(1024)).floor();
    return '${(bytes / math.pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with icon and title
            _buildHeader(),
            SizedBox(height: 20),

            // Version info cards
            _buildVersionCards(),
            SizedBox(height: 20),

            // Release info
            _buildReleaseInfo(),
            SizedBox(height: 20),

            // Release notes toggle
            if (widget.releaseNotes.isNotEmpty) _buildReleaseNotesSection(),

            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        AnimatedBuilder(
          animation: widget.pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: widget.pulseAnimation.value,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFE85D75)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFFF6B6B).withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.system_update_alt,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            );
          },
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Update Available!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.appName,
                style: TextStyle(color: Colors.white60, fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVersionCards() {
    return Row(
      children: [
        Expanded(
          child: _buildVersionCard(
            'Current',
            widget.fromVersion,
            Color(0xFF4ECDC4),
          ),
        ),
        SizedBox(width: 16),
        Icon(Icons.arrow_forward, color: Colors.white60),
        SizedBox(width: 16),
        Expanded(
          child: _buildVersionCard(
            'Latest',
            widget.toVersion,
            Color(0xFFFF6B6B),
          ),
        ),
      ],
    );
  }

  Widget _buildVersionCard(String label, String version, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            version,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReleaseInfo() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          if (widget.releaseTitle.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.new_releases, color: Color(0xFFFF6B6B), size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.releaseTitle,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
          ],
          Row(
            children: [
              Icon(Icons.schedule, color: Colors.white60, size: 18),
              SizedBox(width: 8),
              Text(
                _formatDate(widget.releaseDate),
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.download, color: Colors.white60, size: 18),
              SizedBox(width: 8),
              Text(
                _getInstallSize(),
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReleaseNotesSection() {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _showReleaseNotes = !_showReleaseNotes;
            });
            HapticFeedback.selectionClick();
          },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.article, color: Color(0xFF4ECDC4), size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Release Notes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _showReleaseNotes ? 0.5 : 0,
                  duration: Duration(milliseconds: 300),
                  child: Icon(Icons.keyboard_arrow_down, color: Colors.white60),
                ),
              ],
            ),
          ),
        ),
        AnimatedContainer(
          duration: Duration(milliseconds: 300),
          height: _showReleaseNotes ? null : 0,
          child: _showReleaseNotes
              ? Container(
                  margin: EdgeInsets.only(top: 12),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  constraints: BoxConstraints(maxHeight: 200),
                  child: Markdown(
                    data: widget.releaseNotes,
                    shrinkWrap: true,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(color: Colors.white70, fontSize: 14),
                      h1: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      h2: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      h3: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      strong: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      em: TextStyle(
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                      ),
                      code: TextStyle(
                        color: Color(0xFF4ECDC4),
                        backgroundColor: Colors.white.withOpacity(0.1),
                        fontFamily: 'monospace',
                      ),
                      listBullet: TextStyle(color: Color(0xFFFF6B6B)),
                    ),
                  ),
                )
              : SizedBox.shrink(),
        ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Main update button with enhanced animation
        Container(
          width: double.infinity,
          height: 56,
          child: AnimatedBuilder(
            animation: widget.shimmerAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFF6B6B),
                      Color(0xFFE85D75),
                      Color(0xFFFF6B6B),
                      Color(0xFFFF8E53),
                    ],
                    stops: [
                      math.max(0.0, widget.shimmerAnimation.value - 0.3),
                      widget.shimmerAnimation.value,
                      math.min(1.0, widget.shimmerAnimation.value + 0.3),
                      1.0,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFFF6B6B).withOpacity(0.5),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    widget.onUpdate();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.download_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Update SOYO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('🚀', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 12),
        // Secondary actions row
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  widget.onLater();
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      color: Colors.white60,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Remind Later',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _launchURL(
                    'https://github.com/${widget.downloadUrl.split('/').take(5).join('/')}/releases',
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Color(0xFF4ECDC4).withOpacity(0.3)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      color: Color(0xFF4ECDC4),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'All Releases',
                      style: TextStyle(
                        color: Color(0xFF4ECDC4),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _launchURL(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        HapticFeedback.selectionClick();
      } else {
        debugPrint("❌ Could not launch URL: $url");
      }
    } catch (e) {
      debugPrint("💥 Error launching URL: $e");
    }
  }
}
