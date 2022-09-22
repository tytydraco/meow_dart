import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// A pair between a video and its directory.
class VideoPair {
  /// Creates a new [VideoPair] given a [directory] and a [video].
  VideoPair(this.directory, this.video);

  /// Where this video lives.
  final Directory directory;

  /// The specified video.
  final Video video;
}