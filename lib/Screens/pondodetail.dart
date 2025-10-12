// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:soyo/Screens/playerScreen.dart';
// import 'package:soyo/models/pondo_models.dart';

// class PondoVideoDetailScreen extends StatefulWidget {
//   final PondoVideo video;

//   const PondoVideoDetailScreen({Key? key, required this.video})
//     : super(key: key);

//   @override
//   _PondoVideoDetailScreenState createState() => _PondoVideoDetailScreenState();
// }

// class _PondoVideoDetailScreenState extends State<PondoVideoDetailScreen>
//     with TickerProviderStateMixin {
//   late AnimationController _animationController;
//   late Animation<double> _fadeAnimation;
//   late AnimationController _slideAnimationController;
//   late Animation<Offset> _slideAnimation;
//   late AnimationController _scaleAnimationController;
//   late Animation<double> _scaleAnimation;
//   String _selectedQuality = '720p'; // Add this at class level

//   @override
//   void initState() {
//     super.initState();

//     _animationController = AnimationController(
//       duration: const Duration(milliseconds: 800),
//       vsync: this,
//     );
//     _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
//     );

//     _slideAnimationController = AnimationController(
//       duration: const Duration(milliseconds: 600),
//       vsync: this,
//     );
//     _slideAnimation =
//         Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
//           CurvedAnimation(
//             parent: _slideAnimationController,
//             curve: Curves.easeOutCubic,
//           ),
//         );

//     _scaleAnimationController = AnimationController(
//       duration: const Duration(milliseconds: 400),
//       vsync: this,
//     );
//     _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
//       CurvedAnimation(
//         parent: _scaleAnimationController,
//         curve: Curves.easeOutBack,
//       ),
//     );

//     _animationController.forward();
//     _slideAnimationController.forward();
//     _scaleAnimationController.forward();
//   }

//   @override
//   void dispose() {
//     _animationController.dispose();
//     _slideAnimationController.dispose();
//     _scaleAnimationController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF0A0A0A),
//       body: CustomScrollView(
//         slivers: [
//           _buildSliverAppBar(),
//           SliverToBoxAdapter(
//             child: FadeTransition(
//               opacity: _fadeAnimation,
//               child: _buildVideoDetails(),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSliverAppBar() {
//     return SliverAppBar(
//       expandedHeight: 400,
//       pinned: true,
//       elevation: 0,
//       backgroundColor: const Color(0xFF0A0A0A),
//       leading: Container(
//         margin: const EdgeInsets.all(8),
//         decoration: BoxDecoration(
//           color: Colors.black.withOpacity(0.5),
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: IconButton(
//           icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       flexibleSpace: FlexibleSpaceBar(
//         background: Stack(
//           fit: StackFit.expand,
//           children: [
//             Hero(
//               tag: 'video-${widget.video.id}',
//               child: Image.network(
//                 widget.video.bestQualityThumbnail,
//                 fit: BoxFit.cover,
//                 errorBuilder: (context, error, stackTrace) {
//                   return Container(
//                     color: Colors.grey[900],
//                     child: Center(
//                       child: Icon(
//                         Icons.video_library,
//                         size: 80,
//                         color: Colors.white.withOpacity(0.3),
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//             Container(
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   begin: Alignment.topCenter,
//                   end: Alignment.bottomCenter,
//                   colors: [
//                     Colors.transparent,
//                     Colors.transparent,
//                     const Color(0xFF0A0A0A).withOpacity(0.7),
//                     const Color(0xFF0A0A0A),
//                   ],
//                   stops: const [0.0, 0.5, 0.8, 1.0],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildVideoDetails() {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _buildTitleSection(),
//           const SizedBox(height: 20),
//           _buildMetaInfo(),
//           const SizedBox(height: 24),
//           _buildActionButtons(),
//           const SizedBox(height: 32),
//           if (widget.video.description.isNotEmpty) _buildDescriptionSection(),
//           if (widget.video.description.isNotEmpty) const SizedBox(height: 32),
//           if (widget.video.actressNames.isNotEmpty) _buildActressSection(),
//           if (widget.video.actressNames.isNotEmpty) const SizedBox(height: 32),
//           if (widget.video.tags.isNotEmpty) _buildTagsSection(),
//         ],
//       ),
//     );
//   }

//   Widget _buildTitleSection() {
//     return SlideTransition(
//       position: _slideAnimation,
//       child: ScaleTransition(
//         scale: _scaleAnimation,
//         child: Container(
//           padding: const EdgeInsets.all(20),
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               colors: [
//                 Colors.pink.withOpacity(0.1),
//                 Colors.purple.withOpacity(0.05),
//               ],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//             borderRadius: BorderRadius.circular(20),
//             border: Border.all(color: Colors.pink.withOpacity(0.2), width: 1),
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 widget.video.title,
//                 style: GoogleFonts.nunito(
//                   color: Colors.white,
//                   fontSize: 32,
//                   fontWeight: FontWeight.w900,
//                   height: 1.2,
//                   letterSpacing: -0.5,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 'Video ID: ${widget.video.id}',
//                 style: GoogleFonts.nunito(
//                   color: Colors.grey[400],
//                   fontSize: 14,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildMetaInfo() {
//     return Wrap(
//       spacing: 20,
//       runSpacing: 12,
//       children: [
//         if (widget.video.rating > 0)
//           _buildMetaChip(
//             icon: Icons.star_rounded,
//             text: widget.video.rating.toStringAsFixed(1),
//             color: Colors.amber,
//           ),
//         _buildMetaChip(
//           icon: Icons.calendar_today_rounded,
//           text: widget.video.releaseDate,
//           color: Colors.blue,
//         ),
//         _buildMetaChip(
//           icon: Icons.schedule_rounded,
//           text: widget.video.formattedDuration,
//           color: Colors.green,
//         ),
//       ],
//     );
//   }

//   Widget _buildMetaChip({
//     required IconData icon,
//     required String text,
//     required Color color,
//   }) {
//     return TweenAnimationBuilder<double>(
//       duration: const Duration(milliseconds: 400),
//       tween: Tween(begin: 0.0, end: 1.0),
//       builder: (context, value, child) {
//         return Transform.scale(
//           scale: value,
//           child: Container(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//               borderRadius: BorderRadius.circular(25),
//               border: Border.all(color: color.withOpacity(0.4), width: 1.5),
//               boxShadow: [
//                 BoxShadow(
//                   color: color.withOpacity(0.2),
//                   blurRadius: 8,
//                   offset: const Offset(0, 2),
//                 ),
//               ],
//             ),
//             child: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(4),
//                   decoration: BoxDecoration(
//                     color: color.withOpacity(0.2),
//                     shape: BoxShape.circle,
//                   ),
//                   child: Icon(icon, color: color, size: 16),
//                 ),
//                 const SizedBox(width: 8),
//                 Text(
//                   text,
//                   style: GoogleFonts.nunito(
//                     color: Colors.white,
//                     fontSize: 14,
//                     fontWeight: FontWeight.w700,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildActionButtons() {
//     return SlideTransition(
//       position: _slideAnimation,
//       child: Column(
//         children: [
//           // Quality selector
//           if (widget.video.memberFiles.isNotEmpty ||
//               widget.video.sampleFiles.isNotEmpty)
//             Container(
//               margin: const EdgeInsets.only(bottom: 16),
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [
//                     Colors.grey[900]!.withOpacity(0.6),
//                     Colors.grey[900]!.withOpacity(0.3),
//                   ],
//                 ),
//                 borderRadius: BorderRadius.circular(16),
//                 border: Border.all(color: Colors.grey[800]!, width: 1),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Select Quality',
//                     style: GoogleFonts.nunito(
//                       color: Colors.white,
//                       fontSize: 14,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   Wrap(
//                     spacing: 8,
//                     runSpacing: 8,
//                     children: _getAvailableQualities().map((quality) {
//                       final isSelected = _selectedQuality == quality;
//                       return GestureDetector(
//                         onTap: () {
//                           setState(() {
//                             _selectedQuality = quality;
//                           });
//                         },
//                         child: Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 16,
//                             vertical: 8,
//                           ),
//                           decoration: BoxDecoration(
//                             gradient: isSelected
//                                 ? LinearGradient(
//                                     colors: [Colors.pink, Colors.purple],
//                                   )
//                                 : null,
//                             color: isSelected ? null : Colors.grey[800],
//                             borderRadius: BorderRadius.circular(20),
//                             border: Border.all(
//                               color: isSelected
//                                   ? Colors.pink
//                                   : Colors.grey[700]!,
//                               width: 1.5,
//                             ),
//                           ),
//                           child: Text(
//                             quality,
//                             style: GoogleFonts.nunito(
//                               color: Colors.white,
//                               fontSize: 12,
//                               fontWeight: isSelected
//                                   ? FontWeight.bold
//                                   : FontWeight.w500,
//                             ),
//                           ),
//                         ),
//                       );
//                     }).toList(),
//                   ),
//                 ],
//               ),
//             ),

//           // Action buttons
//           Row(
//             children: [
//               Expanded(
//                 child: TweenAnimationBuilder<double>(
//                   duration: const Duration(milliseconds: 500),
//                   tween: Tween(begin: 0.0, end: 1.0),
//                   builder: (context, value, child) {
//                     return Transform.scale(
//                       scale: value,
//                       child: Container(
//                         decoration: BoxDecoration(
//                           borderRadius: BorderRadius.circular(20),
//                           gradient: LinearGradient(
//                             colors: [Colors.blue, Colors.blue.shade700],
//                             begin: Alignment.topLeft,
//                             end: Alignment.bottomRight,
//                           ),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.blue.withOpacity(0.4),
//                               blurRadius: 20,
//                               offset: const Offset(0, 8),
//                             ),
//                           ],
//                         ),
//                         child: ElevatedButton.icon(
//                           onPressed: widget.video.sampleFiles.isNotEmpty
//                               ? () => _playSampleVideo()
//                               : null,
//                           icon: Icon(Icons.play_circle_filled, size: 28),
//                           label: Text(
//                             'Play Sample',
//                             style: GoogleFonts.nunito(
//                               fontSize: 17,
//                               fontWeight: FontWeight.w800,
//                               letterSpacing: 0.5,
//                             ),
//                           ),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.transparent,
//                             foregroundColor: Colors.white,
//                             disabledForegroundColor: Colors.white.withOpacity(
//                               0.5,
//                             ),
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 32,
//                               vertical: 18,
//                             ),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(20),
//                             ),
//                             elevation: 0,
//                           ),
//                         ),
//                       ),
//                     );
//                   },
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: TweenAnimationBuilder<double>(
//                   duration: const Duration(milliseconds: 500),
//                   tween: Tween(begin: 0.0, end: 1.0),
//                   builder: (context, value, child) {
//                     return Transform.scale(
//                       scale: value,
//                       child: Container(
//                         decoration: BoxDecoration(
//                           borderRadius: BorderRadius.circular(20),
//                           gradient: LinearGradient(
//                             colors:
//                                 widget.video.canStream &&
//                                     widget.video.memberFiles.isNotEmpty
//                                 ? [Colors.green, Colors.green.shade700]
//                                 : [Colors.grey, Colors.grey.shade700],
//                           ),
//                           boxShadow:
//                               widget.video.canStream &&
//                                   widget.video.memberFiles.isNotEmpty
//                               ? [
//                                   BoxShadow(
//                                     color: Colors.green.withOpacity(0.4),
//                                     blurRadius: 20,
//                                     offset: const Offset(0, 8),
//                                   ),
//                                 ]
//                               : [],
//                         ),
//                         child: ElevatedButton.icon(
//                           onPressed:
//                               widget.video.canStream &&
//                                   widget.video.memberFiles.isNotEmpty
//                               ? () => _playFullVideo()
//                               : null,
//                           icon: Icon(Icons.play_arrow_rounded, size: 28),
//                           label: Text(
//                             'Play Full',
//                             style: GoogleFonts.nunito(
//                               fontSize: 17,
//                               fontWeight: FontWeight.w800,
//                               letterSpacing: 0.5,
//                             ),
//                           ),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.transparent,
//                             foregroundColor: Colors.white,
//                             disabledForegroundColor: Colors.white.withOpacity(
//                               0.5,
//                             ),
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 32,
//                               vertical: 18,
//                             ),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(20),
//                             ),
//                             elevation: 0,
//                           ),
//                         ),
//                       ),
//                     );
//                   },
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   List<String> _getAvailableQualities() {
//     final qualities = <String>{};

//     for (final file in widget.video.sampleFiles) {
//       qualities.add(file.quality);
//     }
//     for (final file in widget.video.memberFiles) {
//       qualities.add(file.quality);
//     }

//     // Sort by quality (highest first)
//     final sortedQualities = qualities.toList();
//     sortedQualities.sort((a, b) {
//       final aValue = int.tryParse(a.replaceAll('p', '')) ?? 0;
//       final bValue = int.tryParse(b.replaceAll('p', '')) ?? 0;
//       return bValue.compareTo(aValue);
//     });

//     return sortedQualities;
//   }

//   String? _getVideoUrl(List<VideoFile> files, String quality) {
//     final file = files.firstWhere(
//       (f) => f.quality == quality,
//       orElse: () => files.isNotEmpty
//           ? files.first
//           : VideoFile(fileName: '', fileSize: 0, url: '', quality: ''),
//     );
//     return file.url.isNotEmpty ? file.url : null;
//   }

//   void _playSampleVideo() {
//     final url = _getVideoUrl(widget.video.sampleFiles, _selectedQuality);

//     if (url == null) {
//       _showErrorSnackBar('Sample video not available for selected quality');
//       return;
//     }

//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => SimpleStreamPlayer(
//           streamUrl: url,
//           movieTitle: '${widget.video.title} (Sample)',
//           isTvShow: false,
//           autoPlay: true,
//         ),
//       ),
//     );
//   }

//   void _playFullVideo() {
//     final url = _getVideoUrl(widget.video.memberFiles, _selectedQuality);

//     if (url == null) {
//       _showErrorSnackBar('Full video not available for selected quality');
//       return;
//     }

//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => SimpleStreamPlayer(
//           streamUrl: url,
//           movieTitle: widget.video.title,
//           isTvShow: false,
//           autoPlay: true,
//           customHeaders: {
//             'Referer': 'https://en.1pondo.tv/',
//             'Origin': 'https://en.1pondo.tv',
//             'User-Agent':
//                 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
//             'Accept': '*/*',
//             'Accept-Encoding': 'identity',
//             'Connection': 'keep-alive',
//           },
//         ),
//       ),
//     );
//   }

//   void _showErrorSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Row(
//           children: [
//             const Icon(Icons.error_outline, color: Colors.white),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Text(
//                 message,
//                 style: GoogleFonts.nunito(color: Colors.white),
//               ),
//             ),
//           ],
//         ),
//         backgroundColor: Colors.red.shade700,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       ),
//     );
//   }

//   void _showComingSoonDialog(String feature) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: Colors.grey[900],
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         title: Text(
//           'Coming Soon',
//           style: GoogleFonts.nunito(
//             color: Colors.white,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         content: Text(
//           '$feature will be available soon!',
//           style: GoogleFonts.nunito(color: Colors.grey[300]),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text(
//               'OK',
//               style: GoogleFonts.nunito(
//                 color: Colors.pink,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildDescriptionSection() {
//     return SlideTransition(
//       position: _slideAnimation,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 width: 4,
//                 height: 28,
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     colors: [Colors.pink, Colors.purple],
//                     begin: Alignment.topCenter,
//                     end: Alignment.bottomCenter,
//                   ),
//                   borderRadius: BorderRadius.circular(2),
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Text(
//                 'Description',
//                 style: GoogleFonts.nunito(
//                   color: Colors.white,
//                   fontSize: 26,
//                   fontWeight: FontWeight.w800,
//                   letterSpacing: -0.5,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           Container(
//             padding: const EdgeInsets.all(24),
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [
//                   Colors.grey[900]!.withOpacity(0.6),
//                   Colors.grey[900]!.withOpacity(0.3),
//                 ],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//               borderRadius: BorderRadius.circular(20),
//               border: Border.all(
//                 color: Colors.grey[800]!.withOpacity(0.5),
//                 width: 1,
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.3),
//                   blurRadius: 20,
//                   offset: const Offset(0, 10),
//                 ),
//               ],
//             ),
//             child: Text(
//               widget.video.description,
//               style: GoogleFonts.nunito(
//                 color: Colors.grey[200],
//                 fontSize: 16,
//                 height: 1.7,
//                 fontWeight: FontWeight.w500,
//                 letterSpacing: 0.2,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildActressSection() {
//     return SlideTransition(
//       position: _slideAnimation,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 width: 4,
//                 height: 28,
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     colors: [Colors.pink, Colors.purple],
//                     begin: Alignment.topCenter,
//                     end: Alignment.bottomCenter,
//                   ),
//                   borderRadius: BorderRadius.circular(2),
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Text(
//                 'Cast',
//                 style: GoogleFonts.nunito(
//                   color: Colors.white,
//                   fontSize: 26,
//                   fontWeight: FontWeight.w800,
//                   letterSpacing: -0.5,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           Wrap(
//             spacing: 12,
//             runSpacing: 12,
//             children: widget.video.actressNames.map((actress) {
//               return Container(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 16,
//                   vertical: 10,
//                 ),
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     colors: [
//                       Colors.pink.withOpacity(0.2),
//                       Colors.purple.withOpacity(0.1),
//                     ],
//                   ),
//                   borderRadius: BorderRadius.circular(20),
//                   border: Border.all(
//                     color: Colors.pink.withOpacity(0.3),
//                     width: 1,
//                   ),
//                 ),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Icon(Icons.person, color: Colors.pink, size: 16),
//                     const SizedBox(width: 8),
//                     Text(
//                       actress,
//                       style: GoogleFonts.nunito(
//                         color: Colors.white,
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ],
//                 ),
//               );
//             }).toList(),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildTagsSection() {
//     return SlideTransition(
//       position: _slideAnimation,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 width: 4,
//                 height: 28,
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     colors: [Colors.pink, Colors.purple],
//                     begin: Alignment.topCenter,
//                     end: Alignment.bottomCenter,
//                   ),
//                   borderRadius: BorderRadius.circular(2),
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Text(
//                 'Tags',
//                 style: GoogleFonts.nunito(
//                   color: Colors.white,
//                   fontSize: 26,
//                   fontWeight: FontWeight.w800,
//                   letterSpacing: -0.5,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           Wrap(
//             spacing: 10,
//             runSpacing: 10,
//             children: widget.video.tags.map((tag) {
//               return Container(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 14,
//                   vertical: 8,
//                 ),
//                 decoration: BoxDecoration(
//                   color: Colors.grey[800]!.withOpacity(0.6),
//                   borderRadius: BorderRadius.circular(18),
//                   border: Border.all(
//                     color: Colors.grey[700]!.withOpacity(0.5),
//                     width: 1,
//                   ),
//                 ),
//                 child: Text(
//                   tag,
//                   style: GoogleFonts.nunito(
//                     color: Colors.grey[300],
//                     fontSize: 13,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               );
//             }).toList(),
//           ),
//         ],
//       ),
//     );
//   }
// }
