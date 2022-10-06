import 'dart:async';

import 'package:meow_dart/src/data/result.dart';
import 'package:meow_dart/src/downloader_spawner.dart';
import 'package:stdlog/stdlog.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

export 'src/data/config.dart';
export 'src/data/format.dart';
export 'src/downloader_spawner.dart';

/// A portable YouTube archiver.
class MeowDart {
  /// Creates a new [MeowDart] given a [spawner].
  MeowDart({required this.spawner});

  /// The downloader spawner to use.
  final DownloaderSpawner spawner;

  /// The YouTube downloader instance used only to get metadata.
  final _yt = YoutubeExplode();

  /// Output the result of the download.
  void _handleResult(String videoId, Result result) {
    switch (result) {
      case Result.badStream:
        error('$videoId\tFailed to fetch the audio stream.');
        break;
      case Result.badWrite:
        error('$videoId\tFailed to write the output content.');
        break;
      case Result.badCommand:
        warn('$videoId\tA command finished with a non-zero exit code.');
        break;
      case Result.fileExists:
        debug('$videoId\tAlready downloaded.');
        break;
      case Result.success:
        info('$videoId\tDownloaded successfully.');
        break;
    }
  }

  /// Download a video to the specified directory.
  Future<void> archiveVideo(String id) async {
    await spawner.spawnDownloader(
      id,
      resultHandler: (result) => _handleResult(id, result),
    );
  }

  /// Download a playlist to the specified directory.
  Future<void> archivePlaylist(String id) async {
    final videosStream = _yt.playlists.getVideos(id);

    await for (final video in videosStream) {
      await archiveVideo(video.id.value);
    }
  }

  /// Closes the YouTube client.
  void dispose() => _yt.close();
}
