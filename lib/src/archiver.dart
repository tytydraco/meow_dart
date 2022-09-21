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

  final _yt = YoutubeExplode();

  String _getFormattedFileName(Video video, AudioStreamInfo audioStream) {
    final fileExtension = audioStream.container.name;
    return '${video.title}'
        ' $fileNameIdSeparator '
        '${video.id.value}'
        '.$fileExtension';
  }

  Future<AudioStreamInfo> _getBestAudioStream(Video video) async {
    final manifest = await _yt.videos.streamsClient.getManifest(video.id);
    return manifest.audioOnly.sortByBitrate().first;
  }

  /// Returns true if we downloaded the audio, and false if we skipped it.
  Future<bool> _archiveAudio(Video video) async {
    final audioStream = await _getBestAudioStream(video);
    final fileName = _getFormattedFileName(video, audioStream);
    final file = File(join(files.directory.path, fileName));

    // Check if we already have this one.
    if (files.containsFile(file)) return false;

    final byteStream = _yt.videos.streamsClient.get(audioStream);
    files.addCachedFile(file);
    await byteStream.pipe(file.openWrite());

    return true;
  }

  Future<List<Video>> _getVideosFromPlaylist(String url) async {
    final playlist = await _yt.playlists.get(url);
    return _yt.playlists.getVideos(playlist.id).toList();
  }

  /// Downloads the highest quality audio from the given playlist URL, skipping
  /// tracks that have already been downloaded.
  Future<void> archivePlaylists(List<String> urls) async {
    await files.scan();

    final videos = <Video>{};
    for (final url in urls) {
      final videosPart = await _getVideosFromPlaylist(url);
      videos.addAll(videosPart);
    }

    for (final video in videos.toSet()) {
      stdout
        ..writeln()
        ..writeln('=== TRACK ===')
        ..writeln('ID:\t${video.id.value}')
        ..writeln('TITLE:\t${video.title}')
        ..writeln('AUTHOR:\t${video.author}')
        ..writeln()
        ..write('>>> Downloading... ');

      final downloaded = await _archiveAudio(video);

      stdout
        ..writeln(downloaded ? 'Done.' : 'Skipped.')
        ..writeln('=============')
        ..writeln();
    }
  }
}
