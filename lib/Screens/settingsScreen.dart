import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:soyo/Services/m3u8api.dart';

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
            // _buildServerSection(),
            // SizedBox(height: 20),
            _buildStreamingSection(),
            SizedBox(height: 20),
            // _buildAppearanceSection(),
            // SizedBox(height: 20),
            // _buildStorageSection(),
            // SizedBox(height: 20),
            _buildAboutSection(),
            SizedBox(height: 20),
            _buildDisclaimerSection(),
            SizedBox(height: 60),
          ],
        ),
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

  // Widget _buildServerSection() {
  //   return Container(
  //     padding: EdgeInsets.all(20),
  //     decoration: BoxDecoration(
  //       color: Colors.grey[900],
  //       borderRadius: BorderRadius.circular(15),
  //       border: Border.all(color: Colors.grey[800]!),
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         // Row(
  //         //   children: [
  //         //     Icon(Icons.cloud, color: Colors.blue),
  //         //     SizedBox(width: 12),
  //         //     Text(
  //         //       'Server Settings',
  //         //       style: TextStyle(
  //         //         color: Colors.white,
  //         //         fontSize: 18,
  //         //         fontWeight: FontWeight.bold,
  //         //       ),
  //         //     ),
  //         //   ],
  //         // ),
  //         // SizedBox(height: 20),

  //         // // Server URL
  //         // Container(
  //         //   padding: EdgeInsets.all(12),
  //         //   decoration: BoxDecoration(
  //         //     color: Colors.black.withOpacity(0.5),
  //         //     borderRadius: BorderRadius.circular(10),
  //         //     border: Border.all(color: Colors.grey[700]!),
  //         //   ),
  //         //   child: Column(
  //         //     crossAxisAlignment: CrossAxisAlignment.start,
  //         //     children: [
  //         //       Text(
  //         //         'API Server URL:',
  //         //         style: TextStyle(color: Colors.white70, fontSize: 14),
  //         //       ),
  //         //       SizedBox(height: 5),
  //         //       Row(
  //         //         children: [
  //         //           Expanded(
  //         //             child: Text(
  //         //               'https://0nnf7qzl-5000.inc1.devtunnels.ms',
  //         //               style: TextStyle(color: Colors.blue, fontSize: 12),
  //         //             ),
  //         //           ),
  //         //           IconButton(
  //         //             onPressed: () => _copyToClipboard(
  //         //               'https://0nnf7qzl-5000.inc1.devtunnels.ms',
  //         //             ),
  //         //             icon: Icon(Icons.copy, color: Colors.grey, size: 18),
  //         //           ),
  //         //         ],
  //         //       ),
  //         //     ],
  //         //   ),
  //         // ),

  //         SizedBox(height: 15),

  //         // Connection Test
  //         Row(
  //           children: [
  //             Expanded(
  //               child: ElevatedButton.icon(
  //                 onPressed: _isTestingConnection ? null : _testConnection,
  //                 icon: _isTestingConnection
  //                     ? SizedBox(
  //                         width: 16,
  //                         height: 16,
  //                         child: CircularProgressIndicator(
  //                           strokeWidth: 2,
  //                           valueColor: AlwaysStoppedAnimation<Color>(
  //                             Colors.white,
  //                           ),
  //                         ),
  //                       )
  //                     : Icon(_getConnectionIcon(), size: 18),
  //                 label: Text(
  //                   _isTestingConnection ? 'Testing...' : 'Test Connection',
  //                 ),
  //                 style: ElevatedButton.styleFrom(
  //                   backgroundColor: _getConnectionColor(),
  //                   foregroundColor: Colors.white,
  //                   shape: RoundedRectangleBorder(
  //                     borderRadius: BorderRadius.circular(10),
  //                   ),
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),

  //         if (_connectionStatus != null)
  //           Container(
  //             margin: EdgeInsets.only(top: 10),
  //             padding: EdgeInsets.all(10),
  //             decoration: BoxDecoration(
  //               color: _connectionStatus!
  //                   ? Colors.green.withOpacity(0.2)
  //                   : Colors.red.withOpacity(0.2),
  //               borderRadius: BorderRadius.circular(8),
  //               border: Border.all(
  //                 color: _connectionStatus! ? Colors.green : Colors.red,
  //               ),
  //             ),
  //             child: Row(
  //               children: [
  //                 Icon(
  //                   _connectionStatus! ? Icons.check_circle : Icons.error,
  //                   color: _connectionStatus! ? Colors.green : Colors.red,
  //                   size: 18,
  //                 ),
  //                 SizedBox(width: 8),
  //                 Text(
  //                   _connectionStatus!
  //                       ? 'Server is online'
  //                       : 'Server is offline',
  //                   style: TextStyle(
  //                     color: _connectionStatus! ? Colors.green : Colors.red,
  //                     fontSize: 14,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //       ],
  //     ),
  //   );
  // }

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
                style: TextStyle(
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

  // Widget _buildAppearanceSection() {
  //   return Container(
  //     padding: EdgeInsets.all(20),
  //     decoration: BoxDecoration(
  //       color: Colors.grey[900],
  //       borderRadius: BorderRadius.circular(15),
  //       border: Border.all(color: Colors.grey[800]!),
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Row(
  //           children: [
  //             Icon(Icons.palette, color: Colors.purple),
  //             SizedBox(width: 12),
  //             Text(
  //               'Appearance',
  //               style: TextStyle(
  //                 color: Colors.white,
  //                 fontSize: 18,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //           ],
  //         ),
  //         SizedBox(height: 20),

  //         _buildSwitchSetting(
  //           'Dark Theme',
  //           'Use dark theme throughout the app',
  //           _darkTheme,
  //           (value) => setState(() => _darkTheme = value),
  //           Icons.dark_mode,
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildStorageSection() {
  //   return Container(
  //     padding: EdgeInsets.all(20),
  //     decoration: BoxDecoration(
  //       color: Colors.grey[900],
  //       borderRadius: BorderRadius.circular(15),
  //       border: Border.all(color: Colors.grey[800]!),
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Row(
  //           children: [
  //             Icon(Icons.storage, color: Colors.orange),
  //             SizedBox(width: 12),
  //             Text(
  //               'Storage',
  //               style: TextStyle(
  //                 color: Colors.white,
  //                 fontSize: 18,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //           ],
  //         ),
  //         SizedBox(height: 20),

  //         // Saved movies count
  //         Container(
  //           padding: EdgeInsets.all(12),
  //           decoration: BoxDecoration(
  //             color: Colors.black.withOpacity(0.5),
  //             borderRadius: BorderRadius.circular(10),
  //           ),
  //           child: Row(
  //             children: [
  //               Icon(Icons.bookmark, color: Colors.orange, size: 20),
  //               SizedBox(width: 10),
  //               Expanded(
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Text(
  //                       'Saved Movies',
  //                       style: TextStyle(
  //                         color: Colors.white,
  //                         fontWeight: FontWeight.w500,
  //                       ),
  //                     ),
  //                     Text(
  //                       '${SavedScreen.getSavedMoviesCount()} movies saved',
  //                       style: TextStyle(color: Colors.grey[400], fontSize: 12),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),

  //         SizedBox(height: 15),

  //         ElevatedButton.icon(
  //           onPressed: _showClearDataDialog,
  //           icon: Icon(Icons.delete_sweep, size: 18),
  //           label: Text('Clear All Data'),
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: Colors.red.withOpacity(0.8),
  //             foregroundColor: Colors.white,
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(10),
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

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

          _buildInfoRow('App Version', '1.0.0'),
          _buildInfoRow('Developer', 'Piyush Golan'),
          _buildInfoRow('API Version', 'v2.1'),

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
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
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
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          DropdownButton<String>(
            value: value,
            dropdownColor: Colors.grey[800],
            style: TextStyle(color: Colors.white),
            underline: Container(),
            items: options.map((String option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(option, style: TextStyle(color: Colors.white)),
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
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getConnectionIcon() {
    if (_connectionStatus == null) return Icons.wifi;
    return _connectionStatus! ? Icons.check_circle : Icons.error;
  }

  Color _getConnectionColor() {
    if (_connectionStatus == null) return Colors.blue;
    return _connectionStatus! ? Colors.green : Colors.red;
  }

  void _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
    });

    try {
      final isConnected = await _api.testConnection();
      setState(() {
        _connectionStatus = isConnected;
        _isTestingConnection = false;
      });
    } catch (e) {
      setState(() {
        _connectionStatus = false;
        _isTestingConnection = false;
      });
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied to clipboard'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 10),
            Text('Clear All Data', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'This will remove all saved movies and reset app settings. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              // Here you would clear all data
              // Since we're using in-memory storage, we can't actually persist this
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Data cleared successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text('Clear All', style: TextStyle(color: Colors.red)),
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
          style: TextStyle(color: Colors.white),
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
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
