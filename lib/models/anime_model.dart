// Response model
class AnimeResponse {
  final int page;
  final List<Anime> results;
  final int totalPages;
  final int totalResults;

  AnimeResponse({
    required this.page,
    required this.results,
    required this.totalPages,
    required this.totalResults,
  });

  factory AnimeResponse.fromJson(Map<String, dynamic> json) {
    return AnimeResponse(
      page: json['page'],
      results: List<Anime>.from(json['results'].map((x) => Anime.fromJson(x))),
      totalPages: json['total_pages'],
      totalResults: json['total_results'],
    );
  }
}

// Anime model
class Anime {
  final bool adult;
  final String? backdropPath;
  final String firstAirDate;
  final List<int> genreIds;
  final int id;
  final String name;
  final List<String> originCountry;
  final String originalLanguage;
  final String originalName;
  final String overview;
  final double popularity;
  final String? posterPath;
  final double voteAverage;
  final int voteCount;

  Anime({
    required this.adult,
    this.backdropPath,
    required this.firstAirDate,
    required this.genreIds,
    required this.id,
    required this.name,
    required this.originCountry,
    required this.originalLanguage,
    required this.originalName,
    required this.overview,
    required this.popularity,
    this.posterPath,
    required this.voteAverage,
    required this.voteCount,
  });

  factory Anime.fromJson(Map<String, dynamic> json) {
    return Anime(
      adult: json['adult'],
      backdropPath: json['backdrop_path'],
      firstAirDate: json['first_air_date'],
      genreIds: List<int>.from(json['genre_ids']),
      id: json['id'],
      name: json['name'],
      originCountry: List<String>.from(json['origin_country']),
      originalLanguage: json['original_language'],
      originalName: json['original_name'],
      overview: json['overview'],
      popularity: json['popularity'].toDouble(),
      posterPath: json['poster_path'],
      voteAverage: json['vote_average'].toDouble(),
      voteCount: json['vote_count'],
    );
  }

  // Helper method to get full image URL
  String getPosterUrl({String size = 'w500'}) {
    if (posterPath == null) return '';
    return 'https://image.tmdb.org/t/p/$size$posterPath';
  }

  String getBackdropUrl({String size = 'w780'}) {
    if (backdropPath == null) return '';
    return 'https://image.tmdb.org/t/p/$size$backdropPath';
  }
}

// Sorting options
enum AnimeSortOption {
  popularityDesc('popularity.desc'),
  popularityAsc('popularity.asc'),
  voteAverageDesc('vote_average.desc'),
  voteAverageAsc('vote_average.asc'),
  firstAirDateDesc('first_air_date.desc'),
  firstAirDateAsc('first_air_date.asc'),
  nameAsc('original_name.asc'),
  nameDesc('original_name.desc');

  final String value;
  const AnimeSortOption(this.value);
}
