# meow_dart

A portable YouTube archiver.

# How it works

Meow will download the highest quality stream available for the video. Files are named with the YouTube ID appended at
the end in order to scan for existing downloads quickly.

# Getting started

Install the program using the following command:

`dart pub global activate -s git https://github.com/tytydraco/meow_dart`

# Usage

```
-h, --help              Shows the usage.
-d, --directory         The directory to download to.
                        (defaults to ".")
-u, --url               The YouTube playlist URL to download. Multiple can be specified using a comma, or be specifying multiple URL options.
-k, --max-concurrent    The maximum number of concurrent downloads to do at once.
                        (defaults to "8")
-f, --format            The output format to use.
                        [audio, video, muxed (default)]
-m, --mode              The download mode for the URL.
                        [video (default), playlist]
-c, --command           A command to run after a download has been completed. The downloaded file path will be passed to the command as an argument.
```
