import 'dart:io';
import 'dart:isolate';

import 'package:meow_dart/src/download_result.dart';
import 'package:meow_dart/src/downloader.dart';
import 'package:pool/pool.dart';
import 'package:stdlog/stdlog.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class DownloaderSpawner {
  final _pool = Pool(8);

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

  static Future<void> _isolateTask(List<Object> args) async {
    final sendPort = args[0] as SendPort;
    final videoId = args[1] as String;
    final directoryPath = args[2] as String;

    final downloader = Downloader(
      videoId: videoId,
      directoryPath: directoryPath,
    );

    final result = await downloader.download();
    sendPort.send(result);
  }

  /// Spawn a new isolate to download this video.
  Future<void> _spawnDownloader(Video video, Directory directory) async {
    final poolResource = await _pool.request();

    final receivePort = RawReceivePort()
      ..handler = (result) {
        // TODO(tytydraco): handle result here _handleResult
        poolResource.release();
      };

    await Isolate.spawn(
      _isolateTask,
      [receivePort.sendPort, video.id.value, directory.path],
      onError: receivePort.sendPort,
    );
  }
}
