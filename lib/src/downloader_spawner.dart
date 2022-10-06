import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:meow_dart/src/downloader.dart';
import 'package:meow_dart/src/downloader_config.dart';
import 'package:meow_dart/src/downloader_result.dart';
import 'package:meow_dart/src/format.dart';
import 'package:path/path.dart';
import 'package:pool/pool.dart';

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
  final _existingIds = HashSet<String>();

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

  /// Creates a new isolate for the downloader task.
  static Future<void> _isolateTask(List<Object?> args) async {
    final sendPort = args[0]! as SendPort;
    final videoId = args[1]! as String;
    final directoryPath = args[2]! as String;
    final format = args[3]! as Format;
    final commands = args[4]! as List<String>;

    final downloader = Downloader(
      DownloaderConfig(
        directory: Directory(directoryPath),
        format: format,
        commands: commands,
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
    String videoId, {
    void Function(DownloaderResult result)? resultHandler,
  }) async {
    /// Skip the download if the pool has been closed.
    if (_pool.isClosed) return;

    // Do a rapid existence check.
    if (_existingIds.contains(videoId)) {
      resultHandler?.call(DownloaderResult.fileExists);
      return;
    }

    // Grab a resource.
    final poolResource = await _pool.request();

    // When the isolate task finishes, output the result if one exists and
    // release the resource.
    final port = ReceivePort();
    port.listen((message) {
      final result = message as DownloaderResult?;

      // Cache the ID now that we know it successfully downloaded.
      if (result == DownloaderResult.success) _existingIds.add(videoId);
      poolResource.release();

      // Do not allow any more incoming messages.
      port.close();

      // Return the result so it can be handled.
      if (result != null) resultHandler?.call(result);
    });

    // Spawn the task.
    await Isolate.spawn(
      _isolateTask,
      [
        port.sendPort,
        videoId,
        config.directory.path,
        config.format,
        config.commands,
      ],
      onExit: port.sendPort,
    );
  }
}
