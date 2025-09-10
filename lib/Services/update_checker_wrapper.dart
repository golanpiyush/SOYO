import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:intl/intl.dart';

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

class _UpdateCheckerWrapperState extends State<UpdateCheckerWrapper> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    if (_checked) return;
    _checked = true;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final url =
          'https://api.github.com/repos/${widget.githubRepo}/releases/latest';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final latestVersion = data['tag_name'] ?? '';
        final releaseTitle = data['name'] ?? '';
        final releaseNotes = data['body'] ?? '';
        final releaseDate = data['published_at'] ?? '';

        if (_isNewerVersion(currentVersion, latestVersion)) {
          _showUpdateDialog(
            releaseTitle: releaseTitle,
            fromVersion: currentVersion,
            toVersion: latestVersion,
            releaseNotes: releaseNotes,
            releaseDate: releaseDate,
          );
        }
      }
    } catch (e) {
      debugPrint("Update check failed: $e");
    }
  }

  bool _isNewerVersion(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest
          .replaceAll(RegExp(r'[^0-9.]'), '')
          .split('.')
          .map(int.parse)
          .toList();
      for (int i = 0; i < latestParts.length; i++) {
        if (i >= currentParts.length || latestParts[i] > currentParts[i]) {
          return true;
        } else if (latestParts[i] < currentParts[i]) {
          return false;
        }
      }
    } catch (_) {}
    return false;
  }

  void _showUpdateDialog({
    required String releaseTitle,
    required String fromVersion,
    required String toVersion,
    required String releaseNotes,
    required String releaseDate,
  }) {
    final formattedDate = DateFormat.yMMMMd().format(
      DateTime.parse(releaseDate),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Update Available',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                releaseTitle,
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Version: $fromVersion → $toVersion',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 8),
              Text(
                'Release Date: $formattedDate',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 12),
              Text(
                'Release Notes:',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(releaseNotes, style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Later', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              // Open GitHub release page
              _launchURL(
                'https://github.com/${widget.githubRepo}/releases/latest',
              );
            },
            child: Text('Update Now'),
          ),
        ],
      ),
    );
  }

  void _launchURL(String url) async {
    // Use url_launcher package if available
    try {
      // ignore: deprecated_member_use
      // await launch(url);
    } catch (e) {
      debugPrint("Could not launch URL: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
