import 'dart:io';

import 'package:meow_dart/src/files.dart';
import 'package:path/path.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// A portable YouTube audio archiver.
class MeowDart {
  /// Creates a new [MeowDart] given a [directory].
  MeowDart(this.directory);

  /// The input directory to use.
  final Directory directory;

  late final Files _files = Files(directory);

  /// The string used to separate the file name and the YouTube id.
  static const fileNameIdSeparator = '~';

  /// The [YoutubeExplode] instance.
  final _yt = YoutubeExplode();

  String _getFormattedFileName(Video video, AudioStreamInfo audioStream) {
    final fileExtension = audioStream.container.name;
    return '${video.title}'
        ' $fileNameIdSeparator '
        '${video.id.value}'
        '.$fileExtension';
  }

  Future<AudioStreamInfo> _getBestAudioStream(Video video) async {
    final manifest = await _yt.videos.streamsClient.getManifest(video.id);
    return manifest.audioOnly.sortByBitrate().first;
  }

  Future<void> _archiveAudio(Video video) async {
    final audioStream = await _getBestAudioStream(video);
    final byteStream = _yt.videos.streamsClient.get(audioStream);
    final fileName = _getFormattedFileName(video, audioStream);
    final file = File(join(_files.directory.path, fileName));

    // Check if we already have this one.
    if (_files.containsFile(file)) {
      stdout.write('.');
    } else {
      _files.addCachedFile(file);
      await byteStream.pipe(file.openWrite());
      stdout.write('!');
    }
  }

  /// Downloads the highest quality audio, skipping tracks that have already
  /// been downloaded.
  Future<void> archive() async {
    final urls = await _files.getUrls();
    await _files.scan();

    // Get the full list of videos.
    final videos = <Video>{};
    for (final url in urls) {
      final playlist = await _yt.playlists.get(url);
      final videosPart = await _yt.playlists.getVideos(playlist.id).toList();
      videos.addAll(videosPart);
    }

    // Download in parallel.
    await Future.wait(videos.map(_archiveAudio));
  }
}
