import 'dart:io';

import 'package:meow_dart/meow_dart.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('No directory specified.');
    exit(1);
  }

  try {
    final inputDirectory = Directory(args.first);
    await MeowDart(inputDirectory).archive();
    stdout.writeln();
  } catch (e) {
    stdout.writeln(e.toString());
    exit(1);
  }
}
