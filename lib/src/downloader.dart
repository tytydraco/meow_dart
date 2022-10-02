import 'dart:io';

import 'package:io/io.dart';
import 'package:meow_dart/src/downloader_result.dart';
import 'package:meow_dart/src/format.dart';
import 'package:path/path.dart';
import 'package:stdlog/stdlog.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Downloads the best-quality stream to a file.
class Downloader {
  /// Creates a new [Downloader] given a [videoId].
  Downloader({
    required this.videoId,
    required this.directory,
    this.format = Format.video,
    this.command,
  });

  /// The YouTube video ID to use.
  final String videoId;

  /// The directory to place the video in.
  final Directory directory;

  /// The download format type.
  final Format format;

  /// A command to run after each download has been completed.
  final String? command;

  /// The string used to separate the file name and the YouTube id.
  static const fileNameIdSeparator = ' ~ ';

  /// Lazily initialized YouTube download client.
  late final _yt = YoutubeExplode();

  /// Returns a valid file name fore the given video.
  String _getFileNameForStream(
    Video video,
    StreamInfo streamInfo,
  ) {
    final fileExtension = streamInfo.container.name;
    final name = '${video.title.replaceAll('/', '')}'
        '$fileNameIdSeparator'
        '${video.id.value}'
        '.$fileExtension';

    return name;
  }

  /// Returns the highest quality stream.
  Future<StreamInfo> _getBestStream() async {
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);

    switch (format) {
      case Format.audio:
        return manifest.audioOnly.sortByBitrate().first;
      case Format.video:
        return manifest.videoOnly.sortByVideoQuality().first;
      case Format.muxed:
        return manifest.muxed.sortByVideoQuality().first;
    }
  }

  /// Writes the file out to the disk.
  Future<bool> _writeFile(File file, Stream<List<int>> byteStream) async {
    final fileSink = file.openWrite();

    try {
      // Download the stream data to a file.
      await byteStream.pipe(fileSink);
      return true;
    } catch (_) {
      // Clean up after an error.
      await fileSink.close();
      if (file.existsSync()) await file.delete();
      return false;
    }
  }

  /// Check if a file with the same video ID already exists.
  Future<bool> _videoAlreadyDownloaded() async {
    return directory
        .list()
        .map(
          (file) => basenameWithoutExtension(file.path),
        )
        .map((name) => name.split(fileNameIdSeparator).last)
        .any((id) => id == videoId);
  }

  /// Run the command on the newly-downloaded file.
  Future<void> _executeCommand(File file) async {
    // Skip if no command was given.
    if (command == null) return;

    final parts = shellSplit(command!);
    final process = await Process.start(
      parts.first,
      [...parts.sublist(1), file.path],
      runInShell: true,
      mode: ProcessStartMode.inheritStdio,
    );

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      warn('$videoId\tCommand exited with non-zero exit code.');
    }
  }

  /// Downloads the video.
  Future<DownloaderResult> download() async {
    // Check if we already have this one in case we can skip.
    if (await _videoAlreadyDownloaded()) return DownloaderResult.fileExists;

    final video = await _yt.videos.get(videoId);

    final StreamInfo streamInfo;
    final Stream<List<int>> byteStream;

    try {
      // Get the stream metadata and byte stream.
      streamInfo = await _getBestStream();
      byteStream = _yt.videos.streamsClient.get(streamInfo);
    } catch (_) {
      // Failed to fetch stream info.
      return DownloaderResult.badStream;
    }

    // Figure out where to put this file.
    final filePath =
        join(directory.path, _getFileNameForStream(video, streamInfo));
    final file = File(filePath);

    // Pipe byte stream to file.
    final wrote = await _writeFile(file, byteStream);
    if (!wrote) return DownloaderResult.badWrite;

    // Run the optional command.
    await _executeCommand(file);

    return DownloaderResult.success;
  }
}
