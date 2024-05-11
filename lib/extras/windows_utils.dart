/// [windows_utils.dart] contains Windows platform specific code
/// that helps in creating a desktop shortcut i.e the windows lnk file
/// using powershell scripting.

import 'dart:io';
import '../core/storage/gpm_storage.dart';
import 'extras.dart';

/// [WindowsUtils] basic system calls for windows using ps1 scripts
class WindowsUtils {
  WindowsUtils._();

  /// opens up a [path] using the windows's explorer program
  static void openInExlorer(String path) {
    Process.runSync('explorer', [path], runInShell: true);
  }

  /// Creates a Windows Desktop Shortcut by writing the lnk file
  /// at $HOME\Desktop\[executable].lnk where [executable] is repository name.
  static int createDesktopShortcut(String name, String executable) {
    final result = Process.runSync(
      'pwsh',
      [
        '-Command',
        GPMStorage.windowsDesktopShortcutCreatorFile.path,
      ],
      workingDirectory: GPMStorage.root,
      environment: {
        'DestinationPath': "${getUserHome()}\\Desktop\\$name.lnk",
        'SourceExe': executable,
      },
    );
    if (result.exitCode != 0) {
      print(result.stdout);
      print(result.stderr);
    }
    return result.exitCode;
  }

  // Deletes the Windows Desktop Shortcut
  static void deleteDesktopShortcut(String name) {
    final path = "${getUserHome()}\\Desktop\\$name.lnk";
    final file = File(path);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }
}
