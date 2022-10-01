import 'dart:io';

import 'package:io/io.dart';
import 'package:meow_dart/src/download_result.dart';
import 'package:path/path.dart';
import 'package:stdlog/stdlog.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Downloads the best-quality audio stream to a file.
class Downloader {
  /// Creates a new [Downloader] given a [videoId].
  Downloader({
    required this.videoId,
    required this.directory,
    this.command,
  });

  /// The YouTube video ID to use.
  final String videoId;

  /// The directory to place the video in.
  final Directory directory;

  /// A command to run after each download has been completed.
  final String? command;

  /// The string used to separate the file name and the YouTube id.
  static const fileNameIdSeparator = ' ~ ';

  /// Lazily initialized YouTube download client.
  late final _yt = YoutubeExplode();

  /// Returns a valid file name fore the given video.
  String _getFileNameForAudio(
    Video video,
    AudioStreamInfo audioStream,
  ) {
    final fileExtension = audioStream.container.name;
    final name = '${video.title.replaceAll('/', '')}'
        '$fileNameIdSeparator'
        '${video.id.value}'
        '.$fileExtension';

    return name;
  }

  /// Returns the highest quality audio stream.
  Future<AudioStreamInfo> _getBestAudioStream() async {
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    return manifest.audioOnly.sortByBitrate().first;
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
    final result = await Process.run(
      parts.first,
      [...parts.sublist(1), file.path],
      runInShell: true,
      workingDirectory: file.parent.path,
    );

    if (result.exitCode != 0) {
      warn('$videoId\tCommand exited with non-zero exit code.');
    }
  }

  /// Downloads the audio track for the video.
  Future<DownloadResult> download() async {
    // Check if we already have this one in case we can skip.
    if (await _videoAlreadyDownloaded()) return DownloadResult.fileExists;

    final video = await _yt.videos.get(videoId);

    final AudioStreamInfo audioStream;
    final Stream<List<int>> byteStream;

    try {
      // Get the stream metadata and byte stream.
      audioStream = await _getBestAudioStream();
      byteStream = _yt.videos.streamsClient.get(audioStream);
    } catch (_) {
      // Failed to fetch stream info.
      return DownloadResult.badStream;
    }

    // Figure out where to put this file.
    final filePath =
        join(directory.path, _getFileNameForAudio(video, audioStream));
    final file = File(filePath);

    // Pipe byte stream to file.
    final wrote = await _writeFile(file, byteStream);
    if (!wrote) return DownloadResult.badWrite;

    // Run the optional command.
    await _executeCommand(file);

    return DownloadResult.success;
  }
}
