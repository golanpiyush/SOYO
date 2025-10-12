// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:soyo/Screens/pondodetail.dart';
// import 'package:soyo/Services/pondotv.dart';
// import 'package:soyo/models/pondo_models.dart';

// class PondoHomeScreen extends StatefulWidget {
//   const PondoHomeScreen({super.key});

//   @override
//   State<PondoHomeScreen> createState() => _PondoHomeScreenState();
// }

// class _PondoHomeScreenState extends State<PondoHomeScreen>
//     with TickerProviderStateMixin {
//   final PondoScraper _scraper = PondoScraper();
//   List<PondoVideo> _videos = [];
//   bool _isLoading = true;
//   bool _hasError = false;
//   int _currentPage = 1;
//   final ScrollController _scrollController = ScrollController();
//   late AnimationController _shimmerAnimation;

//   @override
//   void initState() {
//     super.initState();
//     _shimmerAnimation = AnimationController(
//       duration: Duration(milliseconds: 1500),
//       vsync: this,
//     )..repeat();
//     _loadVideos();
//     _scrollController.addListener(_scrollListener);
//   }

//   @override
//   void dispose() {
//     _scrollController.dispose();
//     _shimmerAnimation.dispose();
//     super.dispose();
//   }

//   void _scrollListener() {
//     if (_scrollController.position.pixels ==
//         _scrollController.position.maxScrollExtent) {
//       _loadNextPage();
//     }
//   }

//   Future<void> _loadVideos() async {
//     try {
//       setState(() {
//         _isLoading = true;
//         _hasError = false;
//       });

//       final videos = await _scraper.getNewestVideos(page: _currentPage);

//       setState(() {
//         _videos = videos;
//         _isLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _isLoading = false;
//         _hasError = true;
//       });
//     }
//   }

//   Future<void> _loadNextPage() async {
//     if (_isLoading) return;
//     _currentPage++;
//     await _loadVideos();
//   }

//   Future<void> _loadPreviousPage() async {
//     if (_currentPage > 1 && !_isLoading) {
//       _currentPage--;
//       await _loadVideos();
//     }
//   }

//   Future<void> _refresh() async {
//     _currentPage = 1;
//     await _loadVideos();
//   }

//   Widget _buildShimmerLoading() {
//     return AnimatedBuilder(
//       animation: _shimmerAnimation,
//       builder: (context, child) {
//         return GridView.builder(
//           padding: EdgeInsets.all(20),
//           gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//             crossAxisCount: 2,
//             childAspectRatio: 0.7,
//             crossAxisSpacing: 10,
//             mainAxisSpacing: 20,
//           ),
//           itemCount: 6,
//           itemBuilder: (context, index) {
//             return Container(
//               margin: EdgeInsets.only(left: 20, right: index % 2 == 1 ? 20 : 0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Container(
//                     height: 190,
//                     decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(18),
//                       gradient: LinearGradient(
//                         begin: Alignment(-1.0 + _shimmerAnimation.value, -1.0),
//                         end: Alignment(1.0 + _shimmerAnimation.value, 1.0),
//                         colors: [
//                           Colors.white.withOpacity(0.1),
//                           Colors.white.withOpacity(0.3),
//                           Colors.white.withOpacity(0.1),
//                         ],
//                       ),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   Container(
//                     height: 16,
//                     decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(8),
//                       gradient: LinearGradient(
//                         begin: Alignment(-1.0 + _shimmerAnimation.value, 0.0),
//                         end: Alignment(1.0 + _shimmerAnimation.value, 0.0),
//                         colors: [
//                           Colors.white.withOpacity(0.1),
//                           Colors.white.withOpacity(0.2),
//                           Colors.white.withOpacity(0.1),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//             colors: [
//               Color(0xFF0A0A0A),
//               Color(0xFF1A0A1A),
//               Color(0xFF0A1A2A),
//               Color(0xFF000000),
//             ],
//             stops: [0.0, 0.3, 0.7, 1.0],
//           ),
//         ),
//         child: SafeArea(
//           child: Column(
//             children: [
//               _buildAppBar(),
//               Expanded(
//                 child: _isLoading && _videos.isEmpty
//                     ? _buildShimmerLoading()
//                     : _hasError
//                     ? _buildErrorState()
//                     : _buildContent(),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildAppBar() {
//     return Container(
//       padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
//       child: Row(
//         children: [
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 ShaderMask(
//                   shaderCallback: (bounds) => LinearGradient(
//                     colors: [Colors.white, Colors.pink.withOpacity(0.8)],
//                   ).createShader(bounds),
//                   child: Text(
//                     '1Pondo.tv',
//                     style: GoogleFonts.nunito(
//                       fontSize: 32,
//                       fontWeight: FontWeight.w800,
//                       color: Colors.white,
//                       letterSpacing: -0.5,
//                     ),
//                   ),
//                 ),
//                 Text(
//                   'Browse newest videos',
//                   style: GoogleFonts.nunito(
//                     fontSize: 14,
//                     color: Colors.white.withOpacity(0.7),
//                     fontWeight: FontWeight.w400,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Container(
//             padding: EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               gradient: LinearGradient(colors: [Colors.pink, Colors.purple]),
//               borderRadius: BorderRadius.circular(15),
//             ),
//             child: Icon(Icons.video_library, color: Colors.white, size: 24),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildErrorState() {
//     return Center(
//       child: Container(
//         margin: EdgeInsets.all(30),
//         padding: EdgeInsets.all(30),
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             colors: [Colors.red.withOpacity(0.1), Colors.red.withOpacity(0.05)],
//           ),
//           borderRadius: BorderRadius.circular(20),
//           border: Border.all(color: Colors.red.withOpacity(0.3)),
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(Icons.error_outline, color: Colors.red, size: 60),
//             SizedBox(height: 20),
//             Text(
//               'Failed to load videos',
//               style: GoogleFonts.nunito(color: Colors.white, fontSize: 16),
//             ),
//             SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: _loadVideos,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.red,
//                 foregroundColor: Colors.white,
//                 padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(25),
//                 ),
//               ),
//               child: Text(
//                 'Retry',
//                 style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildContent() {
//     if (_videos.isEmpty) {
//       return Center(
//         child: Text(
//           'No videos found',
//           style: GoogleFonts.nunito(color: Colors.white, fontSize: 16),
//         ),
//       );
//     }

//     return RefreshIndicator(
//       onRefresh: _refresh,
//       backgroundColor: Colors.black,
//       color: Colors.white,
//       child: Column(
//         children: [
//           // Page Navigation
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 IconButton(
//                   onPressed: _currentPage > 1 ? _loadPreviousPage : null,
//                   icon: Icon(Icons.arrow_back_ios, color: Colors.white),
//                   color: _currentPage > 1 ? Colors.white : Colors.grey,
//                 ),
//                 Text(
//                   'Page $_currentPage',
//                   style: GoogleFonts.nunito(
//                     color: Colors.white,
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 IconButton(
//                   onPressed: _loadNextPage,
//                   icon: Icon(Icons.arrow_forward_ios, color: Colors.white),
//                 ),
//               ],
//             ),
//           ),

//           // Video Grid
//           Expanded(
//             child: GridView.builder(
//               controller: _scrollController,
//               padding: EdgeInsets.all(20),
//               gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: 2,
//                 childAspectRatio: 0.7,
//                 crossAxisSpacing: 10,
//                 mainAxisSpacing: 20,
//               ),
//               itemCount: _videos.length,
//               itemBuilder: (context, index) {
//                 return _buildVideoCard(_videos[index], index);
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildVideoCard(PondoVideo video, int index) {
//     return GestureDetector(
//       onTap: () => _navigateToDetail(video),
//       child: Container(
//         margin: EdgeInsets.only(left: 20, right: index % 2 == 1 ? 20 : 0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Hero(
//               tag: 'video-${video.id}',
//               child: Container(
//                 height: 190,
//                 width: 140,
//                 child: Stack(
//                   children: [
//                     Container(
//                       decoration: BoxDecoration(
//                         borderRadius: BorderRadius.circular(18),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.pink.withOpacity(0.3),
//                             blurRadius: 20,
//                             offset: Offset(0, 10),
//                             spreadRadius: -5,
//                           ),
//                         ],
//                       ),
//                       child: ClipRRect(
//                         borderRadius: BorderRadius.circular(18),
//                         child: Image.network(
//                           video.primaryThumbnail,
//                           fit: BoxFit.cover,
//                           width: 140,
//                           height: 190,
//                           loadingBuilder: (context, child, loadingProgress) {
//                             if (loadingProgress == null) return child;
//                             return Container(
//                               decoration: BoxDecoration(
//                                 gradient: LinearGradient(
//                                   colors: [
//                                     Colors.grey.shade900,
//                                     Colors.grey.shade800,
//                                   ],
//                                 ),
//                                 borderRadius: BorderRadius.circular(18),
//                               ),
//                               child: Center(
//                                 child: CircularProgressIndicator(
//                                   color: Colors.pink,
//                                   strokeWidth: 2,
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                       ),
//                     ),
//                     // Gradient overlay
//                     Container(
//                       decoration: BoxDecoration(
//                         borderRadius: BorderRadius.circular(18),
//                         gradient: LinearGradient(
//                           begin: Alignment.topCenter,
//                           end: Alignment.bottomCenter,
//                           colors: [
//                             Colors.transparent,
//                             Colors.black.withOpacity(0.7),
//                           ],
//                         ),
//                       ),
//                     ),
//                     // Rating chip
//                     if (video.rating > 0)
//                       Positioned(
//                         top: 10,
//                         right: 10,
//                         child: Container(
//                           padding: EdgeInsets.symmetric(
//                             horizontal: 8,
//                             vertical: 4,
//                           ),
//                           decoration: BoxDecoration(
//                             color: Colors.black.withOpacity(0.7),
//                             borderRadius: BorderRadius.circular(15),
//                             border: Border.all(
//                               color: Colors.white.withOpacity(0.2),
//                               width: 1,
//                             ),
//                           ),
//                           child: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Icon(Icons.star, color: Colors.amber, size: 12),
//                               SizedBox(width: 2),
//                               Text(
//                                 video.rating.toStringAsFixed(1),
//                                 style: GoogleFonts.nunito(
//                                   color: Colors.white,
//                                   fontSize: 10,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     // Duration badge
//                     Positioned(
//                       bottom: 8,
//                       right: 8,
//                       child: Container(
//                         padding: EdgeInsets.symmetric(
//                           horizontal: 6,
//                           vertical: 2,
//                         ),
//                         decoration: BoxDecoration(
//                           color: Colors.black.withOpacity(0.7),
//                           borderRadius: BorderRadius.circular(4),
//                         ),
//                         child: Text(
//                           video.formattedDuration,
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 10,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             SizedBox(height: 12),
//             Text(
//               video.title,
//               style: GoogleFonts.nunito(
//                 color: Colors.white,
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//                 height: 1.2,
//               ),
//               maxLines: 2,
//               overflow: TextOverflow.ellipsis,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _navigateToDetail(PondoVideo video) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => PondoVideoDetailScreen(video: video),
//       ),
//     );
//   }
// }
