import 'dart:io';

import 'package:chalkdart/chalkstrings.dart';
import 'package:cli_table/cli_table.dart';
import 'package:gpm/core/logging/exit_codes.dart';
import 'package:gpm/core/service/package_service.dart';
import 'package:path/path.dart';

import '../../gpm_cli.dart';
import '../../entity/asset_entity.dart';
import '../../entity/source_entity.dart';
import '../storage/gpm_storage.dart';
import '../storage/omegaui/json_configurator.dart';
import '../storage/storage_keys.dart';

class PackageRegistryService {
  PackageRegistryService._();

  static void lockUpdates({
    required String? id,
  }) async {
    id = await PackageService.findFullQualifiedID(id, searchOnGitHub: false);
    if (id != null) {
      final configPath = GPMStorage.toRegistryPath(id);
      bool exists = File(configPath).existsSync();
      if (exists) {
        final config = JsonConfigurator(configPath: configPath);
        if (config.get('explicit_version') ?? false) {
          print("$id is already locked.");
        } else {
          config.put('explicit_version', true);
          print("$id will not receive updates from now on.".red);
        }
        terminateInstance();
      } else {
        print("$id is not installed.");
        print("run the following to install it:");
        print("gpm --install $id".dim.bold);
        print("after it's installed, you can lock it.");
        terminateInstance(exitCode: ExitCodes.unavailable);
      }
    }
  }

  static void unlockUpdates({
    required String? id,
  }) async {
    id = await PackageService.findFullQualifiedID(id, searchOnGitHub: false);
    if (id != null) {
      final configPath = GPMStorage.toRegistryPath(id);
      bool exists = File(configPath).existsSync();
      if (exists) {
        final config = JsonConfigurator(configPath: configPath);
        if (config.get('explicit_version') ?? false) {
          config.put('explicit_version', false);
          print("$id will receive updates from now on.".blue);
        } else {
          print("$id is already unlocked.");
        }
        terminateInstance();
      } else {
        print("$id is not installed.");
        print("run the following to install it:");
        print("gpm --install $id".dim.bold);
        terminateInstance(exitCode: ExitCodes.unavailable);
      }
    }
  }

  static void registerRelease({
    required ReleaseAssetEntity asset,
  }) async {
    final configPath = GPMStorage.toRegistryPath(asset.appID);
    bool isNewInstall = !File(configPath).existsSync();
    final config = JsonConfigurator(configPath: configPath);
    if (!asset.versions.contains(asset.tag)) {
      asset.versions.add(asset.tag);
    }
    config.addAll(asset.toMap());
    config.put(StorageKeys.mode, 'release');
    if (isNewInstall) {
      config.put(StorageKeys.installedAt, DateTime.now().toString());
    } else {
      config.put(StorageKeys.updatedAt, DateTime.now().toString());
    }
  }

  static void remove({required String id}) {
    final registryFile = File(GPMStorage.toRegistryPath(id));
    if (registryFile.existsSync()) {
      registryFile.deleteSync();
    }
  }

  static bool isPackageInstalled(String id) {
    final registryFile = File(GPMStorage.toRegistryPath(id));
    return registryFile.existsSync();
  }

  static bool isPackageInstalledViaReleaseMode(String id) {
    final configPath = GPMStorage.toRegistryPath(id);
    final config = JsonConfigurator(configPath: configPath);
    final mode = config.get(StorageKeys.mode);
    if (mode == null) {
      config.deleteSync();
    }
    return mode == 'release';
  }

  static bool isPackageInstalledViaSourceMode(String id) {
    final configPath = GPMStorage.toRegistryPath(id);
    final config = JsonConfigurator(configPath: configPath);
    final mode = config.get(StorageKeys.mode);
    if (mode == null) {
      config.deleteSync();
    }
    return mode == 'source';
  }

  static ReleaseAssetEntity getReleaseObject(String id) {
    final configPath = GPMStorage.toRegistryPath(id);
    final config = JsonConfigurator(configPath: configPath);
    return ReleaseAssetEntity.fromMap(
      config.get('owner'),
      config.get('repo'),
      config.get('tag'),
      config.config,
    );
  }

  static SourceEntity getSourceObject(String id) {
    final configPath = GPMStorage.toRegistryPath(id);
    final config = JsonConfigurator(configPath: configPath);
    return SourceEntity.fromMap(
      config.config,
    );
  }

  static List<String> getInstalledApps() {
    List<String> appIDs = [];
    final appRegistries = GPMStorage.registryDir.listSync(recursive: true);
    appRegistries
        .removeWhere((e) => !e.path.endsWith('.json')); // filtering json files
    for (final registry in appRegistries) {
      final owner = basename(registry.parent.path);
      final repo = basenameWithoutExtension(registry.path);
      final id = '$owner/$repo';
      appIDs.add(id);
    }
    return appIDs;
  }

  static List<ReleaseAssetEntity> getInstalledReleases() {
    final installedReleases = <ReleaseAssetEntity>[];
    final appIDs = getInstalledApps();
    for (final id in appIDs) {
      if (PackageRegistryService.isPackageInstalledViaReleaseMode(id)) {
        installedReleases.add(PackageRegistryService.getReleaseObject(id));
      }
    }
    return installedReleases;
  }

  static List<SourceEntity> getInstalledSources() {
    final installedSources = <SourceEntity>[];
    final appIDs = getInstalledApps();
    for (final id in appIDs) {
      if (PackageRegistryService.isPackageInstalledViaSourceMode(id)) {
        installedSources.add(PackageRegistryService.getSourceObject(id));
      }
    }
    return installedSources;
  }

  static void listInstalledApps(_) {
    if (_) {
      if (listMode == null || listMode == 'release') {
        // gettings all apps
        final installedReleases = getInstalledReleases();
        installedReleases.sort((a, b) => a.appID.compareTo(b.appID));
        // filtering mode
        final none = listType == 'all';
        // printing information in tabular form
        final table = Table(
          header: [
            'Package Name'.blue.bold,
            'Installed Version'.blue.bold,
            if (none) 'Type'.blue.bold,
          ],
          columnWidths: [30, 20],
        );
        for (final asset in installedReleases) {
          if (none || asset.type == listType) {
            table.add([
              '${asset.owner}/${asset.repo}',
              asset.tag,
              if (none) asset.type,
            ]);
          }
        }
        if (table.isNotEmpty) {
          print('Apps Installed via release mode');
          print(table.toString());
        } else {
          print(
              'Couldn\'t find any packages installed via gpm (release mode).');
        }
      }
      if (listMode == null || listMode == 'source') {
        // gettings all apps
        final installedSources = getInstalledSources();
        installedSources.sort((a, b) => a.appID.compareTo(b.appID));
        // printing information in tabular form
        final table = Table(
          header: [
            'Package Name'.blue.bold,
            'Installed Commit Hash'.blue.bold,
          ],
          columnWidths: [30, 35],
        );
        for (final asset in installedSources) {
          table.add([
            '${asset.owner}/${asset.repo}',
            asset.commitHash,
          ]);
        }
        if (table.isNotEmpty) {
          print('Apps Installed via source mode');
          print(table.toString());
        } else {
          print('Couldn\'t find any packages installed via gpm (source mode).');
        }
      }
      terminateInstance();
    }
  }

  static void registerSource(SourceEntity source) {
    final configPath =
        GPMStorage.toRegistryPath('${source.owner}/${source.repo}');
    bool isNewInstall = !File(configPath).existsSync();
    final config = JsonConfigurator(configPath: configPath);
    config.addAll(source.toMap());
    config.put(StorageKeys.mode, 'source');
    config.add(StorageKeys.versions, source.commitHash);
    if (isNewInstall) {
      config.put(StorageKeys.installedAt, DateTime.now().toString());
    } else {
      config.put(StorageKeys.updatedAt, DateTime.now().toString());
    }
  }

  static List<String> getSourceCommits(id) {
    final configPath = GPMStorage.toRegistryPath(id);
    final config = JsonConfigurator(configPath: configPath);
    return List<String>.from(config.get('versions') ?? <String>[]);
  }
}
