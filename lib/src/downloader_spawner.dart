import 'dart:io';
import 'dart:isolate';

import 'package:meow_dart/src/download_result.dart';
import 'package:meow_dart/src/downloader.dart';
import 'package:pool/pool.dart';
import 'package:stdlog/stdlog.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Handles the spawning of multithreaded downloads.
class DownloaderSpawner {
  /// Creates a new [DownloaderSpawner] with a given thread limit.
  DownloaderSpawner(
    this.maxConcurrent, {
    this.command,
  }) {
    if (maxConcurrent < 1) {
      throw ArgumentError('Must be a positive integer.', 'maxConcurrent');
    }
  }

  /// The maximum number of concurrent downloads to do at once.
  final int maxConcurrent;

  /// A command to run after each download has been completed.
  final String? command;

  /// Resource pool that specifies the maximum number of concurrent downloads.
  late final _pool = Pool(maxConcurrent);

  /// Output the result of the download.
  void _handleResult(String videoId, DownloadResult result) {
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
  }

  /// Creates a new isolate for the downloader task.
  static Future<void> _isolateTask(List<Object?> args) async {
    final sendPort = args[0]! as SendPort;
    final videoId = args[1]! as String;
    final directoryPath = args[2]! as String;
    final command = args[3] as String?;

    final downloader = Downloader(
      videoId: videoId,
      directory: Directory(directoryPath),
      command: command,
    );

    final result = await downloader.download();
    sendPort.send(result);
  }

  /// Prevent any more downloads from being started.
  Future<void> close() async {
    await _pool.close();
  }

  /// Spawn a new isolate to download this video.
  Future<void> spawnDownloader(Video video, Directory directory) async {
    /// Skip the download if the pool has been closed.
    if (_pool.isClosed) return;

    final videoId = video.id.value;

    // Grab a resource.
    final poolResource = await _pool.request();

    // When the isolate task finishes, output the result and release the
    // resource.
    final resultPort = RawReceivePort()
      ..handler = (DownloadResult result) {
        _handleResult(videoId, result);
        poolResource.release();
      };

    // Spawn the task.
    await Isolate.spawn(
      _isolateTask,
      [resultPort.sendPort, videoId, directory.path, command],
    );
  }
}
