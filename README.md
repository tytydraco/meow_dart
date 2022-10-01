# meow_dart

A portable YouTube audio archiver.

# How it works

Meow will recursively search through a directory for files named `.url`. The URL file contains one or more URLs to
YouTube or YouTube Music playlists, separated by a newline. Meow will download the highest quality audio-only stream
available for the video to the directory its playlist URL was part of. Audio files are named with the YouTube ID
appended at the end in order to avoid conflicts when downloading two tracks of the same name. If the file already
exists, the download will be skipped.

# Getting started

Install the program using the following command:

`dart pub global activate -s git https://github.com/tytydraco/meow_dart`

# Usage

```
-h, --help                     Shows the usage.
-d, --directory (mandatory)    The directory to use. If no URL is specified, a file named '.url' should contain one or more URLs.
-u, --url                      The URL to use instead of using a file. Multiple can be specified using a comma, or be specifying multiple URL options.
-r, --[no-]recursive           Search directory recursively.
                               (defaults to on)
-m, --max-concurrent           The maximum number of concurrent downloads to do at once.
                               (defaults to "8")
-c, --command                  A command to run after a download has been completed. The downloaded file path will be passed to the command as an argument. The command's working directory is the parent directory of the downloaded file.
```
