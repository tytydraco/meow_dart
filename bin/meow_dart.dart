import 'dart:io';

import 'package:args/args.dart';
import 'package:meow_dart/meow_dart.dart';
import 'package:meow_dart/src/data/quality.dart';
import 'package:meow_dart/src/downloader.dart';
import 'package:path/path.dart';
import 'package:stdlog/stdlog.dart';

/// The download mode.
enum Mode {
  /// A single video.
  video,

  /// A playlist of videos.
  playlist,

  /// All videos from a channel.
  channel,
}

ArgResults _parseArgs(List<String> args) {
  final argParser = ArgParser();
  argParser
    ..addFlag(
      'help',
      abbr: 'h',
      help: 'Shows the usage.',
      negatable: false,
      callback: (value) {
        if (value) {
          stdout.writeln(argParser.usage);
          exit(0);
        }
      },
    )
    ..addOption(
      'directory',
      abbr: 'd',
      help: 'The directory to download to.',
      defaultsTo: '.',
    )
    ..addMultiOption(
      'id',
      abbr: 'i',
      help: 'The YouTube ID to download. Multiple IDs can be specified.',
    )
    ..addOption(
      'max-concurrent',
      abbr: 'k',
      help: 'The maximum number of concurrent downloads to do at once. By '
          'default, it will be set to the number of CPU cores.',
      defaultsTo: '${Platform.numberOfProcessors}',
    )
    ..addOption(
      'format',
      abbr: 'f',
      help: 'The output format to use.',
      allowed: ['audio', 'video', 'muxed'],
      defaultsTo: 'muxed',
    )
    ..addOption(
      'quality',
      abbr: 'q',
      help: 'The download quality to use.',
      allowed: ['worst', 'average', 'best'],
      defaultsTo: 'best',
    )
    ..addOption(
      'mode',
      abbr: 'm',
      help: 'The mode that indicates the download method for the ID.',
      allowed: ['video', 'playlist', 'channel'],
      defaultsTo: 'video',
    )
    ..addMultiOption(
      'command',
      abbr: 'c',
      help: 'A command to run after a download has been completed. The '
          'downloaded file path will be passed to the command as an argument. '
          'Multiple commands can be specified.',
    )
    ..addFlag(
      'strict',
      abbr: 's',
      help: 'Remove old videos in the directory that were not part of the '
          'download.',
    );
  return argParser.parse(args);
}

Future<void> main(List<String> args) async {
  // Get results.
  final results = _parseArgs(args);

  // Parse all results.
  final directory = results['directory'] as String;
  final ids = results['id'] as List<String>;
  final maxConcurrent = int.parse(results['max-concurrent'] as String);
  final commands = results['command'] as List<String>;
  final formatStr = results['format'] as String;
  final format = Format.values.firstWhere((format) => format.name == formatStr);
  final qualityStr = results['quality'] as String;
  final quality =
      Quality.values.firstWhere((quality) => quality.name == qualityStr);
  final modeStr = results['mode'] as String;
  final mode = Mode.values.firstWhere((mode) => mode.name == modeStr);
  final strict = results['strict'] as bool;

  // Exit if a bad directory path was specified.
  final inputDirectory = Directory(directory);
  if (!inputDirectory.existsSync()) {
    error('Directory does not exist.');
    exit(1);
  }

  // Exit if we have nothing to process.
  if (ids.isEmpty) {
    warn('No IDs specified');
    exit(0);
  }

  /// Set up the downloader config we will be using.
  final config = Config(
    directory: inputDirectory,
    format: format,
    quality: quality,
    commands: commands,
  );

  final spawner = DownloaderSpawner(config, maxConcurrent: maxConcurrent);
  await spawner.cacheExistingDownloads();
  final meowDart = MeowDart(spawner: spawner);

  var forceQuit = false;

  // Stop all requests if there is an exit request.
  final exitHandler = ProcessSignal.sigint.watch().listen((signal) async {
    // Consider bailing without proper cleanup.
    if (forceQuit) {
      error('Force quit.');
      exit(1);
    }

    // If the user triggers it again, exit forcefully.
    forceQuit = true;

    error(
      'Halt! Waiting for queued downloads to finish. '
      'Interrupt again to force quit.',
    );
    await spawner.close();
    exit(0);
  });

  Future<void> Function(String id) getDownloadMethod() {
    switch (mode) {
      case Mode.video:
        return meowDart.archiveVideo;
      case Mode.playlist:
        return meowDart.archivePlaylist;
      case Mode.channel:
        return meowDart.archiveChannel;
    }
  }

  final downloadMethod = getDownloadMethod();

  // Archive all IDs.
  for (final id in ids) {
    await downloadMethod(id);
  }

  if (strict) {
    await inputDirectory.list().forEach((file) {
      final fileName = basenameWithoutExtension(file.path);
      final videoId = fileName.split(Downloader.fileNameIdSeparator).last;
      if (!meowDart.downloadIds.contains(videoId)) {
        info('$videoId\tDeleting stray.');
        file.deleteSync();
      }
    });
  }

  // Clean up.
  meowDart.dispose();

  // Exit gracefully.
  await exitHandler.cancel();
}
