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
      mandatory: true,
    )
    ..addMultiOption(
      'url',
      abbr: 'u',
      help: 'The YouTube playlist URL to download. Multiple can be specified '
          'using a comma, or be specifying multiple URL options.',
    )
    ..addOption(
      'max-concurrent',
      abbr: 'm',
      help: 'The maximum number of concurrent downloads to do at once.',
      defaultsTo: '8',
    )
    ..addOption(
      'command',
      abbr: 'c',
      help: 'A command to run after a download has been completed. The '
          'downloaded file path will be passed to the command as an argument. '
          "The command's working directory is the parent directory of the "
          'downloaded file.',
    );

  try {
    final results = argParser.parse(args);
    final directory = results['directory'] as String;
    final urls = results['url'] as List<String>;
    final maxConcurrent = int.parse(results['max-concurrent'] as String);
    final command = results['command'] as String?;

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

    // Setup our package.
    final meowDart = MeowDart(
      inputDirectory,
      maxConcurrent: maxConcurrent,
      command: command,
    );

    // Archive all URLs.
    for (final url in urls) {
      await meowDart.archivePlaylist(url);
    }
  } catch (e) {
    stdout.writeln(e.toString());
    exit(1);
  }
}
