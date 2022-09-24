import 'dart:io';

import 'package:meow_dart/meow_dart.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('No directory specified.');
    exit(1);
  }

  try {
    final inputDirectory = Directory(args.first);
    if (!inputDirectory.existsSync()) {
      throw AssertionError('Directory does not exist.');
    }

    await MeowDart().archiveDirectory(inputDirectory);
  } catch (e) {
    stdout.writeln(e.toString());
    exit(1);
  }
}
