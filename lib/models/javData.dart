class JAVVideo {
  final String id;
  final String title;
  final String posterUrl;
  final String duration;
  final String uploadDate;
  final String code;
  final String pageUrl;

  JAVVideo({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.duration,
    required this.uploadDate,
    required this.code,
    required this.pageUrl,
  });

  // Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'posterUrl': posterUrl,
      'duration': duration,
      'uploadDate': uploadDate,
      'code': code,
      'pageUrl': pageUrl,
    };
  }

  // Create from JSON for caching
  factory JAVVideo.fromJson(Map<String, dynamic> json) {
    return JAVVideo(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      posterUrl: json['posterUrl'] ?? '',
      duration: json['duration'] ?? '',
      uploadDate: json['uploadDate'] ?? '',
      code: json['code'] ?? '',
      pageUrl: json['pageUrl'] ?? '',
    );
  }
}
