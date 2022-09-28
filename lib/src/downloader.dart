import 'dart:io';

import 'package:meow_dart/src/download_result.dart';
import 'package:path/path.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Downloads the best-quality audio stream to a file.
class Downloader {
  /// Creates a new [Downloader] given a [videoId].
  Downloader({
    required this.videoId,
    required this.directoryPath,
  });

  /// The YouTube video ID to use.
  final String videoId;

  /// The path of the directory to place the video in.
  final String directoryPath;

  /// The string used to separate the file name and the YouTube id.
  static const fileNameIdSeparator = '~';

  final _yt = YoutubeExplode();

  /// Returns a valid file name fore the given video.
  String _getFileNameForAudio(
    Video video,
    AudioStreamInfo audioStream,
  ) {
    final fileExtension = audioStream.container.name;
    final name = '${video.title.replaceAll('/', '')}'
        ' $fileNameIdSeparator '
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

  /// Downloads the audio track for the video.
  Future<DownloadResult> download() async {
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
        join(directoryPath, _getFileNameForAudio(video, audioStream));
    final file = File(filePath);

    // Check if we already have this one in case we can skip.
    if (file.existsSync()) return DownloadResult.fileExists;

    // Pipe byte stream to file.
    final wrote = await _writeFile(file, byteStream);
    if (!wrote) return DownloadResult.badWrite;

    return DownloadResult.success;
  }
}
