import 'dart:async';
import 'dart:io';

import 'package:meow_dart/src/downloader_config.dart';
import 'package:meow_dart/src/downloader_spawner.dart';
import 'package:meow_dart/src/format.dart';
import 'package:stdlog/stdlog.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// A portable YouTube archiver.
class MeowDart {
  /// Creates a new [MeowDart] given a directory.
  MeowDart(
    this.inputDirectory, {
    required this.maxConcurrent,
    this.format = Format.muxed,
    this.command,
  });

  /// The target input directory.
  final Directory inputDirectory;

  /// The maximum number of concurrent downloads to do at once.
  final int maxConcurrent;

  /// The download format type.
  final Format format;

  /// A command to run after a download has been completed.
  final String? command;

  /// The YouTube downloader instance used only to get playlist information.
  final _yt = YoutubeExplode();

  /// The download spawner to handle threaded downloads.
  late final _downloaderSpawner = DownloaderSpawner();

  /// A SIGINT handler to cancel additional downloads.
  late final _exitHandler =
      ProcessSignal.sigint.watch().listen(_handleExitSignal);

  /// Stop all requests if there is an exit request.
  Future<void> _handleExitSignal(ProcessSignal signal) async {
    error('Halt! Waiting for current downloads to finish.');
    await _downloaderSpawner.close();
    exit(0);
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

  /// Download a playlist to the specified directory.
  Future<void> archivePlaylist(String url) async {
    final videosStream = _getVideosFromPlaylist(url);
    await for (final video in videosStream) {
      await _downloaderSpawner.spawnDownloader(
        DownloaderConfig(
          videoId: video.id.value,
          directory: inputDirectory,
          format: format,
          command: command,
        ),
      );
    }

    // Cancel the exit handler so we can exit gracefully.
    await _exitHandler.cancel();
  }
}
