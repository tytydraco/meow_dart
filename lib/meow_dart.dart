import 'dart:async';
import 'dart:io';

import 'package:meow_dart/src/downloader_config.dart';
import 'package:meow_dart/src/downloader_spawner.dart';
import 'package:stdlog/stdlog.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

export 'src/format.dart';

/// A portable YouTube archiver.
class MeowDart {
  /// Creates a new [MeowDart] given a directory.
  MeowDart({
    required this.config,
    required this.spawner,
  });

  /// The downloader config to use.
  final DownloaderConfig config;

  /// The downloader spawner to use.
  final DownloaderSpawner spawner;

  /// The YouTube downloader instance used only to get metadata.
  final _yt = YoutubeExplode();

  /// Register a SIGINT handler to cancel additional downloads.
  StreamSubscription<void> registerExitHandler() =>
      ProcessSignal.sigint.watch().listen(_handleExitSignal);

  /// Stop all requests if there is an exit request.
  Future<void> _handleExitSignal(ProcessSignal signal) async {
    error('Halt! Waiting for current downloads to finish.');
    await spawner.close();
    exit(0);
  }

  /// Download a video to the specified directory.
  Future<void> archiveVideo(String url) async {
    final video = await _yt.videos.get(url);
    await spawner.spawnDownloader(config, videoId: video.id.value);
  }

  /// Download a playlist to the specified directory.
  Future<void> archivePlaylist(String url) async {
    final playlist = await _yt.playlists.get(url);
    final videosStream = _yt.playlists.getVideos(playlist.id);

    await for (final video in videosStream) {
      await spawner.spawnDownloader(config, videoId: video.id.value);
    }
  }
}
