import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
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

  Stream<Video> _getVideosStreams(File urlFile) async* {
    final urls = await urlFile.readAsLines();
    final videosStreams = StreamGroup<Video>();

    // Get all of the video streams for this URL file.
    for (final url in urls) {
      final Playlist playlist;

      try {
        // Get the playlist information and contained videos.
        playlist = await _yt.playlists.get(url);
        final videosStream = _yt.playlists.getVideos(playlist.id);
        await videosStreams.add(videosStream);
      } catch (_) {
        // Failed to fetch playlist information.
        stdout.write('?');
        continue;
      }
    }

    yield* videosStreams.stream;
  }

  Future<void> _downloadVideos(
    Directory urlDirectory,
    Stream<Video> videosStreams,
  ) async {
    await videosStreams.forEach((video) async {
      final AudioStreamInfo audioStream;
      final Stream<List<int>> byteStream;

      try {
        // Get the stream metadata and byte stream.
        audioStream = await _getBestAudioStream(video);
        byteStream = _yt.videos.streamsClient.get(audioStream);
      } catch (_) {
        // Failed to fetch stream info.
        stdout.write('!');
        return;
      }

      // Figure out where to put this file.
      final file = _getFile(urlDirectory, video, audioStream);

      // Check if we already have this one in case we can skip.
      if (file.existsSync()) {
        stdout.write('.');
        return;
      }

      try {
        // Pipe byte stream to file in parallel.
        unawaited(byteStream.pipe(file.openWrite()));
      } catch (_) {
        // Delete partial downloads.
        stdout.write('!');
        if (file.existsSync()) unawaited(file.delete());
        return;
      }

      stdout.write('^');
    });
  }

  /// Downloads the highest quality audio, skipping tracks that have already
  /// been downloaded.
  Future<void> archive(Directory directory) async {
    // Search recursively for URL files.
    final files = directory.list(recursive: true);

    // Create a list of download jobs.
    final jobs =
        files.where((file) => basename(file.path) == urlFileName).map((file) {
      // Get the URLs for all found URL files.
      final urlFile = File(file.path);
      final urlDirectory = urlFile.parent;
      final videosStreams = _getVideosStreams(urlFile);

      // Download each file that we can simultaneously.
      return _downloadVideos(urlDirectory, videosStreams);
    });

    // Start all the jobs at once and wait for them to finish.
    await Future.wait(await jobs.toList());

    stdout.writeln();
  }
}
