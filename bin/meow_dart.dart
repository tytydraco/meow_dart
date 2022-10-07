import 'dart:io';

import 'package:args/args.dart';
import 'package:meow_dart/meow_dart.dart';
import 'package:stdlog/stdlog.dart';

Future<void> main(List<String> args) async {
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
    );

  // Parse all results.
  final results = argParser.parse(args);
  final directory = results['directory'] as String;
  final ids = results['id'] as List<String>;
  final maxConcurrent = int.parse(results['max-concurrent'] as String);
  final commands = results['command'] as List<String>;
  final formatStr = results['format'] as String;
  final modeStr = results['mode'] as String;

  final Format format;
  switch (formatStr) {
    case 'audio':
      format = Format.audio;
      break;
    case 'video':
      format = Format.video;
      break;
    default:
      format = Format.muxed;
      break;
  }

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
    commands: commands,
  );

  final spawner = DownloaderSpawner(config, maxConcurrent: maxConcurrent);
  await spawner.cacheExistingDownloads();
  final meowDart = MeowDart(spawner: spawner);

  // Stop all requests if there is an exit request.
  var forceQuit = false;
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

  final Future<void> Function(String id) downloadMethod;
  switch (modeStr) {
    case 'playlist':
      downloadMethod = meowDart.archivePlaylist;
      break;
    case 'channel':
      downloadMethod = meowDart.archiveChannel;
      break;
    default:
      downloadMethod = meowDart.archiveVideo;
      break;
  }

  // Archive all IDs.
  for (final id in ids) {
    await downloadMethod(id);
  }

  // Clean up.
  meowDart.dispose();

  // Exit gracefully.
  await exitHandler.cancel();
}
