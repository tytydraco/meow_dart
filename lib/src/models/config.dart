import 'dart:io';

import 'package:meow_dart/src/data/format.dart';
import 'package:meow_dart/src/data/quality.dart';

/// The configuration for the download.
class Config {
  /// Creates a new [Config].
  Config({
    required this.directory,
    this.format = Format.muxed,
    this.quality = Quality.best,
    this.commands = const [],
    this.cookie,
  });

  /// The directory to place the video in.
  final Directory directory;

  /// The download format type.
  final Format format;

  /// The download quality.
  final Quality quality;

  /// Ordered commands to run after each download has been completed.
  final List<String> commands;

  /// The user cookie.
  final String? cookie;
}
