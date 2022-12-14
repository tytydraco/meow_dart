import 'dart:io';

import 'package:io/io.dart';
import 'package:meow_dart/src/data/format.dart';
import 'package:meow_dart/src/data/quality.dart';
import 'package:meow_dart/src/data/result.dart';
import 'package:meow_dart/src/models/config.dart';
import 'package:path/path.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Downloads the best-quality stream to a file.
class Downloader {
  /// Creates a new [Downloader] given a [config].
  Downloader(
    this.config, {
    required this.videoId,
  });

  /// The downloader config to use.
  final Config config;

  /// The YouTube video ID to use.
  final String videoId;

  /// The string used to separate the file name and the YouTube id.
  static const fileNameIdSeparator = ' ~ ';

  /// Lazily initialized YouTube download client.
  late final _yt = YoutubeExplode();

  /// Remove some restricted characters from the file name.
  String _sanitizeFileName(String fileName) => fileName.replaceAll(
        RegExp(r'["*/:<>?\\|]'),
        '',
      );

  /// Returns a valid file name fore the given video.
  String _getFileNameForStream(
    Video video,
    StreamInfo streamInfo,
  ) {
    final fileExtension = streamInfo.container.name;
    final name = '${video.title}'
        '$fileNameIdSeparator'
        '${video.id.value}'
        '.$fileExtension';

    return _sanitizeFileName(name);
  }

  /// Return the proper stream list for the config format.
  List<StreamInfo> _getFormatStreams(StreamManifest manifest) {
    switch (config.format) {
      case Format.audio:
        return manifest.audioOnly.sortByBitrate();
      case Format.video:
        return manifest.videoOnly.sortByVideoQuality();
      case Format.muxed:
        return manifest.muxed.sortByVideoQuality();
    }
  }

  /// Returns the stream of the config format and quality.
  Future<StreamInfo> _getStream() async {
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    final streams = _getFormatStreams(manifest);

    // Choose the appropriate quality.
    switch (config.quality) {
      case Quality.worst:
        return streams.last;
      case Quality.average:
        return streams[(streams.length - 1) ~/ 2];
      case Quality.best:
        return streams.first;
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

  /// Run the commands on the newly-downloaded file. If any command exits with
  /// a non-zero exit code, the function returns false. It returns true if all
  /// commands succeed.
  Future<bool> _executeCommands(File file) async {
    // Skip if no commands were given.
    if (config.commands.isEmpty) return true;

    for (final command in config.commands) {
      final parts = shellSplit(command);
      final process = await Process.start(
        parts.first,
        [...parts.sublist(1), file.path],
        runInShell: true,
        mode: ProcessStartMode.inheritStdio,
      );

      final exitCode = await process.exitCode;
      if (exitCode != 0) return false;
    }

    return true;
  }

  /// Downloads the video.
  Future<Result> download() async {
    final video = await _yt.videos.get(videoId);

    final StreamInfo streamInfo;
    final Stream<List<int>> byteStream;

    try {
      // Get the stream metadata and byte stream.
      streamInfo = await _getStream();
      byteStream = _yt.videos.streamsClient.get(streamInfo);
    } catch (_) {
      // Failed to fetch stream info.
      return Result.badStream;
    }

    // Figure out where to put this file.
    final filePath =
        join(config.directory.path, _getFileNameForStream(video, streamInfo));
    final file = File(filePath);

    // Skip if this file exists already.
    if (file.existsSync()) return Result.fileExists;

    // Pipe byte stream to file.
    final wrote = await _writeFile(file, byteStream);
    if (!wrote) return Result.badWrite;

    // Run the optional commands.
    final commandsSuccess = await _executeCommands(file);
    if (!commandsSuccess) return Result.badCommand;

    return Result.success;
  }

  /// Closes the YouTube client.
  void dispose() => _yt.close();
}
