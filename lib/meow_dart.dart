import 'dart:async';
import 'dart:io';

import 'package:meow_dart/src/video_pair.dart';
import 'package:path/path.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// A portable YouTube audio archiver.
class MeowDart {
  /// The string used to separate the file name and the YouTube id.
  static const fileNameIdSeparator = '~';

  /// The name of the URL file.
  static const urlFileName = '.url';

  final _yt = YoutubeExplode();

  File _getFile(
    Directory directory,
    Video video,
    AudioStreamInfo audioStream,
  ) {
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
  Future<void> archive(Directory directory) async {
    final files = directory.list(recursive: true);
    final urlFiles = files.where((file) => basename(file.path) == urlFileName);

    // The map between videos and the parent directory for their file.
    final videos = <VideoPair>[];

    // Get the URLs for all found URL files.
    await for (final urlFileSystemEntity in urlFiles) {
      final urlFile = File(urlFileSystemEntity.path);
      final urlDirectory = urlFile.parent;
      final urls = await urlFile.readAsLines();

      // Add the videos from the URLs to the map.
      for (final url in urls) {
        final playlist = await _yt.playlists.get(url);
        final videosStream = _yt.playlists.getVideos(playlist.id);

        await for (final part in videosStream) {
          stdout.write('|');
          videos.add(VideoPair(urlDirectory, part));
        }
      }
    }

    stdout.write('\r');

    await Future.wait(
      videos.map((pair) async {
        final audioStream = await _getBestAudioStream(pair.video);
        final byteStream = _yt.videos.streamsClient.get(audioStream);
        final file = _getFile(pair.directory, pair.video, audioStream);

        // Check if we already have this one.
        if (file.existsSync()) {
          stdout.write('.');
        } else {
          await byteStream.pipe(file.openWrite());
          stdout.write('^');
        }
      }),
    );

    stdout.writeln();
  }
}
