// Collection Models
class MovieCollection {
  final int id;
  final String name;
  final String overview;
  final String posterPath;
  final String backdropPath;
  final List<CollectionMovie> parts;

  MovieCollection({
    required this.id,
    required this.name,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.parts,
  });

  factory MovieCollection.fromJson(Map<String, dynamic> json) {
    return MovieCollection(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      overview: json['overview'] ?? '',
      posterPath: json['poster_path'] ?? '',
      backdropPath: json['backdrop_path'] ?? '',
      parts: json['parts'] != null
          ? List<CollectionMovie>.from(
              json['parts'].map((x) => CollectionMovie.fromJson(x)),
            )
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'overview': overview,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'parts': parts.map((x) => x.toJson()).toList(),
    };
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

  // Get movies sorted by release date
  List<CollectionMovie> get moviesSortedByReleaseDate {
    final sortedParts = List<CollectionMovie>.from(parts);
    sortedParts.sort((a, b) {
      if (a.releaseDate.isEmpty || b.releaseDate.isEmpty) return 0;
      return DateTime.parse(
        a.releaseDate,
      ).compareTo(DateTime.parse(b.releaseDate));
    });
    return sortedParts;
  }

  // Get total runtime of all movies
  int get totalRuntime {
    return parts.fold(0, (sum, movie) => sum + (movie.runtime ?? 0));
  }

  // Get average rating
  double get averageRating {
    if (parts.isEmpty) return 0.0;
    final totalRating = parts.fold(
      0.0,
      (sum, movie) => sum + movie.voteAverage,
    );
    return totalRating / parts.length;
  }
}

class CollectionMovie {
  final int id;
  final String title;
  final String? originalTitle;
  final String overview;
  final String posterPath;
  final String? backdropPath;
  final String mediaType;
  final String? originalLanguage;
  final List<int> genreIds;
  final double popularity;
  final String releaseDate;
  final bool video;
  final double voteAverage;
  final int voteCount;
  final bool adult;
  final int? runtime;

  CollectionMovie({
    required this.id,
    required this.title,
    this.originalTitle,
    required this.overview,
    required this.posterPath,
    this.backdropPath,
    required this.mediaType,
    this.originalLanguage,
    required this.genreIds,
    required this.popularity,
    required this.releaseDate,
    required this.video,
    required this.voteAverage,
    required this.voteCount,
    required this.adult,
    this.runtime,
  });

  factory CollectionMovie.fromJson(Map<String, dynamic> json) {
    return CollectionMovie(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      originalTitle: json['original_title'],
      overview: json['overview'] ?? '',
      posterPath: json['poster_path'] ?? '',
      backdropPath: json['backdrop_path'],
      mediaType: json['media_type'] ?? 'movie',
      originalLanguage: json['original_language'],
      genreIds: List<int>.from(json['genre_ids'] ?? []),
      popularity: (json['popularity'] ?? 0.0).toDouble(),
      releaseDate: json['release_date'] ?? '',
      video: json['video'] ?? false,
      voteAverage: (json['vote_average'] ?? 0.0).toDouble(),
      voteCount: json['vote_count'] ?? 0,
      adult: json['adult'] ?? false,
      runtime: json['runtime'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'original_title': originalTitle,
      'overview': overview,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'media_type': mediaType,
      'original_language': originalLanguage,
      'genre_ids': genreIds,
      'popularity': popularity,
      'release_date': releaseDate,
      'video': video,
      'vote_average': voteAverage,
      'vote_count': voteCount,
      'adult': adult,
      'runtime': runtime,
    };
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
  String get backdropUrl => backdropPath != null && backdropPath!.isNotEmpty
      ? 'https://image.tmdb.org/t/p/w780$backdropPath'
      : 'https://via.placeholder.com/780x439/333/fff?text=No+Image';

  // High quality backdrop URL for detail screens
  String get backdropUrlLarge =>
      backdropPath != null && backdropPath!.isNotEmpty
      ? 'https://image.tmdb.org/t/p/w1280$backdropPath'
      : 'https://via.placeholder.com/1280x720/333/fff?text=No+Image';

  // Get release year
  String get releaseYear {
    if (releaseDate.isEmpty) return 'Unknown';
    try {
      return DateTime.parse(releaseDate).year.toString();
    } catch (e) {
      return 'Unknown';
    }
  }

  // Check if movie is recently released (within last 2 years)
  bool get isRecentRelease {
    if (releaseDate.isEmpty) return false;
    try {
      final releaseDateTime = DateTime.parse(releaseDate);
      final now = DateTime.now();
      final twoYearsAgo = DateTime(now.year - 2, now.month, now.day);
      return releaseDateTime.isAfter(twoYearsAgo);
    } catch (e) {
      return false;
    }
  }

  // Get formatted rating
  String get formattedRating => voteAverage.toStringAsFixed(1);
}
