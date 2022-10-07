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
-i, --id                The YouTube ID to download. Multiple IDs can be specified.
-k, --max-concurrent    The maximum number of concurrent downloads to do at once. By default, it will be set to the number of CPU cores.
                        (defaults to "8")
-f, --format            The output format to use.
                        [audio, video, muxed (default)]
-m, --mode              The mode that indicates the download method for the ID.
                        [video (default), playlist, channel]
-c, --command           A command to run after a download has been completed. The downloaded file path will be passed to the command as an argument. Multiple commands can be specified.
```
