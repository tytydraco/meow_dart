import 'dart:isolate';

import 'package:meow_dart/src/downloader.dart';

/// A data structure to ship packaged data to a downloader isolate.
class DownloaderIsolateData {
  /// Creates a new [DownloaderIsolateData].
  DownloaderIsolateData({
    required this.sendPort,
    required this.downloader,
  });

  /// The [SendPort] to use for the isolate.
  final SendPort sendPort;

  /// The downloader to use.
  final Downloader downloader;
}
