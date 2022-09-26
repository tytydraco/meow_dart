import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// A portable YouTube audio archiver.
class MeowDart {
  /// Creates a new [MeowDart] given a directory.
  MeowDart(this.inputDirectory);

  /// The string used to separate the file name and the YouTube id.
  static const fileNameIdSeparator = '~';

  /// The name of the URL file.
  static const urlFileName = '.url';

  /// The target input directory.
  final Directory inputDirectory;

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

  Stream<Video> _getVideosStream(String url) async* {
    final Playlist playlist;

    try {
      // Get the playlist information and contained videos.
      playlist = await _yt.playlists.get(url);
      yield* _yt.playlists.getVideos(playlist.id);
    } catch (_) {
      // Failed to fetch playlist information.
      stdout.write('?');
    }
  }

  Future<void> _downloadVideo(File file, Stream<List<int>> byteStream) async {
    final fileSink = file.openWrite();

    try {
      // Download the stream data to a file.
      await byteStream.pipe(fileSink);
      stdout.write('^');
    } catch (_) {
      // Clean up after an error.
      await fileSink.close();
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

      // Pipe byte stream to file.
      await _downloadVideo(file, byteStream);
    }
  }

  /// Searches recursively for URL files to download from.
  Future<void> archiveDirectory({bool recursive = true}) async {
    // Search recursively for URL files.
    final files = inputDirectory.list(recursive: recursive);
    final urlFiles = await files
        .where((file) => basename(file.path) == urlFileName)
        .toList();

    for (final file in urlFiles) {
      // Get the URLs for all found URL files.
      final urlFile = File(file.path);
      final urlDirectory = urlFile.parent;

      final urls = await urlFile.readAsLines();
      for (final url in urls) {
        final videosStream = _getVideosStream(url);
        await _downloadVideos(urlDirectory, videosStream);
      }
    }

    stdout.writeln();
  }

  /// Download multiple URLs to the specified directory.
  Future<void> archiveUrls(List<String> urls) async {
    for (final url in urls) {
      final videosStream = _getVideosStream(url);
      await _downloadVideos(inputDirectory, videosStream);
    }
  }
}
