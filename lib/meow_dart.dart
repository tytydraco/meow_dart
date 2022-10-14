import 'dart:async';
import 'dart:collection';

import 'package:meow_dart/src/data/result.dart';
import 'package:meow_dart/src/downloader_spawner.dart';
import 'package:stdlog/stdlog.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

export 'src/data/format.dart';
export 'src/downloader_spawner.dart';
export 'src/models/config.dart';

/// A portable YouTube archiver.
class MeowDart {
  /// Creates a new [MeowDart] given a [spawner].
  MeowDart({required this.spawner});

  /// The downloader spawner to use.
  final DownloaderSpawner spawner;

  /// The YouTube downloader instance used only to get metadata.
  final _yt = YoutubeExplode();

  /// A list of video IDs that we have requested to download.
  final downloadIds = HashSet<String>();

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

  /// Archive all videos in a video stream.
  Future<void> _archiveVideoStream(Stream<Video> videosStream) async {
    await for (final video in videosStream) {
      await archiveVideo(video.id.value);
    }
  }

  /// Download a video.
  Future<void> archiveVideo(String id) async {
    downloadIds.add(id);
    await spawner.spawnDownloader(
      id,
      resultHandler: (result) => _handleResult(id, result),
    );
  }

  /// Download a playlist.
  Future<void> archivePlaylist(String id) async {
    final videosStream = _yt.playlists.getVideos(id);
    await _archiveVideoStream(videosStream);
  }

  /// Download all uploads from a channel.
  Future<void> archiveChannel(String id) async {
    final videoStream = _yt.channels.getUploads(id);
    await _archiveVideoStream(videoStream);
  }

  /// Closes the YouTube client.
  void dispose() => _yt.close();
}
