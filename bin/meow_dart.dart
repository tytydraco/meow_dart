import 'dart:io';

import 'package:args/args.dart';
import 'package:meow_dart/meow_dart.dart';

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
      help: "The directory to use. If no URL is specified, a file named '.url' "
          'should contain one or more URLs.',
      mandatory: true,
    )
    ..addMultiOption(
      'url',
      abbr: 'u',
      help: 'The URL to use instead of using a file. Multiple can be specified '
          'using a comma, or be specifying multiple URL options.',
    )
    ..addFlag(
      'recursive',
      abbr: 'r',
      help: 'Search directory recursively.',
      defaultsTo: true,
    );

  try {
    final results = argParser.parse(args);
    final directory = results['directory'] as String;
    final urls = results['url'] as List<String>;
    final recursive = results['recursive'] as bool;

    final inputDirectory = Directory(directory);
    if (!inputDirectory.existsSync()) {
      throw AssertionError('Directory does not exist.');
    }

    final meowDart = MeowDart(inputDirectory);

    // If URL is not specified, search recursively. Otherwise, use the URL.
    if (urls.isEmpty) {
      await meowDart.archiveDirectory(recursive: recursive);
    } else {
      await meowDart.archiveUrls(urls);
    }
  } catch (e) {
    stdout.writeln(e.toString());
    exit(1);
  }
}
