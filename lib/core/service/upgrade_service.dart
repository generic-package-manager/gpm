import 'package:chalkdart/chalkstrings.dart';
import 'package:cli_spin/cli_spin.dart';
import 'package:cli_table/cli_table.dart';
import 'package:gpm/core/storage/gpm_storage.dart';
import 'package:gpm/core/storage/omegaui/json_configurator.dart';
import 'package:gpm/gpm_cli.dart';

import '../../entity/asset_entity.dart';
import '../../entity/source_entity.dart';
import '../../extras/extras.dart';
import 'api_service.dart';
import 'package_registry_service.dart';
import 'package_service.dart';

class UpgradeService {
  UpgradeService._();

  static final _installedReleases =
      PackageRegistryService.getInstalledReleases();
  static final _installedSources = PackageRegistryService.getInstalledSources();

  // map of release packages with latest versions
  static final Map<String, String> _versionsData = {};

  // map of source packages with latest versions
  static final Map<String, String> _sourceUpdateData = {};

  static Future<List<String>> checkUpdates({bool explicitCall = false}) async {
    // a map to store fetched release data
    Map<String, List<ReleaseAssetEntity>> releaseUpdateData = {};
    if (_installedReleases.isNotEmpty) {
      print(
          'Checking updates for ${_installedReleases.length} packages installed via release mode ...');

      // a future to store the api fetch list
      List<Future> futures = [];

      // creating a cli spinner
      final spinner = CliSpin(
        text: 'Fetching release data ...',
        spinner: CliSpinners.pipe,
      ).start();

      // start time
      final startTime = DateTime.now();

      // internal function to check
      // - availability of repo
      // - availability of assets
      Future<void> queryRepo(String id) async {
        if (await APIService.doesRepoExists(id)) {
          releaseUpdateData[id] = await APIService.fetchAssets(id);
        }
      }

      // initiating api service
      for (final app in _installedReleases) {
        futures.add(queryRepo(app.appID));
      }

      await Future.wait(futures);

      spinner.stopAndPersist(
        text:
            '➜ ${'[OK]'.green.bold} Fetch Completed, ${'[took ${formatTime(DateTime.now().difference(startTime))}]'}.',
      );
    }

    // a function to check if an app can be updated
    bool isReleaseUpdatable(ReleaseAssetEntity installedRelease) {
      if (installedRelease.explicitVersion) {
        // this means that the user explicitly installed
        // a specific tag, so, we omit updates for such repos
        return false;
      }
      final id = '${installedRelease.owner}/${installedRelease.repo}';
      if (releaseUpdateData.containsKey(id)) {
        final releases = releaseUpdateData[id]!;
        if (releases.isNotEmpty) {
          final latestTag = releases.first.tag;
          final updateAvailable = installedRelease.tag != latestTag;
          if (updateAvailable) {
            _versionsData[id] = latestTag;
          }
          return updateAvailable;
        }
      }
      return false;
    }

    // next, we compare and find which apps need an update
    final updatableApps = <String>[];
    for (final installedRelease in _installedReleases) {
      if (isReleaseUpdatable(installedRelease)) {
        updatableApps.add(installedRelease.appID);
      }
    }

    // Now, we check the apps installed via source mode
    final futures = <Future>[];
    Future<void> fetchLatestCommit(id) async {
      if (await APIService.doesRepoExists(id)) {
        final commit = await APIService.getLatestCommit(id);
        if (commit != null) {
          _sourceUpdateData[id] = commit;
        }
      }
    }

    if (_installedSources.isNotEmpty) {
      print(
          'Checking updates for ${_installedSources.length} packages installed via source mode ...');

      // start time
      final startTime = DateTime.now();

      // creating a cli spinner
      final spinner = CliSpin(
        text: 'Fetching commit data ...',
        spinner: CliSpinners.pipe,
      ).start();

      for (final source in _installedSources) {
        futures.add(fetchLatestCommit(source.appID));
      }

      await Future.wait(futures);

      spinner.stopAndPersist(
        text:
            '➜ ${'[OK]'.green.bold} Fetch Completed, ${'[took ${formatTime(DateTime.now().difference(startTime))}]'}.',
      );

      // a function to check if an app can be updated
      bool isSourceUpdatable(SourceEntity source) {
        if (source.explicitVersion) {
          // this means that the user explicitly marked an app as
          // not-suitable for update
          // so, we omit updates for such repos
          return false;
        }
        final id = source.appID;
        if (_sourceUpdateData.containsKey(id)) {
          return _sourceUpdateData[id] != source.commitHash.substring(0, 7);
        }
        return false;
      }

      for (final installedSource in _installedSources) {
        if (isSourceUpdatable(installedSource)) {
          updatableApps.add(installedSource.appID);
        }
      }
    }

    if (updatableApps.isNotEmpty) {
      if (explicitCall) {
        print('${updatableApps.length} packages can be updated ...');
      }

      final updatableReleases = <ReleaseAssetEntity>[];

      for (final release in _installedReleases) {
        if (updatableApps.contains(release.appID)) {
          updatableReleases.add(release);
        }
      }

      final updatableSources = <SourceEntity>[];

      for (final source in _installedSources) {
        if (updatableApps.contains(source.appID)) {
          updatableSources.add(source);
        }
      }

      // a function to get installed tag by package id
      String getTag(String id) {
        for (final installedRelease in _installedReleases) {
          final appID = installedRelease.appID;
          if (appID == id) {
            return installedRelease.tag;
          }
        }
        return 'unknown';
      }

      // a function to get installed commit by package id
      String getCommitHash(String id) {
        for (final installSource in _installedSources) {
          final appID = installSource.appID;
          if (appID == id) {
            return installSource.commitHash;
          }
        }
        return 'unknown';
      }

      // json file to be written for update references
      final updateConfig = JsonConfigurator(
          configPath: combinePath([GPMStorage.root, 'update-data.json']));
      updateConfig.deleteSync();

      if (updatableReleases.isNotEmpty) {
        // printing releases update information in tabular form
        final table = Table(
          header: [
            'Package Name'.blue.bold,
            'Installed Version'.blue.bold,
            'Available Version'.blue.bold
          ],
          columnWidths: [30, 20, 20],
        );
        for (final app in updatableReleases) {
          final tag = getTag(app.appID);
          final latest = _versionsData[app.appID].toString();
          table.add([
            app.appID,
            tag,
            latest.blue.bold,
          ]);
          if (explicitCall) {
            updateConfig.add('releases', {
              'package': app.appID,
              'current': tag,
              'latest': latest,
            });
          }
        }
        print(table.toString());
      }

      if (updatableSources.isNotEmpty) {
        // printing releases update information in tabular form
        final table = Table(
          header: [
            'Package Name'.blue.bold,
            'Installed Commit'.blue.bold,
            'Available Commit'.blue.bold
          ],
          columnWidths: [30, 20, 20],
        );
        for (final app in updatableSources) {
          final commitHash = getCommitHash(app.appID);
          final latest = _sourceUpdateData[app.appID].toString();
          table.add([
            app.appID,
            commitHash,
            latest.blue.bold,
          ]);
          if (explicitCall) {
            updateConfig.add('sources', {
              'package': app.appID,
              'current': commitHash.substring(0, 7),
              'latest': latest,
            });
          }
        }
        print(table.toString());
      }
    } else {
      if (explicitCall) {
        print('All your apps are already up-to-date.');
      }
    }
    if (explicitCall) {
      terminateInstance();
    }
    return updatableApps;
  }

  static Future<void> doUpgrade(List<String> appIDs) async {
    final updatableApps = await checkUpdates();
    // now, we got the repos which can be updated
    if (updatableApps.isNotEmpty) {
      print('${updatableApps.length} packages can be updated ...');
      if (!yes('Do you wish to upgrade? (y/N): ')) {
        terminateInstance();
        return;
      }

      // putting yesToAll to true
      yesToAll = true;

      // updating apps one by one
      int count = 0;
      for (final id in updatableApps) {
        print('➜ Updating $id ...'.magenta);
        bool result = await PackageService.handlePackageUpdate(
          id,
          parseRepoName(id),
          false,
          showUpdateLogs: false,
        );
        if (result) {
          count++;
        }
      }
      if (count == updatableApps.length) {
        print('All your apps are now up-to-date.');
        terminateInstance();
      } else {
        int failed = updatableApps.length - count;
        print('Failed to update $failed apps.'.red.bold);
        if (count != 0) {
          print('Updated $count to their latest versions.'.green.bold.dim);
        }
        terminateInstance(exitCode: failed);
      }
    } else {
      print('All your apps are already up-to-date.');
      terminateInstance();
    }
  }
}
