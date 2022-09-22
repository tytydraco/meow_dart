import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// A portable YouTube audio archiver.
class MeowDart {
  /// Creates a new [MeowDart] given a [directory].
  MeowDart(this.directory);

  /// The input directory to use.
  final Directory directory;

  /// The string used to separate the file name and the YouTube id.
  static const fileNameIdSeparator = '~';

  final _yt = YoutubeExplode();

  File _getFile(Video video, AudioStreamInfo audioStream) {
    final fileExtension = audioStream.container.name;
    final path = '${video.title}'
        ' $fileNameIdSeparator '
        '${video.id.value}'
        '.$fileExtension';
    return File(join(directory.path, path));
  }

  Future<AudioStreamInfo> _getBestAudioStream(Video video) async {
    final manifest = await _yt.videos.streamsClient.getManifest(video.id);
    return manifest.audioOnly.sortByBitrate().first;
  }

  /// Downloads the highest quality audio, skipping tracks that have already
  /// been downloaded.
  Future<void> archive(List<String> urls) async {
    // Get the full list of videos.
    final videos = <Video>{};
    for (final url in urls) {
      final playlist = await _yt.playlists.get(url);
      final videosStream = _yt.playlists.getVideos(playlist.id);

      await for (final part in videosStream) {
        stdout.write('|');
        videos.add(part);
      }
    }

    stdout.write('\r');

    // Download in parallel.
    await Future.wait(videos.map((video) async {
      final audioStream = await _getBestAudioStream(video);
      final byteStream = _yt.videos.streamsClient.get(audioStream);
      final file = _getFile(video, audioStream);

      // Check if we already have this one.
      if (file.existsSync()) {
        stdout.write('.');
      } else {
        await byteStream.pipe(file.openWrite());
        stdout.write('^');
      }
    }));

    stdout.writeln();
  }
}
