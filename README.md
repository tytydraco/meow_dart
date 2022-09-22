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

Let Meow search recursively through a directory using the following command:

`meow_dart <DIRECTORY>`

# Log key

Meow uses a unique logging schema in order to show you information about the download concisely.

```
|           A track has been identified.
.           A track has been skipped.
^           A track has been downloaded.
```
