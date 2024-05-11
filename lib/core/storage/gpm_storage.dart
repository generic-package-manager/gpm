import 'dart:io';

import '../../entity/asset_entity.dart';
import '../../extras/extras.dart';
import '../service/system_service.dart';
import 'package:gpm/gpm_cli.dart';

class GPMStorage {
  GPMStorage._();

  static const rootName = '.gpm';
  static const downloadStorage = 'downloads';
  static const registryStorage = 'registry';
  static const appsStorage = 'apps';
  static Directory gpmDir = Directory(combinePath([getUserHome(), rootName]));
  static Directory downloadsDir =
      Directory(combinePath([root, downloadStorage]));
  static Directory registryDir =
      Directory(combinePath([root, registryStorage]));
  static Directory appsDir = Directory(combinePath([root, appsStorage]));
  static File unixCommandExecutorFile =
      File(combinePath([root, 'unix-command-executor.sh']));
  static File windowsDesktopShortcutCreatorFile =
      File(combinePath([root, 'set-shortcut.ps1']));
  static File windowsCommandExecutorFile =
      File(combinePath([root, 'windows-command-executor.ps1']));

  static String get root => gpmDir.absolute.path;

  static void init() {
    if (!gpmDir.existsSync()) {
      gpmDir.createSync();
    }
    if (!downloadsDir.existsSync()) {
      downloadsDir.createSync();
    }
    if (!registryDir.existsSync()) {
      registryDir.createSync();
    }
    if (!appsDir.existsSync()) {
      appsDir.createSync();
    }
    if (Platform.isLinux) {
      if (!unixCommandExecutorFile.existsSync()) {
        unixCommandExecutorFile
            .writeAsStringSync(_Scripts().unixCommandExecutor, flush: true);
        SystemService.makeExecutable(unixCommandExecutorFile.path);
      }
    }
    if (Platform.isWindows) {
      if (!windowsDesktopShortcutCreatorFile.existsSync()) {
        windowsDesktopShortcutCreatorFile.writeAsStringSync(
            _Scripts().windowsDesktopShortcutCreator,
            flush: true);
      }
      if (!windowsCommandExecutorFile.existsSync()) {
        windowsCommandExecutorFile
            .writeAsStringSync(_Scripts().windowsCommandExecutor, flush: true);
      }
    }
  }

  static void cleanDownloads(_) {
    if (_) {
      if (downloadsDir.existsSync()) {
        final files = downloadsDir.listSync();
        for (final file in files) {
          file.deleteSync(recursive: true);
        }
      }
      print('Deleted temporary downloaded installers and cloned repositories.');
      terminateInstance();
    }
  }

  static String toPath(ReleaseAssetEntity assetEntity) {
    return combinePath(
        [GPMStorage.root, GPMStorage.downloadStorage, assetEntity.name]);
  }

  static String toRegistryPath(String id) {
    final owner = parseOwnerName(id);
    final repo = parseRepoName(id);
    final ownerDir = Directory(combinePath([root, registryStorage, owner]));
    if (!ownerDir.existsSync()) {
      ownerDir.createSync();
    }
    return combinePath([ownerDir.path, '$repo.json']);
  }

  static String toAppDirPath(String id) {
    final owner = parseOwnerName(id);
    final repo = parseRepoName(id);
    final ownerDir = Directory(combinePath([root, appsStorage, owner]));
    if (!ownerDir.existsSync()) {
      ownerDir.createSync();
    }
    final repoDir = Directory(combinePath([ownerDir.path, repo]));
    if (!repoDir.existsSync()) {
      repoDir.createSync();
    }
    return repoDir.path;
  }

  static String toAppPath(ReleaseAssetEntity asset) {
    final owner = asset.owner;
    final repo = asset.repo;
    final ownerDir = Directory(combinePath([root, appsStorage, owner]));
    if (!ownerDir.existsSync()) {
      ownerDir.createSync();
    }
    final repoDir = Directory(combinePath([ownerDir.path, repo]));
    if (!repoDir.existsSync()) {
      repoDir.createSync();
    }
    return combinePath([repoDir.path, '$repo.${getExtension(asset.name)}']);
  }

  static String toClonedRepoPath(String id) {
    final owner = parseOwnerName(id);
    final repo = parseRepoName(id);
    final ownerDir = Directory(combinePath([root, downloadStorage, owner]));
    if (!ownerDir.existsSync()) {
      ownerDir.createSync();
    }
    final repoDir = Directory(combinePath([ownerDir.path, repo]));
    if (!repoDir.existsSync()) {
      repoDir.createSync();
    }
    return combinePath([repoDir.path, "$repo.zip"]);
  }
}

class _Scripts {
  final unixCommandExecutor = """#!/bin/sh
\$@""";

  final windowsCommandExecutor = """
\$allArgs = \$PsBoundParameters.Values + \$args
pwsh -Command \$allArgs
exit \$Lastexitcode
""";

  final windowsDesktopShortcutCreator = """
\$DestinationPath = \$env:DestinationPath
\$SourceExe = \$env:SourceExe
echo "Shortcut Path: \$DestinationPath"
echo "Source Path: \$SourceExe"
\$WshShell = New-Object -comObject WScript.Shell
\$Shortcut = \$WshShell.CreateShortcut(\$DestinationPath)
\$Shortcut.TargetPath = \$SourceExe
\$Shortcut.Save()

""";
}
