import 'dart:isolate';

import 'package:meow_dart/src/downloader_config.dart';

/// A data structure to ship packaged instructions to a downloader isolate.
class DownloaderIsolateData {
  /// Creates a new [DownloaderIsolateData].
  DownloaderIsolateData({
    required this.sendPort,
    required this.config,
    required this.videoId,
  });

  /// The [SendPort] to use for the isolate.
  final SendPort sendPort;

  /// The config to use for the downloader.
  final DownloaderConfig config;

  /// The YouTube video ID to use.
  final String videoId;
}
