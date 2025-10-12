import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:soyo/Screens/ExploreMovies.dart';
import 'package:soyo/Screens/homescreen.dart';
import 'package:soyo/Screens/savedscreen.dart';
import 'package:soyo/Screens/settingsScreen.dart';
import 'package:soyo/Services/Providers/settings_provider.dart';
import 'package:soyo/Services/exploreapi.dart';
import 'package:soyo/Services/update_checker_wrapper.dart';
import 'package:soyo/Services/exploretvapi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load cache
  await ExploreApi.loadCacheFromDisk();

  // Initialize settings provider
  final settingsProvider = SettingsProvider();
  await settingsProvider.loadSettings();

  runApp(
    ChangeNotifierProvider.value(
      value: settingsProvider,
      child: UpdateCheckerWrapper(
        githubRepo: 'golanpiyush/SOYO',
        child: MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SOYO',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  var _bottomNavIndex = 0;

  final iconList = <IconData>[
    Icons.home,
    Icons.bookmark,
    Icons.explore,
    Icons.settings,
  ];

  final List<Widget> _screens = [
    HomeScreen(),
    SavedScreen(),
    ExploreScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    ExploreApi.preloadPopularContent();
    ExploreTvApi.getAllProviderShows();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _bottomNavIndex, children: _screens),
      bottomNavigationBar: CustomAnimatedBottomNav(
        currentIndex: _bottomNavIndex,
        icons: iconList,
        onTap: (index) => setState(() => _bottomNavIndex = index),
      ),
    );
  }
}

class CustomAnimatedBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<IconData> icons;
  final Function(int) onTap;

  const CustomAnimatedBottomNav({
    Key? key,
    required this.currentIndex,
    required this.icons,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(
            icons.length,
            (index) => _buildNavItem(index),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final isActive = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: Container(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: isActive ? 4 : 0,
                  width: 30,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 216, 244, 54),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: isActive ? 1.0 : 0.0),
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 1.0 + (value * 0.15),
                      child: Icon(
                        icons[index],
                        color: Color.lerp(Colors.grey[600], Colors.red, value),
                        size: 26,
                      ),
                    );
                  },
                ),
                SizedBox(height: 4),
                AnimatedOpacity(
                  duration: Duration(milliseconds: 300),
                  opacity: isActive ? 1.0 : 0.0,
                  child: Container(
                    height: 4,
                    width: 4,
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 60, 244, 54),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
