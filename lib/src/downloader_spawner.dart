import 'dart:collection';
import 'dart:isolate';

import 'package:meow_dart/src/downloader.dart';
import 'package:meow_dart/src/downloader_config.dart';
import 'package:meow_dart/src/downloader_isolate_data.dart';
import 'package:meow_dart/src/downloader_result.dart';
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

    // Neatly package the downloader and related info to the isolate.
    final data = DownloaderIsolateData(
      sendPort: port.sendPort,
      downloader: Downloader(config, videoId: videoId),
    );

    // Spawn the task.
    await Isolate.spawn(
      // Simply trigger the download from the passed downloader and forward the
      // result.
      (DownloaderIsolateData data) async {
        final result = await data.downloader.download();
        data.sendPort.send(result);
        Isolate.exit();
      },
      data,
      onExit: port.sendPort,
    );
  }

  /// Prevent any more downloads from being started.
  Future<void> close() async {
    await _pool.close();
  }
}
