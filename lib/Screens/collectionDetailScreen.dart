import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:soyo/models/moviecollections.dart';
import 'package:soyo/models/moviemodel.dart';
import 'package:soyo/Screens/movieDetailScreen.dart';
import 'package:soyo/Services/collections_api.dart';

class CollectionDetailScreen extends StatefulWidget {
  final MovieCollection collection;

  const CollectionDetailScreen({Key? key, required this.collection})
    : super(key: key);

  @override
  _CollectionDetailScreenState createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _heroController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _heroAnimation;

  String _sortBy = 'Release Date';
  List<CollectionMovie> _sortedMovies = [];

  final List<String> _sortOptions = [
    'Release Date',
    'Rating',
    'Title',
    'Popularity',
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _sortMovies();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _heroController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutQuart),
    );

    _slideAnimation = Tween<Offset>(begin: Offset(0.0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _heroAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _heroController, curve: Curves.elasticOut),
    );

    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _heroController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _heroController.dispose();
    super.dispose();
  }

  void _sortMovies() {
    _sortedMovies = List.from(widget.collection.parts);

    switch (_sortBy) {
      case 'Release Date':
        _sortedMovies.sort((a, b) {
          if (a.releaseDate.isEmpty || b.releaseDate.isEmpty) return 0;
          return DateTime.parse(
            a.releaseDate,
          ).compareTo(DateTime.parse(b.releaseDate));
        });
        break;
      case 'Rating':
        _sortedMovies.sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
        break;
      case 'Title':
        _sortedMovies.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'Popularity':
        _sortedMovies.sort((a, b) => b.popularity.compareTo(a.popularity));
        break;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final stats = CollectionsApiService.getCollectionStats(widget.collection);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0A0A),
              Color(0xFF1A0A1A),
              Color(0xFF0A1A2A),
              Color(0xFF000000),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            _buildCollectionInfo(stats),
            _buildSortingSection(),
            _buildMoviesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 400,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Hero(
          tag: 'collection-${widget.collection.id}',
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image
              CachedNetworkImage(
                imageUrl: widget.collection.backdropUrlLarge,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.grey.shade900, Colors.grey.shade800],
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.grey.shade900, Colors.grey.shade800],
                    ),
                  ),
                  child: Icon(
                    Icons.movie_filter_outlined,
                    color: Colors.white30,
                    size: 80,
                  ),
                ),
              ),
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.95),
                    ],
                  ),
                ),
              ),
              // Content
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [Colors.white, Colors.deepPurple],
                          ).createShader(bounds),
                          child: Text(
                            widget.collection.name,
                            style: GoogleFonts.nunito(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.deepPurple, Colors.indigo],
                                ),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Text(
                                '${widget.collection.parts.length} Movies',
                                style: GoogleFonts.nunito(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    widget.collection.averageRating
                                        .toStringAsFixed(1),
                                    style: GoogleFonts.nunito(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionInfo(Map<String, dynamic> stats) {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: EdgeInsets.all(20),
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.05),
                Colors.white.withOpacity(0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Collection Overview',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              if (widget.collection.overview.isNotEmpty)
                Text(
                  widget.collection.overview,
                  style: GoogleFonts.cabin(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              SizedBox(height: 20),
              _buildStatsGrid(stats),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: [
        _buildStatCard(
          'Total Movies',
          '${stats['totalMovies']}',
          Icons.movie_filter,
          Colors.deepPurple,
        ),
        _buildStatCard(
          'Average Rating',
          stats['averageRating'].toStringAsFixed(1),
          Icons.star,
          Colors.amber,
        ),
        _buildStatCard(
          'Total Runtime',
          '${(stats['totalRuntime'] / 60).floor()}h ${stats['totalRuntime'] % 60}m',
          Icons.access_time,
          Colors.blue,
        ),
        _buildStatCard(
          'Latest Release',
          stats['latestRelease']?.releaseYear ?? 'N/A',
          Icons.calendar_today,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortingSection() {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Text(
                'Movies',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sortBy,
                    dropdownColor: Colors.grey[900],
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    items: _sortOptions.map((String option) {
                      return DropdownMenuItem<String>(
                        value: option,
                        child: Text(
                          'Sort by $option',
                          style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _sortBy = newValue;
                        });
                        _sortMovies();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoviesList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        return AnimatedBuilder(
          animation: _heroAnimation,
          builder: (context, child) {
            // Fixed: Calculate stagger value so first items have full opacity
            final staggerValue = (_heroAnimation.value + (index * 0.1)).clamp(
              0.0,
              1.0,
            );

            return Transform.translate(
              offset: Offset(0, 30 * (1 - staggerValue)),
              child: Opacity(
                opacity: staggerValue,
                child: _buildMovieListItem(_sortedMovies[index], index),
              ),
            );
          },
        );
      }, childCount: _sortedMovies.length),
    );
  }

  Widget _buildMovieListItem(CollectionMovie movie, int index) {
    return GestureDetector(
      onTap: () => _navigateToMovieDetail(movie),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.05),
              Colors.white.withOpacity(0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Row(
          children: [
            // Movie poster
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: movie.posterUrl,
                width: 60,
                height: 90,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 60,
                  height: 90,
                  color: Colors.grey[800],
                  child: Icon(Icons.movie, color: Colors.white30),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 60,
                  height: 90,
                  color: Colors.grey[800],
                  child: Icon(Icons.movie, color: Colors.white30),
                ),
              ),
            ),
            SizedBox(width: 15),
            // Movie info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  if (movie.releaseDate.isNotEmpty)
                    Text(
                      'Released: ${movie.releaseYear}',
                      style: GoogleFonts.cabin(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 16),
                      SizedBox(width: 4),
                      Text(
                        movie.formattedRating,
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 15),
                      // Fixed: Only show runtime if it's greater than 0
                      if (movie.runtime != null && movie.runtime! > 0)
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: Colors.blue,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '${movie.runtime}min',
                              style: GoogleFonts.nunito(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        )
                      else
                        // Show popularity instead of runtime if runtime is 0 or null
                        Row(
                          children: [
                            Icon(
                              Icons.trending_up,
                              color: Colors.orange,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '${movie.popularity.toStringAsFixed(0)}',
                              style: GoogleFonts.nunito(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Arrow icon
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToMovieDetail(CollectionMovie collectionMovie) {
    // Convert CollectionMovie to Movie
    final movie = Movie(
      id: collectionMovie.id,
      title: collectionMovie.title,
      originalTitle: collectionMovie.originalTitle,
      overview: collectionMovie.overview,
      posterPath: collectionMovie.posterPath,
      backdropPath: collectionMovie.backdropPath ?? '',
      voteAverage: collectionMovie.voteAverage,
      voteCount: collectionMovie.voteCount,
      releaseDate: collectionMovie.releaseDate,
      genreIds: collectionMovie.genreIds,
      originalLanguage: collectionMovie.originalLanguage,
      runtime: collectionMovie.runtime,
      adult: collectionMovie.adult,
      popularity: collectionMovie.popularity,
    );

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            MovieDetailScreen(movie: movie),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: Offset(1.0, 0.0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          );
        },
        transitionDuration: Duration(milliseconds: 400),
      ),
    );
  }
}
