// Create this file: models/savedtvshowmodel.dart
class SavedTvShow {
  final String id;
  final String name;
  final String originalName;
  final String overview;
  final String posterUrl;
  final String backdropUrl;
  final String firstAirDate;
  final double voteAverage;
  final String originalLanguage;

  SavedTvShow({
    required this.id,
    required this.name,
    required this.originalName,
    required this.overview,
    required this.posterUrl,
    required this.backdropUrl,
    required this.firstAirDate,
    required this.voteAverage,
    required this.originalLanguage,
  });

  factory SavedTvShow.fromJson(Map<String, dynamic> json) {
    return SavedTvShow(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      originalName: json['originalName'] ?? '',
      overview: json['overview'] ?? '',
      posterUrl: json['posterUrl'] ?? '',
      backdropUrl: json['backdropUrl'] ?? '',
      firstAirDate: json['firstAirDate'] ?? '',
      voteAverage: (json['voteAverage'] ?? 0.0).toDouble(),
      originalLanguage: json['originalLanguage'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'originalName': originalName,
      'overview': overview,
      'posterUrl': posterUrl,
      'backdropUrl': backdropUrl,
      'firstAirDate': firstAirDate,
      'voteAverage': voteAverage,
      'originalLanguage': originalLanguage,
    };
  }
}
