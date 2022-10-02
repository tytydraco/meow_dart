import 'package:meow_dart/src/downloader.dart';

/// The state of the [Downloader] result.
enum DownloaderResult {
  /// Failed to fetch the stream info.
  badStream,

  /// Failed to pipe the stream to the file.
  badWrite,

  /// The file already exists.
  fileExists,

  /// The download finished successfully.
  success,
}
