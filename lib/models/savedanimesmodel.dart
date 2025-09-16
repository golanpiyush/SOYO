class SavedAnime {
  final String id;
  final String name;
  final String overview;
  final String posterUrl;
  final String backdropUrl;
  final String firstAirDate;
  final double voteAverage;
  final String originalLanguage;
  final DateTime savedAt;

  SavedAnime({
    required this.id,
    required this.name,
    required this.overview,
    required this.posterUrl,
    required this.backdropUrl,
    required this.firstAirDate,
    required this.voteAverage,
    required this.originalLanguage,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'overview': overview,
      'posterUrl': posterUrl,
      'backdropUrl': backdropUrl,
      'firstAirDate': firstAirDate,
      'voteAverage': voteAverage,
      'originalLanguage': originalLanguage,
      'savedAt': savedAt.toIso8601String(),
    };
  }

  factory SavedAnime.fromJson(Map<String, dynamic> json) {
    return SavedAnime(
      id: json['id'],
      name: json['name'],
      overview: json['overview'],
      posterUrl: json['posterUrl'],
      backdropUrl: json['backdropUrl'],
      firstAirDate: json['firstAirDate'],
      voteAverage: json['voteAverage'],
      originalLanguage: json['originalLanguage'],
      savedAt: DateTime.parse(json['savedAt']),
    );
  }
}
