import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:meow_dart/src/download_result.dart';
import 'package:meow_dart/src/downloader.dart';
import 'package:path/path.dart';
import 'package:pool/pool.dart';
import 'package:stdlog/stdlog.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// A portable YouTube audio archiver.
class MeowDart {
  /// Creates a new [MeowDart] given a directory.
  MeowDart(this.inputDirectory);

  /// The target input directory.
  final Directory inputDirectory;

  /// The name of the URL file.
  static const urlFileName = '.url';

  final _yt = YoutubeExplode();
  final _pool = Pool(8);

  /// Spawn a new isolate to download this video.
  Future<void> _spawnDownloader(Video video, Directory directory) async {
    final poolResource = await _pool.request();

    final receivePort = RawReceivePort()
      ..handler = (_) => poolResource.release();

    await Isolate.spawn(
      (List<Object> args) async {
        final sendPort = args[0] as SendPort;
        final videoId = args[1] as String;
        final directoryPath = args[2] as String;

        final downloader = Downloader(
          videoId: videoId,
          directoryPath: directoryPath,
        );
        final result = await downloader.download();
        switch (result) {
          case DownloadResult.badStream:
            error('$videoId\tFailed to fetch the audio stream.');
            break;
          case DownloadResult.badWrite:
            error('$videoId\tFailed to write the output content.');
            break;
          case DownloadResult.fileExists:
            debug('$videoId\tAlready downloaded.');
            break;
          case DownloadResult.success:
            info('$videoId\tDownloaded successfully.');
            break;
        }

        sendPort.send(null);
      },
      [receivePort.sendPort, video.id.value, directory.path],
      onError: receivePort.sendPort,
    );
  }

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
          await _spawnDownloader(video, urlDirectory);
        }
      }
    }
  }

  /// Download multiple URLs to the specified directory.
  Future<void> archiveUrls(List<String> urls) async {
    for (final url in urls) {
      final videosStream = _getVideosFromPlaylist(url);
      await for (final video in videosStream) {
        await _spawnDownloader(video, inputDirectory);
      }
    }
  }
}
