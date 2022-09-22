import 'dart:io';

import 'package:meow_dart/meow_dart.dart';
import 'package:path/path.dart';

/// The name of the URL file.
const urlFileName = '.url';

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

    final urlFile = File(join(inputDirectory.path, urlFileName));
    if (!urlFile.existsSync()) {
      throw AssertionError('URL file does not exist.');
    }

    final urls = await urlFile.readAsLines();
    await MeowDart(inputDirectory).archive(urls);
  } catch (e) {
    stdout.writeln(e.toString());
    exit(1);
  }
}
