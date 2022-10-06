import 'dart:async';

import 'package:meow_dart/src/downloader_result.dart';
import 'package:meow_dart/src/downloader_spawner.dart';
import 'package:stdlog/stdlog.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

export 'src/format.dart';

/// A portable YouTube archiver.
class MeowDart {
  /// Creates a new [MeowDart] given a directory.
  MeowDart({
    required this.spawner,
  });

  /// The downloader spawner to use.
  final DownloaderSpawner spawner;

  /// The YouTube downloader instance used only to get metadata.
  final _yt = YoutubeExplode();

  /// Output the result of the download.
  void _handleResult(String videoId, DownloaderResult result) {
    switch (result) {
      case DownloaderResult.badStream:
        error('$videoId\tFailed to fetch the audio stream.');
        break;
      case DownloaderResult.badWrite:
        error('$videoId\tFailed to write the output content.');
        break;
      case DownloaderResult.badCommand:
        warn('$videoId\tA command finished with a non-zero exit code.');
        break;
      case DownloaderResult.fileExists:
        debug('$videoId\tAlready downloaded.');
        break;
      case DownloaderResult.success:
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
