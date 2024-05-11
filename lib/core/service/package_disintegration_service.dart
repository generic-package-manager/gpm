import 'dart:io';

import 'package:chalkdart/chalkstrings.dart';
import 'package:gpm/gpm_cli.dart';

import '../../constants/enums.dart';
import '../../extras/extras.dart';
import '../../extras/linux_utils.dart';
import '../../extras/windows_utils.dart';
import '../storage/gpm_storage.dart';
import 'package_registry_service.dart';
import 'system_service.dart';

class PackageDisintegrationService {
  PackageDisintegrationService._();

  static void disintegrate(String id) {
    int code = 0;
    switch (SystemService.osObject) {
      case OS.windows:
        code = _disintegrateWindowsPackage(id);
        break;
      case OS.linux:
        code = _disintegateSourceCommon(id);
        break;
      case OS.debian:
        code = _disintegrateDebianPackage(id);
        break;
      case OS.fedora:
        code = _disintegrateFedoraPackage(id);
        break;
      case OS.arch:
        code = _disintegrateArchPackage(id);
        break;
      case OS.macos:
        break;
      case OS.unrecognized:
        break;
    }
    if (code == 0) {
      // this means the disintegration was successful
      // now we have to remove the trace of the installed package
      // using the package register
      PackageRegistryService.remove(id: id);
    }
    terminateInstance(exitCode: code);
  }

  static int _disintegrateWindowsPackage(String id) {
    if (PackageRegistryService.isPackageInstalledViaReleaseMode(id)) {
      final asset = PackageRegistryService.getReleaseObject(id);
      if (asset.isSetup()) {
        // handle msi
        print('${parseRepoName(id)} was installed via an unknown installer.'
            .magenta);
        print('Head over to Installed Apps from Windows Settings to remove it.'
            .blue);
        print('Removing the app from gpm\'s registry ...');
        print('the app will not be getting updates now.');
        print('You can safely uninstall it.');
      } else {
        // handle exe and others
        // deleting the desktop shortcut
        print("Removing Desktop Shortcut ...".blue.bold);
        WindowsUtils.deleteDesktopShortcut(asset.repo);
        // removing the app data from ~/.gpm/apps
        print("Removing App Data ...".blue.bold);
        final app = File(GPMStorage.toAppPath(asset)).parent;
        if (app.existsSync()) {
          app.deleteSync(recursive: true);
        }
        print("Successfully removed $id".green.bold);
      }
      return 0;
    } else {
      return _disintegateSourceCommon(id);
    }
  }

  static int _disintegrateDebianPackage(String id) {
    if (PackageRegistryService.isPackageInstalledViaReleaseMode(id)) {
      final asset = PackageRegistryService.getReleaseObject(id);
      if (asset.isSetup()) {
        print('Removing $id installed via dpkg ...');
        // handle deb using dpkg -r
        final fullName = asset.name;
        // by conventions the package name is separated by an underscore `_` character
        final packageName = fullName.substring(0, fullName.indexOf('_'));
        final exitCode = SystemService.executeSync('sudo dpkg -r $packageName');
        if (exitCode != 0) {
          print('Failed to remove $packageName from your system.');
        } else {
          print("Successfully removed $id".green.bold);
        }
      } else {
        // handle .AppImage and others
        // deleting the desktop shortcut
        print("Removing Desktop Shortcut ...".magenta.bold);
        LinuxUtils.deleteDesktopShortcut(asset.repo);
        // removing the app data from ~/.gpm/apps
        print("Removing App Data ...".magenta.bold);
        final app = File(GPMStorage.toAppPath(asset)).parent;
        if (app.existsSync()) {
          app.deleteSync(recursive: true);
        }
        print("Successfully removed $id".green.bold);
      }
      return 0;
    } else {
      return _disintegateSourceCommon(id);
    }
  }

  static int _disintegrateFedoraPackage(String id) {
    if (PackageRegistryService.isPackageInstalledViaReleaseMode(id)) {
      final asset = PackageRegistryService.getReleaseObject(id);
      if (asset.isSetup()) {
        print('Removing $id installed via dnf ...');
        // handle rpm using dnf remove
        final fullName = asset.name;
        // by conventions the package name is separated by an underscore `_` character
        final packageName = fullName.substring(0, fullName.indexOf('_'));
        final exitCode =
            SystemService.executeSync('sudo dnf remove $packageName');
        if (exitCode != 0) {
          print('Failed to remove $packageName from your system.');
        } else {
          print("Successfully removed $id".green.bold);
        }
      } else {
        // handle .AppImage and others
        // deleting the desktop shortcut
        print("Removing Desktop Shortcut ...".magenta.bold);
        LinuxUtils.deleteDesktopShortcut(asset.repo);
        // removing the app data from ~/.gpm/apps
        print("Removing App Data ...".magenta.bold);
        final app = File(GPMStorage.toAppPath(asset)).parent;
        if (app.existsSync()) {
          app.deleteSync(recursive: true);
        }
        print("Successfully removed $id".green.bold);
      }
      return 0;
    } else {
      return _disintegateSourceCommon(id);
    }
  }

  static int _disintegrateArchPackage(String id) {
    if (PackageRegistryService.isPackageInstalledViaReleaseMode(id)) {
      final asset = PackageRegistryService.getReleaseObject(id);
      if (asset.isSetup()) {
        print('Removing $id installed via pacman ...');
        // handle zst using pacman -R
        final fullName = asset.name;
        // by conventions the package name is separated by an underscore `_` character
        final packageName = fullName.substring(0, fullName.indexOf('_'));
        final exitCode =
            SystemService.executeSync('sudo pacman -R $packageName');
        if (exitCode != 0) {
          print('Failed to remove $packageName from your system.');
        } else {
          print("Successfully removed $id".green.bold);
        }
      } else {
        // handle .AppImage and others
        // deleting the desktop shortcut
        print("Removing Desktop Shortcut ...".magenta.bold);
        LinuxUtils.deleteDesktopShortcut(asset.repo);
        // removing the app data from ~/.gpm/apps
        print("Removing App Data ...".magenta.bold);
        final app = File(GPMStorage.toAppPath(asset)).parent;
        if (app.existsSync()) {
          app.deleteSync(recursive: true);
        }
        print("Successfully removed $id".green.bold);
      }
      return 0;
    } else {
      return _disintegateSourceCommon(id);
    }
  }

  static int _disintegateSourceCommon(String id) {
    try {
      // deleting source binary data
      print("Removing App Data ...".magenta.bold);
      final sourcePath = GPMStorage.toAppDirPath(id);
      final dir = Directory(sourcePath);
      if (dir.existsSync()) {
        dir.delete(recursive: true);
      }
      // cleaning desktop shortcut
      LinuxUtils.deleteDesktopShortcut(parseRepoName(id));
      print("Successfully removed $id".green.bold);
    } catch (e) {
      print("[DSC] Clean up failed.");
      print('Failed to remove $id from your system.');
      return 1;
    }
    return 0;
  }
}
