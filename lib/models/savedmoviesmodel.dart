// SavedMovie model class
class SavedMovie {
  final String id;
  final String title;
  final String overview;
  final String posterUrl;
  final String backdropUrl;
  final String releaseDate;
  final double voteAverage;
  final List<String> cast;
  final Map<String, List<String>> crew;
  final DateTime savedAt;

  SavedMovie({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterUrl,
    required this.backdropUrl,
    required this.releaseDate,
    required this.voteAverage,
    required this.cast,
    required this.crew,
    required this.savedAt,
  });

  factory SavedMovie.fromJson(Map<String, dynamic> json) {
    return SavedMovie(
      id: json['id'],
      title: json['title'],
      overview: json['overview'],
      posterUrl: json['posterUrl'],
      backdropUrl: json['backdropUrl'],
      releaseDate: json['releaseDate'],
      voteAverage: json['voteAverage'].toDouble(),
      cast: List<String>.from(json['cast']),
      crew: Map<String, List<String>>.from(
        json['crew'].map(
          (key, value) => MapEntry(key, List<String>.from(value)),
        ),
      ),
      savedAt: DateTime.parse(json['savedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'overview': overview,
      'posterUrl': posterUrl,
      'backdropUrl': backdropUrl,
      'releaseDate': releaseDate,
      'voteAverage': voteAverage,
      'cast': cast,
      'crew': crew,
      'savedAt': savedAt.toIso8601String(),
    };
  }
}
