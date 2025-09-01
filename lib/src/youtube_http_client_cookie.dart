import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// A [YoutubeHttpClient] that supports a user cookie.
class YoutubeHttpClientCookie extends YoutubeHttpClient {
  /// Creates a new [YoutubeHttpClientCookie] given a [cookie].
  YoutubeHttpClientCookie({required this.cookie});

  /// The user cookie to use.
  final String? cookie;

  @override
  Map<String, String> get headers {
    final superHeaders = super.headers;
    if (cookie != null) superHeaders['cookie'] = cookie!;
    return superHeaders;
  }
}
