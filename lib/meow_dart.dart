import 'dart:async';
import 'dart:io';

import 'package:meow_dart/src/downloader_spawner.dart';
import 'package:path/path.dart';
import 'package:stdlog/stdlog.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// A portable YouTube audio archiver.
class MeowDart {
  /// Creates a new [MeowDart] given a directory.
  MeowDart(
    this.inputDirectory, {
    required this.maxConcurrent,
  });

  /// The target input directory.
  final Directory inputDirectory;

  /// The maximum number of concurrent downloads to do at once.
  final int maxConcurrent;

  /// The name of the URL file.
  static const urlFileName = '.url';

  final _yt = YoutubeExplode();
  late final _downloaderSpawner = DownloaderSpawner(maxConcurrent);

  /// Returns a stream of videos from the playlist URL.
  Stream<Video> _getVideosFromPlaylist(String url) async* {
    final Playlist playlist;

    try {
      // Get the playlist information and contained videos.
      playlist = await _yt.playlists.get(url);
      yield* _yt.playlists.getVideos(playlist.id);
    } catch (_) {
      // Failed to fetch playlist information.
      error('Unable to get playlist information: $url');
    }
  }

  /// Searches recursively for URL files to download from.
  Future<void> archiveDirectory({bool recursive = true}) async {
    // Search recursively for URL files.
    final files = inputDirectory.list(recursive: recursive);
    final urlFiles = await files
        .where((file) => basename(file.path) == urlFileName)
        .toList();

    // Get the URLs for all found URL files.
    for (final file in urlFiles) {
      final urlFile = File(file.path);
      final urlDirectory = urlFile.parent;
      final urls = await urlFile.readAsLines();

      /// Download all of the videos for these URLs.
      for (final url in urls) {
        final videosStream = _getVideosFromPlaylist(url);
        await for (final video in videosStream) {
          await _downloaderSpawner.spawnDownloader(video, urlDirectory);
        }
      }
    }
  }

  /// Download multiple URLs to the specified directory.
  Future<void> archiveUrls(List<String> urls) async {
    for (final url in urls) {
      final videosStream = _getVideosFromPlaylist(url);
      await for (final video in videosStream) {
        await _downloaderSpawner.spawnDownloader(video, inputDirectory);
      }
    }
  }
}
