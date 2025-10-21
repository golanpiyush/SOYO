# 🎬 SOYO (Stream On Your Own)
 
<div align="center">
  <img src="assets/icon/app_icon.png" alt="Soyo App Logo" width="120" height="120" style="border-radius: 20px;">
  
  [![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev/)
  [![Dart](https://img.shields.io/badge/Dart-3.0+-blue.svg)](https://dart.dev/)
  [![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green.svg)](https://flutter.dev/)
  [![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
  [![Stars](https://img.shields.io/github/stars/golanpiyush/SOYO?style=social)](https://github.com/golanpiyush/SOYO/stargazers)
</div>

## 🌐 API Status
<div align="center">
| Category | Status |
|-----------|---------|
| 🎬 **Movies** | [![Movies API](https://img.shields.io/website?url=https%3A%2F%2Fdb.cineby.app%2F3&label=Movies&up_message=Online&down_message=Offline&style=for-the-badge&logo=playstation&color=brightgreen)](https://db.cineby.app/3) |
| 📺 **TV Shows** | [![TV Shows API](https://img.shields.io/website?url=https%3A%2F%2Fcinemaos.me%2F&label=TV%20Shows&up_message=Online&down_message=Offline&style=for-the-badge&logo=appletv&color=brightgreen)](https://cinemaos.me/) |
| 🎌 **Anime** | [![Anime API](https://img.shields.io/website?url=https%3A%2F%2Fflixer.su%2F&label=Anime&up_message=Online&down_message=Offline&style=for-the-badge&logo=crunchyroll&color=brightgreen)](https://flixer.su/) |
| 🔞 **NSFW** | [![NSFW API](https://img.shields.io/website?url=https%3A%2F%2Fxhamster44.desi%2F&label=NSFW&up_message=Online&down_message=Offline&style=for-the-badge&logo=firefox&color=brightgreen)](https://xhamster44.desi/) |


**SOYO** is a modern, feature-rich streaming application built with Flutter that provides seamless access to movies and TV shows from multiple streaming platforms. Experience cinema in your pocket with stunning animations, intuitive design, and powerful streaming capabilities.

## ✨ Features

### 🎭 Content Discovery
- **Movie Explorer**: Browse popular, top-rated, and genre-specific movies
- **TV Shows Hub**: Discover content from Netflix, Apple TV+, Prime Video, Disney+, HBO Max, Hulu, and Paramount+
- **Genre Categories**: Horror, Action, Sci-Fi, Comedy, Thriller, Animation, and more
- **Smart Search**: Find your favorite content quickly and efficiently

### 🚀 Performance & Caching
- **6-Hour Smart Cache**: Intelligent caching system that stores data locally for 6 hours
- **Offline Browsing**: View previously loaded content without internet connection
- **Pull-to-Refresh**: Force refresh content when needed
- **Optimized Loading**: Shimmer loading effects and smooth animations

### 🎨 User Experience
- **Stunning UI**: Dark gradient themes with glassmorphism effects
- **Smooth Animations**: Hero transitions, fade effects, and elastic animations
- **Responsive Design**: Optimized for all screen sizes
- **Intuitive Navigation**: Easy-to-use interface with visual feedback

### 📱 Streaming Features
- **M3U8 Support**: Native support for HLS streaming
- **Subtitle Integration**: Multiple subtitle language support
- **Quality Selection**: Adaptive streaming quality
- **Picture-in-Picture**: Continue watching while using other apps


### API Integration
The app integrates with multiple APIs for comprehensive content discovery:

- **TMDB API**: Movie and TV show metadata
- **CinemaOS API**: Streaming provider integration
- **M3U8 Streaming**: Direct video stream access


## 🛠️ Installation
- Flutter SDK (3.0 or higher)
- Dart SDK (3.0 or higher)
- Android Studio / Xcode
- Git

### Setup
1. **Clone the repository**
   ```bash
   git clone https://github.com/golanpiyush/SOYO.git
   cd soyo-stream
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
    // Latest
  http:
  intl:
  animated_bottom_navigation_bar:
  google_fonts:
  pod_player:
  webview_flutter:
  chewie: 
  url_launcher:
  flutter_inappwebview:
  shared_preferences:
  cached_network_image:
  flutter_svg:
  path_provider:
  volume_controller:
  screen_brightness:
  
```


## 🔧 Configuration

### API Setup
1. Configure your API endpoints in the service files
2. Update base URLs if using different API providers
3. Set up authentication tokens if required

### Customization
- **Themes**: Modify gradient colors in screen files
- **Animations**: Adjust animation durations and curves
- **Cache Duration**: Change cache expiration time in API services

## 🎯 How It Works

### Content Discovery Flow
1. **App Launch**: Loads cached data if available, otherwise fetches fresh content
2. **Category Browsing**: Users can explore different genres and streaming platforms
3. **Smart Caching**: Content is automatically cached for 6 hours to improve performance
4. **Detail Navigation**: Tap any content to view detailed information

### Streaming Process
1. **Content Selection**: User selects a movie or show
2. **Stream Search**: App searches for available streaming links
3. **Quality Detection**: Automatically detects best available quality
4. **Playback**: Launches integrated player with subtitle support


## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Follow Flutter/Dart style guidelines
- Write meaningful commit messages
- Test your changes thoroughly
- Update documentation as needed

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Language Guide](https://dart.dev/guides)
- [Material Design](https://material.io/)

## 📞 Support

If you encounter any issues or have questions:

- Open an issue on GitHub
- Check the documentation
- Review existing issues for solutions

---

<div align="center">
  <p>Made with ❤️ using Flutter</p>
  <p>⭐ Star this repo if you found it helpful!</p>
</div>
