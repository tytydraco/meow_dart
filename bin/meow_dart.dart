import 'dart:io';

import 'package:path/path.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('No directory specified.');
    exit(1);
  }

  final inputDirectory = Directory(args.first);
  if (!inputDirectory.existsSync()) {
    stderr.writeln('Specified directory does not exist.');
    exit(1);
  }

  final inputFiles = inputDirectory.listSync();
  final urlFiles = inputFiles.where(
        (file) => basename(file.path) == '.url',
  );
  if (urlFiles.isEmpty) {
    stderr.writeln('No .url file found in input directory.');
    exit(1);
  }

  final urlFile = File(urlFiles.first.path);
  final urls = urlFile.readAsLinesSync();

  final yt = YoutubeExplode();
  final playlist = await yt.playlists.get(urls.first);
  final videos = yt.playlists.getVideos(playlist.id);

  await for (final video in videos) {
    final manifest = await yt.videos.streamsClient.getManifest(video.id);
    final audioStreams = manifest.audioOnly;
    final bestAudioStream = audioStreams
        .sortByBitrate()
        .last;
    final byteStream = yt.videos.streamsClient.get(bestAudioStream);

    final fileExtension = bestAudioStream.container.name;
    final fileName = '${video.title} ~ ${video.id.value}.$fileExtension';
    final outFile = File(join(inputDirectory.path, fileName));
  }
}
