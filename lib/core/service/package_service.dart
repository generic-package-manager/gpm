import 'dart:io';

import 'package:chalkdart/chalkstrings.dart';
import 'package:gpm/core/logging/exit_codes.dart';
import 'package:yaml/yaml.dart';

import '../../extras/extras.dart';
import '../../gpm_cli.dart';
import '../provider/compatible_asset_provider.dart';
import 'api_service.dart';
import 'build_service.dart';
import 'installation_service.dart';
import 'package_disintegration_service.dart';
import 'package_registry_service.dart';
import 'system_service.dart';
import 'update_service.dart';
import 'upgrade_service.dart';

class PackageService {
  PackageService._();

  static Future<String?> findFullQualifiedID(String? id,
      {bool searchOnGitHub = true}) async {
    if (id == null) {
      return null;
    }
    if (id.contains('/')) {
      return id;
    }
    final releases = PackageRegistryService.getInstalledReleases();
    for (final package in releases) {
      if (package.repo == id) {
        return package.appID;
      }
    }
    final sources = PackageRegistryService.getInstalledSources();
    for (final package in sources) {
      if (package.repo == id) {
        return package.appID;
      }
    }
    // searching on github
    if (searchOnGitHub) {
      print("Searching on github ...");
      final searchResult = await APIService.searchOnGitHub(id);
      final githubPackages =
          searchResult.isEmpty ? <String>[] : searchResult.keys.toList();
      if (githubPackages.isEmpty) {
        print("Could'nt find a package with that name.");
      } else {
        if (githubPackages.length == 1) {
          print(
              "Found a package: ☆ ${searchResult[githubPackages.first]} - ${githubPackages.first.bold}");
          if (yes("Are you looking for this one? (y/N): ")) {
            return githubPackages.first;
          } else {
            print("Couldn't find any packages with the name: $id");
          }
        } else {
          print("Found ${githubPackages.length} packages with this name ...");
          for (final package in githubPackages) {
            int index = githubPackages.indexOf(package) + 1;
            print(
                "${index > 9 ? "" : " "}$index) ☆ ${searchResult[package]} \t- $package");
          }
          stdout.write("Please select one of the above packages: ".bold);
          int index = int.tryParse(stdin.readLineSync() ?? "0") ?? 0;
          if (--index >= 0 && index < githubPackages.length) {
            print("Selected: ${githubPackages[index].bold}");
            return githubPackages[index];
          } else {
            print("Invalid index selected: ${++index}");
          }
        }
      }
    } else {
      print("Could'nt find a package installed with that name.");
    }

    terminateInstance(exitCode: ExitCodes.unavailable);
    return null;
  }

  static void handleInstall(String? id, {required bool explicitCall}) async {
    id = await findFullQualifiedID(id);
    if (id != null) {
      final exists = await APIService.doesRepoExists(id);
      final repo = parseRepoName(id);
      if (exists) {
        await _handlePackageInstall(id, repo, explicitCall);
      } else {
        print("Repository \"$repo\" does not exists or is a private repo.");

        if (explicitCall) terminateInstance(exitCode: ExitCodes.unavailable);
      }
    }
  }

  static Future<void> _handlePackageInstall(
      String id, String repo, bool explicitCall) async {
    // Checking if the package is already installed
    if (PackageRegistryService.isPackageInstalled(id)) {
      await handleUpdate(id, explicitCall: explicitCall);
      return;
    }

    if (mode == 'release') {
      /// RELEASE MODE
      // When package is not installed
      // we start fetching the [targetTag] release from github
      print("Fetching $targetTag release from $repo ...");
      final assets = await APIService.fetchAssets(id);
      if (assets.isEmpty) {
        print(
            "${"$repo has no asset in its ".red}${"$targetTag release.".bold.red}");
        if (explicitCall) terminateInstance(exitCode: ExitCodes.unavailable);
      } else {
        print(
            "Identifying ${SystemService.os} compatible release candidates ...");
        final provider = CompatibleReleaseAssetProvider.fromList(
          assets: assets,
          target: SystemService.osObject,
        );
        int total = 0;
        String targetType = 'compressed (zip or other)';
        final extensions = ExtensionPriorities.getExtensionsWithPriorityOrder(
            SystemService.osObject);
        if (provider.hasPrimary) {
          total += provider.primary.length;
          targetType = extensions.first;
        } else if (provider.hasSecondary) {
          total += provider.secondary.length;
          targetType = extensions[1];
        } else {
          total += provider.others.length;
        }
        if (total > 0) {
          print("Found $total $targetType release candidates.");
          await InstallationService.initReleaseInstall(
              repo, provider, extensions, explicitCall);

          if (explicitCall) terminateInstance();
        } else {
          print("No installable candidates found".red);

          if (explicitCall) terminateInstance(exitCode: ExitCodes.unavailable);
        }
      }
    } else {
      await handleSourceModeInstall(id, repo, explicitCall);
    }
  }

  static Future<bool> handleSourceModeInstall(
      id, repo, bool explicitCall) async {
    // SOURCE MODE
    print('Getting Build Instructions ...');
    final spec = await APIService.getGPMSpecification(id);
    if (spec == null) {
      print(
        '$repo does not have gpm.yaml, cannot install from source.'.red.bold,
      );
      print(
          'Please create an issue to support gpm at https://github.com/$id/issues/new'
              .bold
              .dim);

      if (explicitCall) terminateInstance(exitCode: ExitCodes.unavailable);
    } else {
      final result = await BuildService.handleBuildFromSource(id, repo, spec);
      if (explicitCall) {
        terminateInstance(
          exitCode: result ? ExitCodes.fine : ExitCodes.error,
        );
      }
      return result;
    }
    return false;
  }

  static void handleRemove(String? id) async {
    id = await findFullQualifiedID(id, searchOnGitHub: false);
    if (id != null) {
      if (!PackageRegistryService.isPackageInstalled(id)) {
        print("Couldn't find ${parseRepoName(id).red.bold} in package list.");
        terminateInstance(exitCode: ExitCodes.unavailable);
      } else {
        PackageDisintegrationService.disintegrate(id);
      }
    }
  }

  static Future<bool> handleUpdate(String? id,
      {required bool explicitCall}) async {
    id = await findFullQualifiedID(id);
    if (id != null) {
      final exists = await APIService.doesRepoExists(id);
      final repo = parseRepoName(id);
      if (exists) {
        return await handlePackageUpdate(id, repo, explicitCall);
      } else {
        print("Repository \"$repo\" does not exists or is a private repo.");

        if (explicitCall) terminateInstance(exitCode: ExitCodes.unavailable);
      }
    }
    return false;
  }

  static Future<bool> handlePackageUpdate(
    String id,
    String repo,
    bool explicitCall, {
    bool showUpdateLogs = true,
    bool forceTarget = false,
    String? forceTag,
    bool forceCommit = false,
    String? forceCommitHash,
  }) async {
    // first, we check if the app is installed in the registry
    if (PackageRegistryService.isPackageInstalled(id)) {
      // checking the previous mode of installation
      if (PackageRegistryService.isPackageInstalledViaReleaseMode(id)) {
        final release = PackageRegistryService.getReleaseObject(id);
        if (targetTag == 'latest' && release.explicitVersion) {
          // this means that the user is normally trying to update
          // a package which was specificially installed with certain tag name
          print(
              'WARNING: You explicitly installed $repo with tag ${release.tag},'
                  .yellow
                  .dim);
          print(
              'To update it, you also need to provide the tag name using --tag option, see help.\n'
                  .yellow
                  .dim);
        } else if (targetTag != 'latest') {
          forceTag = targetTag;
        }
        if (forceTarget) {
          targetTag = forceTag;
        }
        if (showUpdateLogs) {
          print("Checking for ${forceTag ?? "updates"} ...");
        }
        // further, we compare the tags
        final latestTag = forceTag ?? await APIService.getLatestTag(id);
        if (latestTag == release.tag) {
          print(
              '$repo is already installed with the latest version ${release.tag}');
        } else {
          if (showUpdateLogs) {
            print('${release.tag} is installed');
          }
          if (latestTag == null) {
            print('Unable to check for updates for $repo!'.red.bold);
          } else {
            if (showUpdateLogs) {
              print('However, ${latestTag.blue.bold} is available ...');
            }
            if (yes('Proceed to update (y/N): ')) {
              final assets = await APIService.fetchAssets(id);
              if (assets.isEmpty) {
                print(
                    "${"$repo has no asset in its ".red}${"latest release.".bold.red}");
              } else {
                print(
                    "Identifying ${SystemService.os} compatible release candidates ...");
                final provider = CompatibleReleaseAssetProvider.fromList(
                  assets: assets,
                  target: SystemService.osObject,
                );

                if (_hasCompatibleReleaseTarget(release.type, provider)) {
                  final extensions =
                      ExtensionPriorities.getExtensionsWithPriorityOrder(
                          SystemService.osObject);
                  final isChosenIndexAvailable =
                      await UpdateService.initReleaseUpdate(
                    repo,
                    provider,
                    extensions,
                    release,
                    explicitCall,
                  );
                  if (!isChosenIndexAvailable) {
                    print(
                        'The source repo no longer provides the choice of release you made: #${release.index}'
                            .red
                            .bold);
                    print('You need to remove and reinstall $id.'.red.bold);

                    if (explicitCall) {
                      terminateInstance(exitCode: ExitCodes.unavailable);
                    }
                  } else {
                    if (explicitCall) terminateInstance();
                    return true;
                  }
                } else {
                  print(
                      'The source repo no longer provides the type of release you installed'
                          .red
                          .bold);
                  print('You need to remove and reinstall $id.'.red.bold);
                }
              }
            }
          }
        }
      } else {
        print('Checking for updates ...');
        final sourceEntity = PackageRegistryService.getSourceObject(id);
        if (forceCommit) {
          commitHash = forceCommitHash;
        }
        final latestCommit = forceCommit
            ? forceCommitHash
            : (commitHash ?? await APIService.getLatestCommit(id));
        if (latestCommit != null) {
          // the stored commit hash in registry is actually the full code
          // and the one we are getting through the API is the short code
          // so, we need to cut-out the short code from the full code
          final currentCommit = sourceEntity.commitHash.substring(0, 7);
          if (currentCommit == latestCommit) {
            print(
                '$repo is already installed with the latest commit $currentCommit');
          } else {
            print("Currently Installed Commit \"$currentCommit\" ...");
            print("However, Commit \"$latestCommit\" is available ...");
            if (yes(
                'Do you want to build from source with the ${forceCommit ? forceCommitHash : "latest"} commit? (y/N): ')) {
              return await handleSourceModeInstall(id, repo, explicitCall);
            }
          }
        } else {
          print('Couldn\'t get latest commit from GitHub.');
        }
      }
    }
    // the app wasn't installed so, it wasn't updated by `gpm --update`

    if (explicitCall) terminateInstance();
    return false;
  }

  static bool _hasCompatibleReleaseTarget(
      String type, CompatibleReleaseAssetProvider provider) {
    if (type == 'primary') {
      for (var asset in provider.primary) {
        asset.type = type;
      }
      return provider.hasPrimary;
    } else if (type == 'secondary') {
      for (var asset in provider.secondary) {
        asset.type = type;
      }
      return provider.hasSecondary;
    } else if (type == 'others') {
      for (var asset in provider.others) {
        asset.type = type;
      }
      return provider.hasOthers;
    }
    return false;
  }

  static void handleUpgrade(_) async {
    if (_) {
      // fetching a list of installed apps
      final appIDs = PackageRegistryService.getInstalledApps();
      if (appIDs.isEmpty) {
        print('Couldn\'t find any packages installed via gpm.');
      } else {
        UpgradeService.doUpgrade(appIDs);
      }
    }
  }

  static void handleRollback(String? id, {required bool explicitCall}) async {
    id = await findFullQualifiedID(id, searchOnGitHub: false);
    if (id != null) {
      final exists = await APIService.doesRepoExists(id);
      final repo = parseRepoName(id);
      if (exists) {
        await handlePackageRollback(id, repo, explicitCall);
      } else {
        print("Repository \"$repo\" does not exists or is a private repo.");

        if (explicitCall) terminateInstance(exitCode: ExitCodes.unavailable);
      }
    }
  }

  static Future<void> handlePackageRollback(
      String id, String repo, bool explicitCall) async {
    if (PackageRegistryService.isPackageInstalled(id)) {
      if (PackageRegistryService.isPackageInstalledViaReleaseMode(id)) {
        print('Getting previous versions ...');
        final release = PackageRegistryService.getReleaseObject(id);
        final index = release.versions.indexOf(release.tag) - 1;
        final targetable = index >= 0;
        if (!targetable) {
          print('No previous versions available to rollback $repo.'.red.bold);

          if (explicitCall) terminateInstance(exitCode: ExitCodes.unavailable);
        } else {
          await handlePackageUpdate(
            id,
            repo,
            explicitCall,
            forceTag: release.versions[index],
            forceTarget: true,
          );
        }
      } else {
        print('Getting previous commits ...');
        final source = PackageRegistryService.getSourceObject(id);
        final versions = PackageRegistryService.getSourceCommits(id);
        final index = versions.indexOf(source.commitHash) - 1;
        final targetable = index >= 0;
        if (!targetable) {
          print('No previous commits available to rollback $repo.'.red.bold);

          if (explicitCall) terminateInstance(exitCode: ExitCodes.unavailable);
        } else {
          await handlePackageUpdate(
            id,
            repo,
            explicitCall,
            forceCommitHash: versions[index],
            forceCommit: true,
          );
        }
      }
    } else {
      print('Couldn\'t find $repo in installed packages.');

      if (explicitCall) terminateInstance(exitCode: ExitCodes.unavailable);
    }
  }

  static void handleRollforward(String? id,
      {required bool explicitCall}) async {
    id = await findFullQualifiedID(id, searchOnGitHub: false);
    if (id != null) {
      final exists = await APIService.doesRepoExists(id);
      final repo = parseRepoName(id);
      if (exists) {
        await handlePackageRollforward(id, repo, explicitCall);
      } else {
        print("Repository \"$repo\" does not exists or is a private repo.");

        if (explicitCall) terminateInstance(exitCode: ExitCodes.unavailable);
      }
    }
  }

  static Future<void> handlePackageRollforward(
      String id, String repo, bool explicitCall) async {
    if (PackageRegistryService.isPackageInstalled(id)) {
      if (PackageRegistryService.isPackageInstalledViaReleaseMode(id)) {
        print('Getting newer versions ...');
        final release = PackageRegistryService.getReleaseObject(id);
        final index = release.versions.indexOf(release.tag) + 1;
        final targetable = index < release.versions.length;
        if (!targetable) {
          print('No newer versions available to rollforward $repo.'.red.bold);

          if (explicitCall) terminateInstance(exitCode: ExitCodes.unavailable);
        } else {
          await handlePackageUpdate(
            id,
            repo,
            explicitCall,
            forceTag: release.versions[index],
            forceTarget: true,
          );
        }
      } else {
        print('Getting newer commits ...');
        final source = PackageRegistryService.getSourceObject(id);
        final versions = PackageRegistryService.getSourceCommits(id);
        final index = versions.indexOf(source.commitHash) + 1;
        final targetable = index < versions.length;
        if (!targetable) {
          print('No newer commits available to rollforward $repo.'.red.bold);

          if (explicitCall) terminateInstance(exitCode: ExitCodes.unavailable);
        } else {
          await handlePackageUpdate(
            id,
            repo,
            explicitCall,
            forceCommitHash: versions[index],
            forceCommit: true,
          );
        }
      }
    } else {
      print('Couldn\'t find $repo in installed packages.');

      if (explicitCall) terminateInstance(exitCode: ExitCodes.unavailable);
    }
  }

  static Future<void> buildLocally(String? id) async {
    id = await findFullQualifiedID(id, searchOnGitHub: false);
    if (id != null) {
      // checking `gpm.yaml` specification
      final specFile = File('gpm.yaml');
      if (!specFile.existsSync()) {
        print(
            'Couldn\'t find `gpm.yaml` specification file in the current directory.'
                .red
                .bold);
        terminateInstance(exitCode: ExitCodes.unavailable);
        return;
      }

      // reading specification
      final contents = specFile.readAsStringSync();
      final spec = await loadYaml(contents);
      final result = await BuildService.handleBuildFromSource(
        id,
        parseRepoName(id),
        spec,
        isLocalBuild: true,
      );
      terminateInstance(
        exitCode: result ? ExitCodes.fine : ExitCodes.error,
      );
    }
  }
}
