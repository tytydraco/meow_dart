import 'dart:io';

import 'package:meow_dart/src/format.dart';
import 'package:meow_dart/src/mode.dart';

/// The configuration for the download.
class DownloaderConfig {
  /// Creates a new [DownloaderConfig].
  DownloaderConfig({
    required this.videoId,
    required this.directory,
    this.format = Format.muxed,
    this.mode = Mode.video,
    this.command,
  });

  /// The YouTube video ID to use.
  final String videoId;

  /// The directory to place the video in.
  final Directory directory;

  /// The download format type.
  final Format format;

  /// The download mode.
  final Mode mode;

  /// A command to run after each download has been completed.
  final String? command;
}
