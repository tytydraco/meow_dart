import 'dart:io';

import 'package:meow_dart/src/archiver.dart';
import 'package:meow_dart/src/files.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// A portable YouTube audio archiver.
class MeowDart {
  /// Creates a new [MeowDart] given a [directory].
  MeowDart(this.directory);

  /// The input directory to use.
  final Directory directory;

  late final Files _files = Files(directory);
  late final Archiver _archiver = Archiver(_files);

  /// Downloads the highest quality audio, skipping tracks that have already
  /// been downloaded.
  Future<void> archive() async {
    final urls = await _files.getUrls();
    await _files.scan();

    // Get the full list of videos.
    final videos = <Video>{};
    for (final url in urls) {
      final playlist = await _archiver.yt.playlists.get(url);
      final videosPart =
          await _archiver.yt.playlists.getVideos(playlist.id).toList();
      videos.addAll(videosPart);
    }

    // Download in parallel.
    await Future.wait(videos.map(_archiver.archiveAudio));
  }
}
