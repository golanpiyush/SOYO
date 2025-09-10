class TvShow {
  final int id;
  final String name;
  final String overview;
  final String posterPath;
  final String firstAirDate;
  final double voteAverage;
  final int voteCount;

  TvShow({
    required this.id,
    required this.name,
    required this.overview,
    required this.posterPath,
    required this.firstAirDate,
    required this.voteAverage,
    required this.voteCount,
  });

  String get posterUrl {
    if (posterPath.isEmpty) return '';
    return 'https://image.tmdb.org/t/p/w500$posterPath';
  }

  factory TvShow.fromJson(Map<String, dynamic> json) {
    return TvShow(
      id: json['id'] ?? 0,
      name: json['name'] ?? json['original_name'] ?? 'Unknown Title',
      overview: json['overview'] ?? '',
      posterPath: json['poster_path'] ?? '',
      firstAirDate: json['first_air_date'] ?? '',
      voteAverage: (json['vote_average'] ?? 0.0).toDouble(),
      voteCount: json['vote_count'] ?? 0,
    );
  }
}
