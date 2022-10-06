import 'dart:io';

import 'package:meow_dart/src/format.dart';

/// The configuration for the download.
class DownloaderConfig {
  /// Creates a new [DownloaderConfig].
  DownloaderConfig({
    required this.directory,
    this.format = Format.muxed,
    this.commands = const [],
  });

  /// The directory to place the video in.
  final Directory directory;

  /// The download format type.
  final Format format;

  /// Ordered commands to run after each download has been completed.
  final List<String> commands;
}
