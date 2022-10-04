import 'dart:io';

import 'package:args/args.dart';
import 'package:meow_dart/meow_dart.dart';
import 'package:meow_dart/src/downloader_config.dart';
import 'package:meow_dart/src/downloader_spawner.dart';
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
      'url',
      abbr: 'u',
      help: 'The YouTube URL to download. Multiple can be specified using a '
          'comma, or be specifying multiple URL options.',
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
      help: 'The download mode for the URL.',
      allowed: ['video', 'playlist'],
      defaultsTo: 'video',
    )
    ..addOption(
      'command',
      abbr: 'c',
      help: 'A command to run after a download has been completed. The '
          'downloaded file path will be passed to the command as an argument.',
    );

  try {
    // Parse all results.
    final results = argParser.parse(args);
    final directory = results['directory'] as String;
    final urls = results['url'] as List<String>;
    final maxConcurrent = int.parse(results['max-concurrent'] as String);
    final command = results['command'] as String?;
    final formatStr = results['format'] as String;
    final modeStr = results['mode'] as String;

    var format = Format.muxed;
    switch (formatStr) {
      case 'audio':
        format = Format.audio;
        break;
      case 'video':
        format = Format.video;
        break;
      case 'muxed':
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
    if (urls.isEmpty) {
      warn('No URLs specified');
      exit(0);
    }

    /// Set up the downloader config we will be using.
    final config = DownloaderConfig(
      directory: inputDirectory,
      format: format,
      command: command,
    );

    final spawner = DownloaderSpawner(config, maxConcurrent: maxConcurrent);
    await spawner.cacheExistingDownloads();
    final meowDart = MeowDart(spawner: spawner);

    // Stop all requests if there is an exit request.
    final exitHandler = ProcessSignal.sigint.watch().listen((signal) async {
      error('Halt! Waiting for current downloads to finish.');
      await spawner.close();
      exit(0);
    });

    // Archive all URLs.
    switch (modeStr) {
      case 'video':
        for (final url in urls) {
          await meowDart.archiveVideo(url);
        }
        break;
      case 'playlist':
        for (final url in urls) {
          await meowDart.archivePlaylist(url);
        }
        break;
    }

    /// Exit gracefully.
    await exitHandler.cancel();
  } catch (e) {
    stdout.writeln(e.toString());
    exit(1);
  }
}
