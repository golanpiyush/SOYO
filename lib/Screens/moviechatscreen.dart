import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:soyo/Screens/playerScreen.dart';
import 'package:soyo/Services/aimodelapi.dart';
import 'package:soyo/Services/m3u8api.dart';

class MovieChatScreen extends StatefulWidget {
  const MovieChatScreen({super.key});

  @override
  State<MovieChatScreen> createState() => _MovieChatScreenState();
}

class _MovieChatScreenState extends State<MovieChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final M3U8Api _m3u8Api = M3U8Api();

  bool _isLoading = false;
  Map<String, dynamic>? _currentMovieData;
  bool _canSendMessage = true;

  late AnimationController _fabAnimationController;
  late AnimationController _appBarAnimationController;
  late Animation<double> _fabAnimation;
  late Animation<Color?> _appBarColorAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _appBarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fabAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _appBarColorAnimation =
        ColorTween(
          begin: Colors.blue.shade900,
          end: Colors.indigo.shade900,
        ).animate(
          CurvedAnimation(
            parent: _appBarAnimationController,
            curve: Curves.easeInOut,
          ),
        );

    // Start animations
    _fabAnimationController.forward();
    _appBarAnimationController.repeat(reverse: true);

    // Add welcome message with delay for better UX
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _messages.add(
              ChatMessage(
                text:
                    "Hey there! I'm SoyoAI, your personal movie expert. I'm here to help you discover amazing films based on your mood, preferences, or anything you're in the mood for! 🎬\n\nTell me how you're feeling or what kind of movie you'd like to watch. 🐧",
                isUser: false,
                hasAnimated: false,
              ),
            );
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _appBarAnimationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_messageController.text.isEmpty || !_canSendMessage) return;

    String userMessage = _messageController.text;

    setState(() {
      _messages.add(
        ChatMessage(text: userMessage, isUser: true, hasAnimated: true),
      );
      _isLoading = true;
      _canSendMessage = false;
    });

    _messageController.clear();
    _scrollToBottom();

    // Check if user wants to play a movie or TV show
    if (userMessage.toLowerCase().startsWith('play ')) {
      await _handlePlayRequest(userMessage);
    } else {
      // Regular AI conversation
      try {
        final response = await SoyoAiApi.getMovieRecommendation(
          userMessage,
          _messages,
        );

        setState(() {
          _isLoading = false;
          _canSendMessage = true;
          _messages.add(ChatMessage(text: response, isUser: false));
        });

        _scrollToBottom();
      } catch (e) {
        setState(() {
          _isLoading = false;
          _canSendMessage = true;
          _messages.add(
            ChatMessage(
              text:
                  "Sorry, I'm having trouble connecting right now. Please try again.",
              isUser: false,
            ),
          );
        });

        _scrollToBottom();
      }
    }
  }

  Future<void> _handlePlayRequest(String userMessage) async {
    String content = userMessage.substring(5).trim();

    // TV show regex pattern
    RegExp tvRegex = RegExp(r'(.+?)\s+(\d+)\s+(\d+)');
    Match? tvMatch = tvRegex.firstMatch(content);

    if (tvMatch != null) {
      // TV show request
      String showName = tvMatch.group(1)!;
      int season = int.parse(tvMatch.group(2)!);
      int episode = int.parse(tvMatch.group(3)!);

      setState(() {
        _messages.add(
          ChatMessage(
            text: "Searching for $showName Season $season Episode $episode...",
            isUser: false,
            hasAnimated: true,
          ),
        );
      });

      _scrollToBottom();

      try {
        final result = await _m3u8Api.searchTvShow(
          showName: showName,
          season: season,
          episode: episode,
          onStatusUpdate: (status) {
            if (mounted) {
              setState(() {
                if (_messages.isNotEmpty) {
                  _messages.last = ChatMessage(
                    text: "Status: $status",
                    isUser: false,
                    hasAnimated: true,
                  );
                }
              });
              _scrollToBottom();
            }
          },
        );

        // Enrich result with title and metadata
        Map<String, dynamic> enrichedResult = Map.from(result);
        enrichedResult['title'] =
            "$showName S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}";
        enrichedResult['showName'] = showName;
        enrichedResult['season'] = season;
        enrichedResult['episode'] = episode;

        setState(() {
          _isLoading = false;
          _canSendMessage = true;
          _currentMovieData = enrichedResult;
          _messages.add(
            ChatMessage(
              text:
                  "Found $showName S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}! Ready to watch?",
              isUser: false,
              movieData: enrichedResult,
            ),
          );
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
          _canSendMessage = true;
          _messages.add(
            ChatMessage(
              text:
                  "Sorry, I couldn't find that episode. Error: ${e.toString()}",
              isUser: false,
            ),
          );
        });
      }
    } else {
      // Movie request
      setState(() {
        _messages.add(
          ChatMessage(
            text: "Searching for \"$content\"...",
            isUser: false,
            hasAnimated: true,
          ),
        );
      });

      _scrollToBottom();

      try {
        final result = await _m3u8Api.searchMovie(
          movieName: content,
          onStatusUpdate: (status) {
            if (mounted) {
              setState(() {
                if (_messages.isNotEmpty) {
                  _messages.last = ChatMessage(
                    text: "Status: $status",
                    isUser: false,
                    hasAnimated: true,
                  );
                }
              });
              _scrollToBottom();
            }
          },
        );

        // Enrich result with title
        Map<String, dynamic> enrichedResult = Map.from(result);
        enrichedResult['title'] = content;
        enrichedResult['movieName'] = content;

        setState(() {
          _isLoading = false;
          _canSendMessage = true;
          _currentMovieData = enrichedResult;
          _messages.add(
            ChatMessage(
              text: "Found \"$content\"! Ready to watch?",
              isUser: false,
              movieData: enrichedResult,
            ),
          );
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
          _canSendMessage = true;
          _messages.add(
            ChatMessage(
              text: "Sorry, I couldn't find that movie. Error: ${e.toString()}",
              isUser: false,
            ),
          );
        });
      }
    }

    _scrollToBottom();
  }

  void _playMovie(Map<String, dynamic> movieData) {
    // Fix the field mapping
    String streamUrl = movieData['m3u8_link'] ?? '';
    String movieTitle =
        movieData['title'] ?? movieData['movieName'] ?? 'Unknown Movie';

    print('Movie data: $movieData');
    print('Stream URL: $streamUrl');
    print('Movie Title: $movieTitle');

    if (streamUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Text('No stream URL available'),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            SimpleStreamPlayer(streamUrl: streamUrl, movieTitle: movieTitle),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedBuilder(
          animation: _appBarColorAnimation,
          builder: (context, child) {
            return AppBar(
              title: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                child: Text(
                  'SoyO AI 🟢',
                  style: GoogleFonts.cabin(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _appBarColorAnimation.value ?? Colors.blue.shade900,
                      Colors.indigo.shade900,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade800.withOpacity(0.6),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade900.withOpacity(0.9),
              Colors.indigo.shade900.withOpacity(0.9),
              Colors.black.withOpacity(0.95),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: kToolbarHeight + 20),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  if (index < _messages.length) {
                    return AnimatedSlideIn(
                      delay: Duration(milliseconds: index * 100),
                      child: ChatBubble(
                        message: _messages[index].text,
                        isUser: _messages[index].isUser,
                        movieData: _messages[index].movieData,
                        onPlay: _playMovie,
                        hasAnimated: _messages[index].hasAnimated,
                      ),
                    );
                  } else {
                    return const AnimatedSlideIn(
                      child: ChatBubble(
                        message: "Thinking...",
                        isUser: false,
                        isThinking: true,
                        hasAnimated: true,
                      ),
                    );
                  }
                },
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.blue.shade900.withOpacity(0.7),
                    Colors.indigo.shade900.withOpacity(0.8),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, -4),
                  ),
                ],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(
                          _canSendMessage ? 0.1 : 0.05,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade800.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: GoogleFonts.cabin(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              "Describe how you're feeling, request a movie (play moviename), or TV show (play showname season episode)...",
                          hintStyle: GoogleFonts.cabin(
                            color: Colors.blue.shade200.withOpacity(0.8),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                            vertical: 16.0,
                          ),
                          suffixIcon: AnimatedRotation(
                            turns: _canSendMessage ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 300),
                            child: IconButton(
                              icon: Icon(
                                _canSendMessage
                                    ? Icons.mood
                                    : Icons.hourglass_empty,
                                color: Colors.blue.shade300,
                              ),
                              onPressed: () {},
                            ),
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                        maxLines: null,
                        enabled: _canSendMessage,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  ScaleTransition(
                    scale: _fabAnimation,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _canSendMessage
                              ? [Colors.blue.shade600, Colors.blue.shade800]
                              : [Colors.grey.shade600, Colors.grey.shade800],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_canSendMessage
                                        ? Colors.blue.shade800
                                        : Colors.grey.shade800)
                                    .withOpacity(0.6),
                            blurRadius: 8,
                            spreadRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            _canSendMessage ? Icons.send : Icons.access_time,
                            color: Colors.white,
                            key: ValueKey(_canSendMessage),
                          ),
                        ),
                        onPressed: _canSendMessage ? _sendMessage : null,
                        padding: const EdgeInsets.all(14),
                        iconSize: 26,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimatedSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const AnimatedSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  @override
  State<AnimatedSlideIn> createState() => _AnimatedSlideInState();
}

class _AnimatedSlideInState extends State<AnimatedSlideIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(opacity: _fadeAnimation, child: widget.child),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final Map<String, dynamic>? movieData;
  final bool hasAnimated;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.movieData,
    this.hasAnimated = false,
  });
}

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final bool isThinking;
  final Map<String, dynamic>? movieData;
  final Function(Map<String, dynamic>)? onPlay;
  final bool hasAnimated;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.isThinking = false,
    this.movieData,
    this.onPlay,
    this.hasAnimated = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatarWithPulse(),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isUser) _buildNameLabel(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? LinearGradient(
                            colors: [
                              Colors.blue.shade600,
                              Colors.blue.shade800,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          )
                        : LinearGradient(
                            colors: [
                              Colors.indigo.shade700,
                              Colors.indigo.shade900,
                            ],
                          ),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20.0),
                      topRight: const Radius.circular(20.0),
                      bottomLeft: Radius.circular(isUser ? 20.0 : 4.0),
                      bottomRight: Radius.circular(isUser ? 4.0 : 20.0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      isThinking
                          ? const ThinkingAnimation()
                          : hasAnimated
                          ? Text(
                              message,
                              style: GoogleFonts.cabin(
                                color: Colors.white,
                                fontSize: 15,
                                height: 1.4,
                              ),
                            )
                          : TypewriterText(
                              text: message,
                              style: GoogleFonts.cabin(
                                color: Colors.white,
                                fontSize: 15,
                                height: 1.4,
                              ),
                            ),
                      if (movieData != null && onPlay != null)
                        _buildPlayButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 12.0),
          if (isUser) _buildUserAvatar(),
        ],
      ),
    );
  }

  Widget _buildAvatarWithPulse() {
    return TweenAnimationBuilder(
      duration: const Duration(seconds: 2),
      tween: Tween<double>(begin: 0.8, end: 1.0),
      builder: (context, double scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.blue.shade500, Colors.blue.shade700],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade800.withOpacity(0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: Icon(
                      Icons.movie_filter,
                      color: Colors.blue.shade100,
                      size: 22,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.blue.shade500, Colors.indigo.shade700],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade800.withOpacity(0.5),
            blurRadius: 6,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 20),
    );
  }

  Widget _buildNameLabel() {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
      child: Text(
        'SoyoAI',
        style: GoogleFonts.cabin(
          color: Colors.blue.shade300,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPlayButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Stream's Ready",
                    style: GoogleFonts.cabin(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Quality: ${movieData!['quality'] ?? 'Adaptive'}",
                    style: GoogleFonts.cabin(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedScale(
              scale: 1.0,
              duration: const Duration(milliseconds: 200),
              child: ElevatedButton.icon(
                onPressed: () => onPlay!(movieData!),
                icon: const Icon(Icons.play_arrow, size: 20),
                label: Text("Play", style: GoogleFonts.cabin()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration speed;

  const TypewriterText({
    super.key,
    required this.text,
    required this.style,
    this.speed = const Duration(milliseconds: 20),
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  late String _displayText;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _displayText = "";
    _currentIndex = 0;
    _startTyping();
  }

  void _startTyping() {
    Future.delayed(widget.speed, () {
      if (mounted && _currentIndex < widget.text.length) {
        setState(() {
          _displayText += widget.text[_currentIndex];
          _currentIndex++;
        });
        _startTyping();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(_displayText, style: widget.style);
  }
}

class ThinkingAnimation extends StatefulWidget {
  const ThinkingAnimation({super.key});

  @override
  State<ThinkingAnimation> createState() => _ThinkingAnimationState();
}

class _ThinkingAnimationState extends State<ThinkingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Thinking",
            style: GoogleFonts.cabin(
              color: Colors.blue.shade200,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.blue.shade200,
            ),
          ),
        ],
      ),
    );
  }
}
