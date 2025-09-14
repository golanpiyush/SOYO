class TvShow {
  final int id;
  final String name;
  final String overview;
  final String posterPath;
  final String backdropPath;
  final String firstAirDate;
  final double voteAverage;
  final int voteCount;
  final String originalName;
  final String originalLanguage;

  // 🔥 Add imdbId for OMDb API
  final String imdbId;

  TvShow({
    required this.id,
    required this.name,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.firstAirDate,
    required this.voteAverage,
    required this.voteCount,
    required this.originalName,
    required this.originalLanguage,
    required this.imdbId,
  });

  String get posterUrl {
    if (posterPath.isEmpty) return '';
    return 'https://image.tmdb.org/t/p/w500$posterPath';
  }

  String get backdropUrlLarge {
    if (backdropPath.isEmpty) {
      return posterUrl.replaceFirst('/w500', '/w1280');
    }
    return 'https://image.tmdb.org/t/p/w1280$backdropPath';
  }

  String get backdropUrlOriginal {
    if (backdropPath.isEmpty) {
      return posterUrl.replaceFirst('/w500', '/original');
    }
    return 'https://image.tmdb.org/t/p/original$backdropPath';
  }

  factory TvShow.fromJson(Map<String, dynamic> json) {
    return TvShow(
      id: json['id'] ?? 0,
      name: json['name'] ?? json['original_name'] ?? 'Unknown Title',
      overview: json['overview'] ?? '',
      posterPath: json['poster_path'] ?? '',
      backdropPath: json['backdrop_path'] ?? '',
      firstAirDate: json['first_air_date'] ?? '',
      voteAverage: (json['vote_average'] ?? 0.0).toDouble(),
      voteCount: json['vote_count'] ?? 0,
      originalName: json['original_name'] ?? '',
      originalLanguage: json['original_language'] ?? 'en',
      // 🔥 Ensure imdb_id is included from TMDB API response
      imdbId: json['imdb_id'] ?? '',
    );
  }

  bool get hasBackdrop => backdropPath.isNotEmpty;

  String get year {
    if (firstAirDate.isEmpty || firstAirDate.length < 4) return '';
    return firstAirDate.substring(0, 4);
  }

  String get formattedRating => voteAverage.toStringAsFixed(1);

  bool get hasOverview => overview.isNotEmpty;
}
