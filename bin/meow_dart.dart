import 'dart:io';

import 'package:meow_dart/src/archiver.dart';
import 'package:meow_dart/src/files.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('No directory specified.');
    exit(1);
  }

  try {
    final inputDirectory = Directory(args.first);
    final io = Files(inputDirectory);
    final urls = await io.getUrls();
    await Archiver(io).archivePlaylists(urls);
  } catch (e) {
    stdout.writeln(e.toString());
    exit(1);
  }
}
