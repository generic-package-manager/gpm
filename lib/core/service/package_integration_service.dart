import 'dart:io';

import 'package:chalkdart/chalkstrings.dart';
import 'package:gpm/core/service/api_service.dart';

import '../../gpm_cli.dart';
import '../../constants/enums.dart';
import '../../entity/asset_entity.dart';
import '../../extras/extras.dart';
import '../../extras/linux_utils.dart';
import '../../extras/windows_utils.dart';
import '../storage/gpm_storage.dart';
import 'package_registry_service.dart';
import 'system_service.dart';

class PackageIntegrationService {
  PackageIntegrationService._();

  static Future<void> integrate(
      ReleaseAssetEntity asset, String packagePath, bool explicitCall) async {
    int code = 0;
    switch (SystemService.osObject) {
      case OS.windows:
        code = await _integrateWindowsPackage(asset, packagePath);
        break;
      case OS.linux:
        code = await _integrateLinuxCommon(asset, packagePath);
        break;
      case OS.macos:
        break;
      case OS.debian:
        code = await _integrateDebianPackage(asset, packagePath);
        break;
      case OS.fedora:
        code = await _integrateFedoraPackage(asset, packagePath);
        break;
      case OS.arch:
        code = await _integrateArchPackage(asset, packagePath);
        break;
      case OS.unrecognized:
        break;
    }
    if (code == 0) {
      // this means the integration was successful
      // now we have to keep track of the installed package
      // using the package register
      PackageRegistryService.registerRelease(asset: asset);
    }

    if (explicitCall) terminateInstance(exitCode: code);
  }

  static Future<int> _integrateWindowsPackage(
      ReleaseAssetEntity asset, String packagePath) async {
    if (asset.isSetup()) {
      // BUG (But its a feature): ms-powertoys bypasses this check somehow
      print("Installing package ...".blue.bold);
      int exitCode = SystemService.executeSync(packagePath);
      if (exitCode == 0) {
        print("Successfully Installed Package".green.bold);
      } else {
        print("Failed to install package".red.bold);
      }
      return exitCode;
    }
    if (verbose) {
      print(
          "Looks like we have downloaded an app ${"(not a setup)".magenta.bold}.");
      print("Don't worry, GPM can still manage updates for it.");
      print("You can launch it or pin it where you want.");
      print("Just do not move it away from ~/.gpm/apps.".yellow.dim);
      print(
          "If you do so, GPM would think you deleted the app and it will not be updated anymore."
              .yellow
              .dim);
    }

    // moving the app to a secure location
    // to prevent deletion from 'gpm --clean' command
    movePath(packagePath, (packagePath = GPMStorage.toAppPath(asset)));
    print("Source: ${packagePath.blue.bold}");

    if (asset.type == 'secondary') {
      print("Creating a desktop shortcut ...".blue.bold);
      final code = WindowsUtils.createDesktopShortcut(asset.repo, packagePath);
      if (code != 0) {
        print("Sorry, we couldn't create a desktop shortcut for this app."
            .magenta
            .bold);
        print('Although, the download was successful.');
        if (yes('Would you like to open it in explorer? [y/N]: ')) {
          WindowsUtils.openInExlorer(File(packagePath).parent.path);
        }
      }
      print("Successfully installed ${asset.repo}.".green.bold);
    } else if (asset.type == 'others') {
      // on windows the other targets are actually compressed files,
      // extracting downloaded target ...
      if (verbose) {
        print('Seems like the downloaded asset is a compressed file,');
        print('GPM may not create a desktop shortcut for such an app.');
      }
      print('Extracting package ...');
      bool result = await extract(packagePath, File(packagePath).parent.path);
      if (result) {
        print('Extraction Completed ...');
        // trying to identify the app binary to create a desktop shortcut
        final appDir = File(packagePath).parent;
        final appBinary = File(combinePath([appDir.path, '${asset.repo}.exe']));
        if (appBinary.existsSync()) {
          print("Creating a desktop shortcut ...".blue.bold);
          final code =
              WindowsUtils.createDesktopShortcut(asset.repo, appBinary.path);
          if (code != 0) {
            print("Sorry, we couldn't create a desktop shortcut for this app."
                .magenta
                .bold);
            print('Although, the download was successful.');
            if (yes('Would you like to open it in explorer? [y/N]: ')) {
              WindowsUtils.openInExlorer(appDir.path);
            }
          }
        }
        // removing compressed archive
        File(packagePath).deleteSync();
        print("Successfully installed ${asset.repo}.".green.bold);
      } else {
        print('A problem occurred while extracting ${packagePath.blue}');
        return 1;
      }
    }
    return 0;
  }

  static Future<int> _integrateDebianPackage(
      ReleaseAssetEntity asset, String packagePath) async {
    if (asset.isSetup()) {
      // this means the asset is actually a .deb package
      // and we need to install it using dpkg
      print("Installing package via dpkg ...".blue.bold);
      final exitCode = SystemService.executeSync('sudo dpkg -i $packagePath');
      if (exitCode == 0) {
        print("Successfully Installed Package via dpkg".green.bold);
      } else {
        print("Failed to install package via dpkg".red.bold);
      }
      return exitCode;
    }
    return await _integrateLinuxCommon(asset, packagePath);
  }

  static Future<int> _integrateArchPackage(
      ReleaseAssetEntity asset, String packagePath) async {
    if (asset.isSetup()) {
      // this means the asset is actually a .zst package
      // and we need to install it using dpkg
      print("Installing package via pacman ...".blue.bold);
      final exitCode = SystemService.executeSync('sudo pacman -U $packagePath');
      if (exitCode == 0) {
        print("Successfully Installed Package via pacman".green.bold);
      } else {
        print("Failed to install package via pacman".red.bold);
      }
      return exitCode;
    }
    return await _integrateLinuxCommon(asset, packagePath);
  }

  static Future<int> _integrateFedoraPackage(
      ReleaseAssetEntity asset, String packagePath) async {
    if (asset.isSetup()) {
      // this means the asset is actually a .rpm package
      // and we need to install it using dnf
      print("Installing package via pacman ...".blue.bold);
      final exitCode =
          SystemService.executeSync('sudo dnf install $packagePath');
      if (exitCode == 0) {
        print("Successfully Installed Package via dnf".green.bold);
      } else {
        print("Failed to install package via dnf".red.bold);
      }
      return exitCode;
    }
    return await _integrateLinuxCommon(asset, packagePath);
  }

  static Future<int> _integrateLinuxCommon(
      ReleaseAssetEntity asset, String packagePath) async {
    // moving the app to a secure location
    // to prevent deletion from 'gpm --clean' command
    movePath(packagePath, (packagePath = GPMStorage.toAppPath(asset)));

    if (asset.type == 'secondary') {
      // handle .AppImage
      // We sure have downloaded the binary and the meta data
      // but we are unsure about the app icon
      // treat .AppImage as .exe on Windows
      // When creating a desktop shortcut on windows, the platform
      // itself identifies the app icon from the binary (.exe)
      // but in case of any linux distros, they cannot do the same
      // so in case, that, a repo host an .AppImage in releases
      // then, it should have a `gpm.yaml` at root
      // with the `icon` property set to the url of the app
      // such that, we can download the icon later and provide the install xp
      // just like an app store or else we use the gpm icon

      packagePath = await _renameRelease(asset.appID, packagePath);
      print("Source: ${packagePath.blue.bold}");

      if (verbose) {
        print(
            "Looks like we have downloaded an app ${"(not a setup)".magenta.bold}.");
        print("Don't worry, GPM can still manage updates for it.");
        print("You can launch it or pin it where you want.");
        print("Just do not move it away from ~/.gpm/apps.".yellow.dim);
        print(
            "If you do so, GPM would think you deleted the app and it will not be updated anymore."
                .yellow
                .dim);
      }

      // we need to make sure that the binary is executable
      SystemService.makeExecutable(packagePath);

      print("Creating a desktop shortcut ...".blue.bold);
      final code =
          await LinuxUtils.createDesktopShortcut(asset.appID, packagePath);
      if (code != 0) {
        print("Sorry, we couldn't create a desktop shortcut for this app."
            .magenta
            .bold);
        print('Although, the download was successful.');
        LinuxUtils.openInFiles(File(packagePath).parent.path);
      }
      print("Successfully installed ${asset.repo}.".green.bold);
    } else if (asset.type == 'others') {
      print("Source: ${packagePath.blue.bold}");
      // extracting downloaded target ...
      if (verbose) {
        print('Seems like the downloaded asset is a compressed file,');
        print('GPM may not create a desktop shortcut for such an app.');
      }
      print('Extracting package ...');
      bool result = await extract(packagePath, File(packagePath).parent.path);
      if (result) {
        print('Extraction Completed ...');

        // trying to identify the app binary to create a desktop shortcut
        final appDir = File(packagePath).parent;
        final appBinary = File(combinePath([appDir.path, (asset.repo)]));

        // we need to make sure that the binary is executable
        SystemService.makeExecutable(appBinary.path);

        if (appBinary.existsSync()) {
          print("Creating a desktop shortcut ...".blue.bold);
          final code = await LinuxUtils.createDesktopShortcut(
              asset.appID, appBinary.path);
          if (code != 0) {
            print("Sorry, we couldn't create a desktop shortcut for this app."
                .magenta
                .bold);
            print('Although, the download was successful.');
            LinuxUtils.openInFiles(appDir.path);
          }
        }
        // removing compressed archive
        File(packagePath).deleteSync();
        print("Successfully installed ${asset.repo}.".green.bold);
      } else {
        print('A problem occurred while extracting ${packagePath.blue}');
        return 1;
      }
    }
    return 0;
  }

  static Future<String> _renameRelease(String id, String packagePath) async {
    final spec = await APIService.getGPMSpecification(id);
    if (spec != null) {
      final releases = spec['releases'];
      if (releases != null) {
        dynamic target = releases[SystemService.os];
        if (target == null) {
          if (SystemService.isKnownLinuxDistribution) {
            target = releases['linux'];
          }
        }
        if (target != null) {
          final destination = target['secondary']['renameTo'];
          if (destination != null) {
            final file = File(packagePath);
            final parent = file.parent;
            final targetPath = "${parent.path}/$destination";
            file.renameSync(targetPath);
            packagePath = targetPath;
          }
        }
      }
    }
    return packagePath;
  }
}
