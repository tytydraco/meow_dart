import 'dart:io';

import 'package:meow_dart/src/files.dart';
import 'package:path/path.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// A class that downloads audio from a YouTube playlist.
class Archiver {
  /// Creates a new [Archiver] given a [files] instance.
  Archiver(this.files);

  /// The string used to separate the file name and the YouTube id.
  static const fileNameIdSeparator = '~';

  /// The [Files] to use.
  final Files files;

  /// The [YoutubeExplode] instance.
  final yt = YoutubeExplode();

  String _getFormattedFileName(Video video, AudioStreamInfo audioStream) {
    final fileExtension = audioStream.container.name;
    return '${video.title}'
        ' $fileNameIdSeparator '
        '${video.id.value}'
        '.$fileExtension';
  }

  Future<AudioStreamInfo> _getBestAudioStream(Video video) async {
    final manifest = await yt.videos.streamsClient.getManifest(video.id);
    return manifest.audioOnly.sortByBitrate().first;
  }

  /// Archive the best audio stream from a video.
  Future<void> archiveAudio(Video video) async {
    final audioStream = await _getBestAudioStream(video);
    final byteStream = yt.videos.streamsClient.get(audioStream);
    final fileName = _getFormattedFileName(video, audioStream);
    final file = File(join(files.directory.path, fileName));

    stdout
      ..writeln()
      ..writeln('=== TRACK ===')
      ..writeln('ID:\t${video.id.value}')
      ..writeln('TITLE:\t${video.title}')
      ..writeln('AUTHOR:\t${video.author}')
      ..writeln()
      ..write('>>> Downloading... ');

    // Check if we already have this one.
    if (files.containsFile(file)) {
      stdout.writeln('Skipped.');
    } else {
      files.addCachedFile(file);
      await byteStream.pipe(file.openWrite());
      stdout.writeln('Done.');
    }

    stdout
      ..writeln('=============')
      ..writeln();
  }
}
