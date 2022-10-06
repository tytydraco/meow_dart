import 'dart:io';

import 'package:meow_dart/src/data/format.dart';

/// The configuration for the download.
class Config {
  /// Creates a new [Config].
  Config({
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
