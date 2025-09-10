import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soyo/Screens/homescreen.dart';

class SavedScreen extends StatefulWidget {
  @override
  _SavedScreenState createState() => _SavedScreenState();

  // Expose static helpers to other screens
  static void addMovie({
    required String name,
    required String m3u8Link,
    List<String>? subtitles,
  }) {
    _SavedScreenState.addMovie(
      name: name,
      m3u8Link: m3u8Link,
      subtitles: subtitles,
    );
  }

  static bool isMovieSaved(String movieName) {
    return _SavedScreenState.isMovieSaved(movieName);
  }

  static int getSavedMoviesCount() {
    return _SavedScreenState.getSavedMoviesCount();
  }
}

class _SavedScreenState extends State<SavedScreen> {
  // In-memory storage for saved movies (use SharedPreferences later if needed)
  static List<Map<String, dynamic>> _savedMovies = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Saved Movies', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_savedMovies.isNotEmpty)
            IconButton(
              onPressed: _clearAllMovies,
              icon: Icon(Icons.clear_all, color: Colors.red),
              tooltip: 'Clear All',
            ),
        ],
      ),
      body: _savedMovies.isEmpty ? _buildEmptyState() : _buildMoviesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bookmark_border,
              size: 80,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 30),
          Text(
            'No Saved Movies',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Search for movies and save them here\nfor quick access later',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to home screen
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => HomeScreen()),
                (Route<dynamic> route) => false,
              );
            },
            icon: Icon(Icons.search),
            label: Text('Start Searching'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoviesList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _savedMovies.length,
      itemBuilder: (context, index) {
        final movie = _savedMovies[index];
        return _buildMovieCard(movie, index);
      },
    );
  }

  Widget _buildMovieCard(Map<String, dynamic> movie, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[800]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie['name'],
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Saved on ${movie['savedDate']}',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _copyToClipboard(movie['m3u8_link']),
                  icon: Icon(Icons.copy, color: Colors.grey),
                  tooltip: 'Copy Link',
                ),
                IconButton(
                  onPressed: () => _removeMovie(index),
                  icon: Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Remove',
                ),
              ],
            ),
          ),

          // Stream link
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.play_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Stream Link',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[700]!),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          movie['m3u8_link'],
                          style: TextStyle(color: Colors.blue, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Buttons
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _playMovie(movie),
                    icon: Icon(Icons.play_arrow, size: 18),
                    label: Text('Play'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _shareMovie(movie),
                    icon: Icon(Icons.share, size: 18),
                    label: Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Subtitles
          if (movie['subtitles'] != null &&
              (movie['subtitles'] as List).isNotEmpty)
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.subtitles, color: Colors.purple, size: 16),
                  SizedBox(width: 8),
                  Text(
                    '${(movie['subtitles'] as List).length} subtitle(s) available',
                    style: TextStyle(
                      color: Colors.purple,
                      fontSize: 12,
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

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Link copied to clipboard'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _playMovie(Map<String, dynamic> movie) {
    _copyToClipboard(movie['m3u8_link']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.play_circle, color: Colors.red),
            SizedBox(width: 10),
            Text('Play Movie', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Stream link copied to clipboard.\n\nOpen in your preferred video player:\n• VLC\n• MX Player\n• Any M3U8 player',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _shareMovie(Map<String, dynamic> movie) {
    final shareText =
        'Check out this movie: ${movie['name']}\n\nStream Link: ${movie['m3u8_link']}';
    _copyToClipboard(shareText);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Movie details copied to clipboard for sharing'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _removeMovie(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Remove Movie', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to remove "${_savedMovies[index]['name']}"?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _savedMovies.removeAt(index);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Movie removed'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _clearAllMovies() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Clear All Movies', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to remove all saved movies?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _savedMovies.clear();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('All movies cleared'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Static helpers
  static void addMovie({
    required String name,
    required String m3u8Link,
    List<String>? subtitles,
  }) {
    bool exists = _savedMovies.any((movie) => movie['name'] == name);
    if (!exists) {
      _savedMovies.add({
        'name': name,
        'm3u8_link': m3u8Link,
        'subtitles': subtitles ?? [],
        'savedDate': DateTime.now().toString().split(' ')[0],
        'savedTime': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  static bool isMovieSaved(String movieName) {
    return _savedMovies.any((movie) => movie['name'] == movieName);
  }

  static int getSavedMoviesCount() {
    return _savedMovies.length;
  }
}
