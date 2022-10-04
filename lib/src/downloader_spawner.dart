import 'dart:io';
import 'dart:isolate';

import 'package:meow_dart/src/downloader.dart';
import 'package:meow_dart/src/downloader_config.dart';
import 'package:meow_dart/src/downloader_result.dart';
import 'package:meow_dart/src/format.dart';
import 'package:path/path.dart';
import 'package:pool/pool.dart';
import 'package:stdlog/stdlog.dart';

/// Handles the spawning of multithreaded downloads.
class DownloaderSpawner {
  /// Creates a new [DownloaderSpawner] with a given thread limit.
  DownloaderSpawner(
    this.config, {
    required this.maxConcurrent,
  }) {
    if (maxConcurrent < 1) {
      throw ArgumentError('Must be a positive integer.', 'maxConcurrent');
    }
  }

  /// The downloader config to use.
  final DownloaderConfig config;

  /// The maximum number of concurrent downloads to do at once.
  final int maxConcurrent;

  /// Resource pool that specifies the maximum number of concurrent downloads.
  late final _pool = Pool(maxConcurrent);

  /// A list of IDs of already downloaded videos.
  final _existingIds = <String>{};

  /// Cache all existing video IDs from this current directory to avoid
  /// downloading a video twice.
  Future<void> cacheExistingDownloads() async {
    await config.directory
        .list()
        .map(
          (file) => basenameWithoutExtension(file.path),
        )
        .map((name) => name.split(Downloader.fileNameIdSeparator).last)
        .forEach(_existingIds.add);
  }

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
        _existingIds.add(videoId);
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
  Future<void> spawnDownloader(String videoId) async {
    /// Skip the download if the pool has been closed.
    if (_pool.isClosed) return;

    // Do a rapid existence check.
    if (_existingIds.contains(videoId)) {
      _handleResult(videoId, DownloaderResult.fileExists);
      return;
    }

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
