/// [extras.dart] contains utility functions used all around gpm
/// Includes functions for:
/// - Formatting
/// - Parsing
/// - Path Utils

import 'dart:io';
import 'dart:math';

import 'package:archive/archive_io.dart';
import 'package:chalkdart/chalkstrings.dart';

/// When this field is set to [true]
/// then the user will not be prompted for confirmation
bool yesToAll = false;

/// parses the name of the package owner
/// for [omegaui/gpm] the output will be [omegaui]
String parseOwnerName(String appID) {
  return appID.substring(0, appID.indexOf('/'));
}

/// parses the name of the repository
/// for [omegaui/gpm] the output will be [gpm]
String parseRepoName(String appID) {
  return appID.substring(appID.indexOf('/') + 1);
}

/// returns only the extension of the file entity if any
/// else the entire name is returned
String getExtension(String filename) {
  if (filename.contains('.')) {
    return filename.substring(filename.lastIndexOf('.') + 1);
  }
  return filename;
}

/// Converts [bytes] into Human Readable Form
/// e.g: 1024 to "1 KB"
String formatBytes(int bytes) {
  if (bytes <= 0) {
    return "0 B";
  }
  const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
  var i = (log(bytes) / log(1024)).floor();
  return '${(bytes / pow(1024, i)).toStringAsFixed(0)} ${suffixes[i]}';
}

/// Converts [duration] into a format more like a time difference
String formatTime(Duration duration) {
  if (duration.inMilliseconds < 1000) {
    return "${duration.inMilliseconds} ms";
  } else if (duration.inSeconds < 60) {
    return "${duration.inSeconds} seconds";
  } else if (duration.inMinutes < 60) {
    return "${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')} minutes";
  } else {
    return "${duration.inHours}:${(duration.inMinutes % 60).toString().padLeft(2, '0')} hours";
  }
}

/// Returns the user's home directory path
String getUserHome() {
  String? home;
  if (Platform.isWindows) {
    home = Platform.environment['USERPROFILE'];
  } else if (Platform.isMacOS) {
    home = Platform.environment['HOME'];
  } else if (Platform.isLinux) {
    home = Platform.environment['HOME'];
  }
  home ??= Directory.systemTemp.path;
  return home;
}

/// Forms a path by combining
/// the [locations] i.e the file entity names
String combinePath(List<String> locations, {bool absolute = false}) {
  String path = locations.join(Platform.pathSeparator);
  return absolute ? File(path).absolute.path : path;
}

void movePath(String oldPath, String newPath) {
  try {
    dynamic oldEntity;

    if (FileSystemEntity.isDirectorySync(oldPath)) {
      oldEntity = Directory(oldPath);
    } else {
      oldEntity = File(oldPath);
    }

    if (oldEntity is File) {
      // Ensure the destination directory exists
      var newDirectory = Directory(newPath).parent;
      if (!newDirectory.existsSync()) {
        newDirectory.createSync(recursive: true);
      }
      var newLocation = File(newPath);
      if (newLocation.existsSync()) {
        newLocation.deleteSync();
      }
      oldEntity.copySync(newPath);
    } else if (oldEntity is Directory) {
      // Ensure the destination directory exists
      var newDirectory = Directory(newPath);
      if (!newDirectory.existsSync()) {
        newDirectory.createSync(recursive: true);
      } else {
        newDirectory.deleteSync(recursive: true);
        newDirectory.createSync(recursive: true);
      }
      oldEntity.renameSync(newPath);
    } else {
      print("Unsupported entity type at the old path.");
    }
  } catch (e) {
    print("Error moving the file: $e");
  }
}

/// Used to prompt the user
/// if user enters y or Y, then true is returned else false
bool yes(String text) {
  if (yesToAll) {
    return true;
  }
  stdout.write(text.bold);
  var input = stdin.readLineSync() ?? "n";
  return input == 'y' || input == 'Y';
}

/// Extracts an archive object to a destination path
/// Useful at the time of source mode install
Future<bool> extract(String archivePath, String outputPath) async {
  try {
    final inputStream = InputFileStream(archivePath);
    final archive = ZipDecoder().decodeBuffer(inputStream);
    await extractArchiveToDiskAsync(archive, outputPath);
    inputStream.close();
    return true;
  } catch (e) {
    // ignore
    print(e);
  }
  return false;
}

/// Performs an addtional check when deleting a directory
void deleteDir(String path) {
  final dir = Directory(path);
  if (dir.existsSync()) {
    dir.deleteSync(recursive: true);
  }
}

String generateGPMIsolateID() {
  String randomLetter = String.fromCharCode(Random().nextInt(26) + 65);
  String randomDigits = (100 + Random().nextInt(9999)).toString();
  String randomString = '$randomLetter$randomDigits';
  return randomString;
}
