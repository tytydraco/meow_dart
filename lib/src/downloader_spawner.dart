import 'dart:io';
import 'dart:isolate';

import 'package:meow_dart/src/downloader.dart';
import 'package:meow_dart/src/downloader_config.dart';
import 'package:meow_dart/src/downloader_result.dart';
import 'package:meow_dart/src/format.dart';
import 'package:pool/pool.dart';
import 'package:stdlog/stdlog.dart';

/// Handles the spawning of multithreaded downloads.
class DownloaderSpawner {
  /// Creates a new [DownloaderSpawner] with a given thread limit.
  DownloaderSpawner({
    required this.maxConcurrent,
  }) {
    if (maxConcurrent < 1) {
      throw ArgumentError('Must be a positive integer.', 'maxConcurrent');
    }
  }

  /// The maximum number of concurrent downloads to do at once.
  final int maxConcurrent;

  /// Resource pool that specifies the maximum number of concurrent downloads.
  late final _pool = Pool(maxConcurrent);

  /// Output the result of the download.
  void _handleResult(String videoId, DownloaderResult result) {
    switch (result) {
      case DownloaderResult.badStream:
        error('$videoId\tFailed to fetch the audio stream.');
        break;
      case DownloaderResult.badWrite:
        error('$videoId\tFailed to write the output content.');
        break;
      case DownloaderResult.fileExists:
        debug('$videoId\tAlready downloaded.');
        break;
      case DownloaderResult.success:
        info('$videoId\tDownloaded successfully.');
        break;
    }
  }

  /// Creates a new isolate for the downloader task.
  static Future<void> _isolateTask(List<Object?> args) async {
    final sendPort = args[0]! as SendPort;
    final videoId = args[1]! as String;
    final directoryPath = args[2]! as String;
    final format = args[3]! as Format;
    final command = args[4] as String?;

    final downloader = Downloader(
      DownloaderConfig(
        directory: Directory(directoryPath),
        format: format,
        command: command,
      ),
      videoId: videoId,
    );

    final result = await downloader.download();
    sendPort.send(result);
    Isolate.exit();
  }

  /// Prevent any more downloads from being started.
  Future<void> close() async {
    await _pool.close();
  }

  /// Spawn a new isolate to download this video.
  Future<void> spawnDownloader(
    DownloaderConfig config, {
    required String videoId,
  }) async {
    /// Skip the download if the pool has been closed.
    if (_pool.isClosed) return;

    // Grab a resource.
    final poolResource = await _pool.request();

    // When the isolate task finishes, output the result if one exists and
    // release the resource.
    final port = ReceivePort();
    port.listen((message) {
      final result = message as DownloaderResult?;
      if (result != null) _handleResult(videoId, result);
      poolResource.release();

      // Do not allow any more incoming messages.
      port.close();
    });

    // Spawn the task.
    await Isolate.spawn(
      _isolateTask,
      [
        port.sendPort,
        videoId,
        config.directory.path,
        config.format,
        config.command,
      ],
      onExit: port.sendPort,
    );
  }
}
