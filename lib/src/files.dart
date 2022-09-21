import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart';

/// A class to manage a specified directory.
class Files {
  /// Creates a new [Files] given a [directory].
  Files(this.directory) {
    _assertDirectoryExists();
    _assertUrlExists();
  }

  /// The name of the URL file.
  static const urlFileName = '.url';

  /// The specified working directory.
  final Directory directory;

  /// The file containing a list of URLs.
  late final _urlFile = File(join(directory.path, urlFileName));

  /// A list of video titles that exist in the directory.
  final _existingFileNames = HashSet<String>();

  /// Scan the specified directory for existing files. This caches filenames so
  /// that we can avoid redundancy.
  Future<void> scan() async {
    final fileNames = await directory
        .list()
        .skipWhile((file) => basenameWithoutExtension(file.path) == urlFileName)
        .map((file) => basenameWithoutExtension(file.path))
        .toSet();
    _existingFileNames
      ..clear()
      ..addAll(fileNames);
  }

  /// Returns true if we have a file with the same basename in the specified
  /// directory already. Cache must be populated using [scan] first.
  bool containsFile(FileSystemEntity file) =>
      _existingFileNames.contains(basenameWithoutExtension(file.path));

  /// Returns a list of URLs specified in the URL file.
  Future<List<String>> getUrls() => _urlFile.readAsLines();

  /// Mark a file as being already downloaded manually. Less expensive than a
  /// full scan.
  void addCachedFile(FileSystemEntity file) {
    _existingFileNames.add(basenameWithoutExtension(file.path));
  }

  void _assertDirectoryExists() {
    if (!directory.existsSync()) {
      throw AssertionError('Directory does not exist.');
    }
  }

  void _assertUrlExists() {
    if (!_urlFile.existsSync()) {
      throw AssertionError('URL file does not exist.');
    }
  }
}
