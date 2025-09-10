class Movie {
  final int id;
  final String title;
  final String? originalTitle;
  final String overview;
  final String posterPath;
  final String backdropPath;
  final double voteAverage;
  final int voteCount;
  final String releaseDate;
  final List<int> genreIds;
  final String? originalLanguage;
  final int? runtime;
  final bool adult;
  final double popularity;
  final List<CastMember>? cast;
  final List<CrewMember>? crew;

  Movie({
    required this.id,
    required this.title,
    this.originalTitle,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.voteAverage,
    required this.voteCount,
    required this.releaseDate,
    required this.genreIds,
    this.originalLanguage,
    this.runtime,
    this.adult = false,
    this.popularity = 0.0,
    this.cast,
    this.crew,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'],
      title: json['title'] ?? '',
      originalTitle: json['original_title'],
      overview: json['overview'] ?? '',
      posterPath: json['poster_path'] ?? '',
      backdropPath: json['backdrop_path'] ?? '',
      voteAverage: (json['vote_average'] ?? 0.0).toDouble(),
      voteCount: json['vote_count'] ?? 0,
      releaseDate: json['release_date'] ?? '',
      genreIds: List<int>.from(json['genre_ids'] ?? []),
      originalLanguage: json['original_language'],
      runtime: json['runtime'],
      adult: json['adult'] ?? false,
      popularity: (json['popularity'] ?? 0.0).toDouble(),
      cast: json['credits'] != null
          ? List<CastMember>.from(
              json['credits']['cast'].map((x) => CastMember.fromJson(x)),
            )
          : null,
      crew: json['credits'] != null
          ? List<CrewMember>.from(
              json['credits']['crew'].map((x) => CrewMember.fromJson(x)),
            )
          : null,
    );
  }

  // Standard poster URL
  String get posterUrl => posterPath.isNotEmpty
      ? 'https://image.tmdb.org/t/p/w500$posterPath'
      : 'https://via.placeholder.com/500x750/333/fff?text=No+Image';

  // High quality poster URL
  String get posterUrlHQ => posterPath.isNotEmpty
      ? 'https://image.tmdb.org/t/p/original$posterPath'
      : 'https://via.placeholder.com/500x750/333/fff?text=No+Image';

  // Standard backdrop URL
  String get backdropUrl => backdropPath.isNotEmpty
      ? 'https://image.tmdb.org/t/p/w780$backdropPath'
      : 'https://via.placeholder.com/780x439/333/fff?text=No+Image';

  // High quality backdrop URL for detail screens
  String get backdropUrlLarge => backdropPath.isNotEmpty
      ? 'https://image.tmdb.org/t/p/w1280$backdropPath'
      : 'https://via.placeholder.com/1280x720/333/fff?text=No+Image';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'original_title': originalTitle,
      'overview': overview,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'vote_average': voteAverage,
      'vote_count': voteCount,
      'release_date': releaseDate,
      'genre_ids': genreIds,
      'original_language': originalLanguage,
      'runtime': runtime,
      'adult': adult,
      'popularity': popularity,
    };
  }
}

class CastMember {
  final int id;
  final String name;
  final String character;
  final String? profilePath;
  final int order;

  CastMember({
    required this.id,
    required this.name,
    required this.character,
    this.profilePath,
    required this.order,
  });

  factory CastMember.fromJson(Map<String, dynamic> json) {
    return CastMember(
      id: json['id'],
      name: json['name'],
      character: json['character'],
      profilePath: json['profile_path'],
      order: json['order'],
    );
  }

  // Standard profile image
  String get profileUrl => profilePath != null
      ? 'https://image.tmdb.org/t/p/w185$profilePath'
      : 'https://via.placeholder.com/185x185/333/fff?text=No+Image';

  // High quality profile image
  String get profileUrlHQ => profilePath != null
      ? 'https://image.tmdb.org/t/p/h632$profilePath'
      : 'https://via.placeholder.com/632x632/333/fff?text=No+Image';
}

class CrewMember {
  final int id;
  final String name;
  final String job;
  final String? profilePath;
  final String department;

  CrewMember({
    required this.id,
    required this.name,
    required this.job,
    this.profilePath,
    required this.department,
  });

  factory CrewMember.fromJson(Map<String, dynamic> json) {
    return CrewMember(
      id: json['id'],
      name: json['name'],
      job: json['job'],
      profilePath: json['profile_path'],
      department: json['department'],
    );
  }

  // Standard profile image
  String get profileUrl => profilePath != null
      ? 'https://image.tmdb.org/t/p/w185$profilePath'
      : 'https://via.placeholder.com/185x185/333/fff?text=No+Image';

  // High quality profile image
  String get profileUrlHQ => profilePath != null
      ? 'https://image.tmdb.org/t/p/h632$profilePath'
      : 'https://via.placeholder.com/632x632/333/fff?text=No+Image';
}
