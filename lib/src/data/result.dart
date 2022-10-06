/// The state of the download result.
enum Result {
  /// Failed to fetch the stream info.
  badStream,

  /// Failed to pipe the stream to the file.
  badWrite,

  /// One or more commands finished with a non-zero exit code.
  badCommand,

  /// The file already exists.
  fileExists,

  /// The download finished successfully.
  success,
}
