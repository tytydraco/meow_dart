import 'dart:isolate';

import 'package:meow_dart/src/downloader.dart';

/// A data structure to ship packaged data to a downloader isolate.
class IsolateData {
  /// Creates a new [IsolateData].
  IsolateData({
    required this.sendPort,
    required this.downloader,
  });

  /// The send port to use for the isolate.
  final SendPort sendPort;

  /// The downloader to use.
  final Downloader downloader;
}
