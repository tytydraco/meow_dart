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

  Stream<Video> _getVideosStreams(File urlFile) async* {
    final urls = await urlFile.readAsLines();

    // Get all of the video streams for this URL file.
    for (final url in urls) {
      final Playlist playlist;

      try {
        // Get the playlist information and contained videos.
        playlist = await _yt.playlists.get(url);
        yield* _yt.playlists.getVideos(playlist.id);
      } catch (_) {
        // Failed to fetch playlist information.
        stdout.write('?');
        continue;
      }
    }
  }

  Future<void> _downloadVideo(File file, Stream<List<int>> byteStream) async {
    try {
      // Download the stream data to a file.
      await byteStream.pipe(file.openWrite());
      stdout.write('^');
    } catch (_) {
      // Clean up after an error.
      if (file.existsSync()) await file.delete();
      stdout.write('!');
    }
  }

  Future<void> _downloadVideos(
    Directory urlDirectory,
    Stream<Video> videosStreams,
  ) async {
    await for (final video in videosStreams) {
      final AudioStreamInfo audioStream;
      final Stream<List<int>> byteStream;

      try {
        // Get the stream metadata and byte stream.
        audioStream = await _getBestAudioStream(video);
        byteStream = _yt.videos.streamsClient.get(audioStream);
      } catch (_) {
        // Failed to fetch stream info.
        stdout.write('!');
        continue;
      }

      // Figure out where to put this file.
      final file = _getFile(urlDirectory, video, audioStream);

      // Check if we already have this one in case we can skip.
      if (file.existsSync()) {
        stdout.write('.');
        continue;
      }

      // Pipe byte stream to file in pooled parallel.
      await _downloadVideo(file, byteStream);
    }
  }

  /// Downloads the highest quality audio, skipping tracks that have already
  /// been downloaded.
  Future<void> archive(Directory directory) async {
    // Search recursively for URL files.
    final files = directory.list(recursive: true);
    final urlFiles = await files
        .where((file) => basename(file.path) == urlFileName)
        .toList();

    for (final file in urlFiles) {
      // Get the URLs for all found URL files.
      final urlFile = File(file.path);
      final urlDirectory = urlFile.parent;
      final videosStreams = _getVideosStreams(urlFile);

      // Download each file that we can simultaneously.
      await _downloadVideos(urlDirectory, videosStreams);
    }
  }
}
