import 'dart:io';

import 'package:path/path.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Downloads the best-quality audio stream to a file.
class Downloader {
  /// Creates a new [Downloader] given a [videoId].
  Downloader(this.videoId, this.directoryPath);

  /// The YouTube video ID to use.
  final String videoId;

  final String directoryPath;

  /// The string used to separate the file name and the YouTube id.
  static const fileNameIdSeparator = '~';

  final _yt = YoutubeExplode();

  Future<AudioStreamInfo> _getBestAudioStream() async {
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    return manifest.audioOnly.sortByBitrate().first;
  }

  Future<void> _writeFile(File file, Stream<List<int>> byteStream) async {
    final fileSink = file.openWrite();

    try {
      // Download the stream data to a file.
      await byteStream.pipe(fileSink);
      stdout.write('^');
    } catch (_) {
      // Clean up after an error.
      await fileSink.close();
      if (file.existsSync()) await file.delete();
      stdout.write('!');
    }
  }

  /// Returns an appropriate file name for an audio stream.
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

  Future<void> download() async {
    final video = await _yt.videos.get(videoId);

    final AudioStreamInfo audioStream;
    final Stream<List<int>> byteStream;

    try {
      // Get the stream metadata and byte stream.
      audioStream = await _getBestAudioStream();
      byteStream = _yt.videos.streamsClient.get(audioStream);
    } catch (_) {
      // Failed to fetch stream info.
      stdout.write('!');
      return;
    }

    // Figure out where to put this file.
    final fileName = _getFileNameForAudio(video, audioStream);
    final filePath = join(directoryPath, fileName);
    final file = File(filePath);

    // Check if we already have this one in case we can skip.
    if (file.existsSync()) {
      stdout.write('.');
      return;
    }

    // Pipe byte stream to file.
    await _writeFile(file, byteStream);
  }
}
