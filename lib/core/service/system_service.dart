import 'dart:io';

import 'package:chalkdart/chalkstrings.dart';
import 'package:gpm/constants/constants.dart';

import '../../constants/enums.dart';
import '../../extras/extras.dart';
import '../../extras/linux_utils.dart';
import '../storage/gpm_storage.dart';

class SystemService {
  SystemService._();

  static late final OS _os;

  static String get os => _os.name;

  static OS get osObject => _os;

  static bool get isKnownLinuxDistribution =>
      KnownLinuxDistro.values.any((e) => e.name == os);

  static void init() {
    if (Platform.isWindows) {
      _os = OS.windows;
    } else if (Platform.isMacOS) {
      _os = OS.macos;
      print('[GPM] MacOS is not currently supported.');
    } else if (Platform.isLinux) {
      // we further try to identify the host linux distribution's parent.
      // For any linux distro we assume that [/etc/os-release] file exist
      final path = '/etc/os-release';
      final releaseFile = File(path);
      if (releaseFile.existsSync()) {
        final contents = releaseFile.readAsStringSync();
        final data = parseLinuxSystemInfo(contents);
        if (data.isDebian()) {
          _os = OS.debian;
        } else if (data.isFedora()) {
          _os = OS.fedora;
        } else if (data.isArch()) {
          _os = OS.arch;
        } else {
          _os = OS.linux;
          // at this point ...
          // an unknown linux distro encountered
          // go gpm !!
        }
      } else {
        _os = OS.linux;
        // again ...
        // an unknown linux distro encountered
        // go gpm !!
      }
    } else {
      _os = OS.unrecognized;
      print("WARNING: Unrecognized Platform: ${Platform.operatingSystem}"
          .yellow
          .bold);
    }
  }

  static List<String> getOSKeywords() {
    final os = SystemService.osObject;
    switch (os) {
      case OS.windows:
        return OSKeywords.windows;
      case OS.linux:
        return OSKeywords.linux;
      case OS.macos:
        return OSKeywords.macos;
      case OS.debian:
        return OSKeywords.debian;
      case OS.fedora:
        return OSKeywords.fedora;
      case OS.arch:
        return OSKeywords.arch;
      case OS.unrecognized:
        return OSKeywords.unrecognized;
    }
  }

  static int executeSync(String cmd, [String? workingDir, bool log = true]) {
    int exitCode = 0;
    if (Platform.isWindows) {
      final result = Process.runSync(
        'pwsh',
        [
          '-file',
          GPMStorage.windowsCommandExecutorFile.path,
          cmd,
        ],
        workingDirectory: workingDir ?? getUserHome(),
        runInShell: true,
        environment: Platform.environment,
      );
      exitCode = result.exitCode;
      if (exitCode != 0) {
        print(result.stdout);
        print(result.stderr);
      }
    } else if (Platform.isLinux) {
      final result = Process.runSync(
        GPMStorage.unixCommandExecutorFile.path,
        [cmd],
        workingDirectory: workingDir ?? getUserHome(),
        runInShell: true,
      );
      exitCode = result.exitCode;
      if (exitCode != 0) {
        print(result.stdout);
        print(result.stderr);
      }
    }
    return exitCode;
  }

  static Future<int> execute(String cmd,
      [String? workingDir, bool log = true]) async {
    int exitCode = 0;
    if (Platform.isWindows) {
      final result = await Process.run(
        'pwsh',
        [
          '-file',
          GPMStorage.windowsCommandExecutorFile.path,
          cmd,
        ],
        workingDirectory: workingDir ?? getUserHome(),
        runInShell: true,
        environment: Platform.environment,
      );
      exitCode = result.exitCode;
      if (exitCode != 0) {
        print(result.stdout);
        print(result.stderr);
      }
    } else if (Platform.isLinux) {
      final result = await Process.run(
        GPMStorage.unixCommandExecutorFile.path,
        [cmd],
        workingDirectory: workingDir ?? getUserHome(),
        runInShell: true,
      );
      exitCode = result.exitCode;
      if (exitCode != 0) {
        print(result.stdout);
        print(result.stderr);
      }
    }
    return exitCode;
  }

  static void makeExecutable(String filePath) {
    final result = Process.runSync(
      'chmod',
      ['+x', filePath],
    );
    if (result.exitCode != 0) {
      print(result.stderr);
    }
  }

  static void addToPath(id, String path) {
    if (Platform.isWindows) {
      print("To ensure security on your windows operating system, ");
      print("gpm will not itself update the path variable.");
      print(
          "Please add ${path.blue.bold} to your System Environment Variable to access the installed cli program throughtout your system.");
    } else if (Platform.isLinux) {
      // identifying shell
      // defaults to bash
      final shell = Platform.environment['SHELL'] ?? '/bin/bash';
      String rcFile = '.bashrc';
      if (shell.contains('zsh')) {
        rcFile = '.zshrc';
      } else if (shell.contains('fish')) {
        rcFile = '.fishrc';
      }
      final file = File(combinePath([getUserHome(), rcFile]));
      file.writeAsString(
        'PATH="$path:\$PATH"',
        mode: FileMode.append,
        flush: true,
      );
      print("Added $id to PATH, Start a new shell or run `source ~/$rcFile` to check it out.");
    }
  }

  /// Checks if an executable or command exists in the system
  /// by running if with --help flag,
  /// if the exitCode is 0, then the executable exists
  /// else we assume that the executable is not installed or not on path
  static bool doesExecutableExists(String executable) {
    if (Platform.isWindows) {
      try {
        final exitCode = SystemService.executeSync('$executable --help');
        return exitCode == 0;
      } catch (e) {
        return false;
      }
    } else if (Platform.isLinux) {
      try {
        final result = Process.runSync(
          executable,
          ['--help'],
        );
        return result.exitCode == 0;
      } catch (e) {
        return false;
      }
    } else {
      print("GPM doesn't supports your operating system, yet.");
      return false;
    }
  }
}
