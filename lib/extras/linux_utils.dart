/// [linux_utils.dart] contains linux platform specific code
/// that helps in identifying the linux distribution,
/// creating desktop shortcuts and querying the desktop.

import 'dart:io';

import '../core/service/api_service.dart';
import '../core/service/download_service.dart';
import '../core/storage/gpm_storage.dart';
import 'extras.dart';

/// [LinuxUtils] contains functions that work commonly in any linux distribution
class LinuxUtils {
  /// Creates a desktop shortcut by writing a desktop entry
  /// file at ~/.local/share/applications/[executable].desktop
  /// where [executable] is usually the repository name
  /// and [id] is the package id used to fetching the icon of the app if any.
  static Future<int> createDesktopShortcut(String id, String executable) async {
    // checking if the repo has a gpm specification
    var icon = "https://img.icons8.com/color/128/empty-box.png";
    final spec = await APIService.getGPMSpecification(id);
    if (spec != null) {
      icon = spec['icon'] ?? icon;
    }

    final iconPath = combinePath([GPMStorage.toAppDirPath(id), 'app-icon.png']);

    print('Fetching App Icon ...');

    await DownloadService.download(
      url: icon,
      path: iconPath,
      onProgress: (progress) {},
      onComplete: (path) async {
        final repo = parseRepoName(id);
        final shortCutData = """
[Desktop Entry]
Name=$repo
Exec=$executable
Icon=$iconPath
Type=Application
Terminal=false
Categories=Utility;
""";
        print('Writing Desktop Entry ...');
        final desktopEntryFile = File(combinePath([
          getUserHome(),
          '.local',
          'share',
          'applications',
          '$repo.desktop'
        ]));
        desktopEntryFile.writeAsStringSync(shortCutData, flush: true);
      },
      onError: () {},
    );
    return 0;
  }

  /// Deletes a desktop shortcut by deleting the desktop entry file
  static void deleteDesktopShortcut(String repo) {
    final desktopEntryFile = File(combinePath(
        [getUserHome(), '.local', 'share', 'applications', '$repo.desktop']));
    if (desktopEntryFile.existsSync()) {
      desktopEntryFile.deleteSync();
    }
  }

  /// Opens the given path in the system file manager
  static void openInFiles(String path) {
    Process.runSync('xdg-open', [path], runInShell: true);
  }
}

/// [parseLinuxSystemInfo] parses the contents of /etc/os-release file
/// using [LinuxSystemReleaseDataEntity].
LinuxSystemReleaseDataEntity parseLinuxSystemInfo(contents) {
  return LinuxSystemReleaseDataEntity.fromReleaseFile(contents);
}

/// [LinuxSystemReleaseDataEntity] reads the given os-release contents
/// and identifies the underlying linux distribution.
/// The primary goal is to find the root parent distro
/// among [debian], [fedora] and [arch].
class LinuxSystemReleaseDataEntity {
  final Map<String, String> _releaseData = {};

  /// Reads the os-release contents
  /// and parses the data into _releaseData
  LinuxSystemReleaseDataEntity.fromReleaseFile(String contents) {
    List<String> lines = contents.split('\n');
    for (final line in lines) {
      if (line.isEmpty) {
        continue;
      }
      final indexOfSeparator = line.indexOf('=');
      final key = line.substring(0, indexOfSeparator);
      var value = line.substring(indexOfSeparator + 1);
      if (value[0] == '"') {
        value = value.substring(1, value.length - 1);
      }
      _releaseData[key.toLowerCase()] = value;
    }
  }

  /// Simple function to fetch the value at the given [key]
  String? _get(String key) {
    return _releaseData[key.toLowerCase()];
  }

  String? get id => _get('ID_LIKE') ?? _get('ID');

  bool isDebian() {
    return id == 'debian';
  }

  bool isFedora() {
    return id == 'fedora';
  }

  bool isArch() {
    return id == 'arch';
  }
}
