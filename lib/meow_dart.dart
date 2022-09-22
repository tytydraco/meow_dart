import 'dart:async';
import 'dart:io';

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
    final path = '${video.title.replaceAll('/', '')}'
        ' $fileNameIdSeparator '
        '${video.id.value}'
        '.$fileExtension';
    return File(join(directory.path, path));
  }

  Future<AudioStreamInfo> _getBestAudioStream(Video video) async {
    final manifest = await _yt.videos.streamsClient.getManifest(video.id);
    return manifest.audioOnly.sortByBitrate().first;
  }

  Future<void> _archiveAudio(Directory urlDirectory, Video video) async {
    // Get the stream metadata and byte stream.
    final audioStream = await _getBestAudioStream(video);

    final byteStream = _yt.videos.streamsClient.get(audioStream);

    // Figure out where to put this file.
    final file = _getFile(urlDirectory, video, audioStream);

    // Check if we already have this one.
    if (file.existsSync()) {
      stdout.write('.');
    } else {
      await byteStream.pipe(file.openWrite());
      stdout.write('^');
    }
  }

  Future<void> _archiveUrl(Directory urlDirectory, String url) async {
    final playlist = await _yt.playlists.get(url);
    final videosStream = _yt.playlists.getVideos(playlist.id);

    // Download each file that we can.
    unawaited(
      videosStream.forEach((video) async {
        try {
          await _archiveAudio(urlDirectory, video);
        } catch (e) {
          stdout.write('!');
        }
      }),
    );
  }

  /// Downloads the highest quality audio, skipping tracks that have already
  /// been downloaded.
  Future<void> archive(Directory directory) async {
    final files = directory.list(recursive: true);
    final urlFiles = files.where((file) => basename(file.path) == urlFileName);

    // Get the URLs for all found URL files.
    await for (final urlFileSystemEntity in urlFiles) {
      final urlFile = File(urlFileSystemEntity.path);
      final urlDirectory = urlFile.parent;
      final urls = await urlFile.readAsLines();

      // Archive these tracks.
      for (final url in urls) {
        try {
          unawaited(_archiveUrl(urlDirectory, url));
        } catch (e) {
          stdout.write('?');
        }
      }
    }

    stdout.writeln();
  }
}
