import 'dart:async';

import 'package:meow_dart/src/downloader_spawner.dart';
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

  /// Download a video to the specified directory.
  Future<void> archiveVideo(String url) async {
    final video = await _yt.videos.get(url);
    await spawner.spawnDownloader(video.id.value);
  }

  /// Download a playlist to the specified directory.
  Future<void> archivePlaylist(String url) async {
    final playlist = await _yt.playlists.get(url);
    final videosStream = _yt.playlists.getVideos(playlist.id);

    await for (final video in videosStream) {
      await spawner.spawnDownloader(video.id.value);
    }
  }
}
