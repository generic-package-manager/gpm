import 'dart:async';
import 'dart:io';

import 'package:chalkdart/chalkstrings.dart';
import 'package:chalkdart/chalkstrings_x11.dart';
import 'package:cli_spin/cli_spin.dart';
import 'package:gpm/core/logging/exit_codes.dart';
import 'package:gpm/core/service/api_service.dart';
import 'package:gpm/core/storage/gpm_instance_manager.dart';
import 'package:gpm/extras/version_utils.dart';
import 'package:gpm/gpm_cli.dart' as cli;
import 'package:gpm/gpm_cli.dart';
import 'package:path/path.dart';

import '../../entity/source_entity.dart';
import '../../extras/extras.dart';
import '../../extras/linux_utils.dart';
import '../../extras/windows_utils.dart';
import '../provider/build_data_provider.dart';
import '../storage/gpm_storage.dart';
import 'download_service.dart';
import 'package_registry_service.dart';
import 'system_service.dart';

class BuildService {
  BuildService._();

  static Future<bool> handleBuildFromSource(
    String id,
    String repo,
    dynamic spec, {
    bool isLocalBuild = false,
  }) async {
    print('Checking platform compatibility ...');
    bool buildSuccess = false; // flag storing result of operation
    final provider = BuildDataProvider.fromMap(spec);
    if (!provider.isHostSupported()) {
      print(
          '${id.blue.bold} doesn\'t supports building from source on ${SystemService.os.magenta.bold.dim} (your operating system).'
              .red
              .bold);
    } else {
      print('Package Type: ${provider.type.blue.bold}');
      final platformBuildData = provider.getTargetPlatformBuildInstructions();
      bool hasSatisfiedDependencies = true;
      // Checking dependencies ...
      if (platformBuildData.hasDependencies) {
        print('Verifying Dependencies ...');
        for (final dependency in platformBuildData.dependencies) {
          stdout.write(
              'Finding ${dependency.executable.blue.bold} ${dependency.version} ... ');
          final exists =
              SystemService.doesExecutableExists(dependency.executable);
          if (exists) {
            if (dependency.hasVersion) {
              final version = dependency.version;
              if (dependency.isVersionSatisfied()) {
                stdout.writeln('${'found!.'.bold} ');
              } else {
                stdout.writeln(
                    '${'[ERROR] requires version $version'.red.bold} ');
                final installedVersion =
                    getVersionString(dependency.executable);
                if (installedVersion != null) {
                  stdout.writeln('[Installed Version] $installedVersion');
                }
                if (dependency.hasHelp) {
                  print('➜ [HELP] ${dependency.help.blue}');
                }
                hasSatisfiedDependencies = false;
              }
            } else {
              stdout.writeln('${'found!.'.bold} ');
            }
          } else {
            stdout.writeln('${'[NO]'.red.bold} ');
            bool dependencyResolved = false;
            if (dependency.hasInstallCommand) {
              print(
                  "Attempting to resolve dependency: ${dependency.executable.blue} ...");
              print(
                  "➜ ${"[EXECUTING]".aliceBlue.dim} ${dependency.installCommand}");
              SystemService.executeSync(dependency.installCommand);
              if (!SystemService.doesExecutableExists(dependency.executable)) {
                print(
                    '➜ ${"[ERROR]".red.dim} Failed to install dependency. Please see help below.');
                hasSatisfiedDependencies = false;
              } else {
                print("➜ ${"[SUCCESS]".green.dim} Dependency resolved.");
                dependencyResolved = true;
              }
            }
            if (!dependencyResolved) {
              if (dependency.hasHelp) {
                print('➜ ${"[HELP]".yellow.dim} ${dependency.help.blue}');
              } else {
                print(
                    'You need to install [${dependency.executable.blue}] manually.'
                        .red);
              }
            }
            hasSatisfiedDependencies = dependencyResolved;
          }
        }
        // Starting repo cloning ...
        if (hasSatisfiedDependencies) {
          if (isLocalBuild) {
            buildSuccess = await _buildFromSource(provider, platformBuildData,
                id, Directory.current.absolute.path, isLocalBuild);
          } else {
            final target = repo;
            String generateText(int progress) {
              return "Cloning $target from GitHub ... ";
            }

            final spinner = CliSpin(
              text: generateText(0),
              spinner: CliSpinners.pipe,
            ).start();

            // removing older clones if any
            deleteDir(combinePath(
                [GPMStorage.downloadsDir.path, parseOwnerName(id), repo]));

            final path = GPMStorage.toClonedRepoPath(id);
            await DownloadService.download(
              url: cli.commitHash != null
                  ? 'https://github.com/omegaui/gpm/archive/${cli.commitHash}.zip'
                  : 'https://api.github.com/repos/$id/zipball',
              path: path,
              onProgress: (_) {},
              onComplete: (path) async {
                spinner.stopAndPersist(
                  text: '➜ ${'[OK]'.green.bold} Clone Completed.',
                );

                // Extracting tarball
                stdout.write('Extracting zipball ... ');
                bool success = await extract(path, File(path).parent.path);
                if (success) {
                  stdout.writeln('[SUCCESS]'.green);
                  // finding extraction root path
                  final rootDir = Directory(combinePath([
                    GPMStorage.downloadsDir.path,
                    parseOwnerName(id),
                    repo
                  ]));
                  final extractionDirPath = rootDir
                      .listSync()
                      .where((e) => FileSystemEntity.isDirectorySync(e.path))
                      .first
                      .path;
                  // removing zipball
                  File(path).deleteSync();
                  buildSuccess = await _buildFromSource(
                      provider, platformBuildData, id, extractionDirPath);
                } else {
                  stdout.writeln('[FAILED]'.red);
                }
              },
              onError: () {
                spinner.fail('Downloaded Failed.'.red);
                terminateInstance(exitCode: ExitCodes.error);
              },
            );
          }
        } else {
          print(
              'Please install all the dependencies required to build from source'
                  .red);
        }
      }
    }
    return buildSuccess;
  }

  static Future<bool> _buildFromSource(
    BuildDataProvider provider,
    PlatformBuildData platformBuildData,
    String id,
    String root, [
    bool isLocalBuild = false,
  ]) async {
    if (platformBuildData.note.isNotEmpty) {
      print('NOTE: ${platformBuildData.note.blue.bold}');
    }
    print('>> Starting build from source ...'.bold);
    final steps = platformBuildData.steps;
    bool failed = false;

    // executing steps asynchronously
    for (int index = 0; index < steps.length && !failed; index++) {
      final step = steps[index];
      // starting spinner
      final spinner = CliSpin(
        text: "${"[STEP ${index + 1} / ${steps.length}]".yellow} ${step.name}",
        spinner: CliSpinners.pipe,
        color: CliSpinnerColor.yellow,
      ).start();

      await Future(() async {
        final exitCode = await step.executeAsync(root);
        if (exitCode == 0) {
          spinner.stopAndPersist(
            text: '➜ ${'[DONE]'.green.bold} ${step.name}.',
          );
        } else {
          if (step.ignoreError) {
            spinner.stopAndPersist(
              text: '➜ ${'[WARNING]'.gold.bold} ${step.name}.',
            );
          } else {
            spinner.stopAndPersist(
              text: '➜ ${'[FAILED]'.red.bold} ${step.name}.',
            );
            failed = true;
          }
        }
      });
    }
    if (failed) {
      print('Couldn\'t install package due to build errors.');
      return false;
    } else {
      print('Build Completed Successfully.');
      print('Creating App Structure ...');
      final owner = parseOwnerName(id);
      final repo = parseRepoName(id);

      // here comes the use of [appData] file list
      final appData = platformBuildData.appData;

      // parsing commit hash from root path
      final rootName = basename(root);

      // basename example: omegaui-archy-358a957
      // commit-hash: 358a957
      final commitHash = isLocalBuild
          ? "local_build"
          : rootName.substring(rootName.lastIndexOf('-') + 1);
      final sourceEntity = SourceEntity(
        owner: owner,
        repo: repo,
        commitHash: commitHash,
        license: await APIService.getRepoLicense(id),
        installedAt: DateTime.now(),
        explicitVersion: cli.commitHash != null,
      );

      // moving binaries to [apps]
      final appPath = GPMStorage.toAppDirPath(id);
      final isGPMUpdatingItselfOnWindowsOS = Platform.isWindows &&
          PackageRegistryService.isPackageInstalled(id) &&
          owner == 'omegaui' &&
          repo == 'gpm';
      for (String path in appData) {
        // moving binaries to [apps]
        // making sure that gpm is not handling its own update
        final buildPath = combinePath([root, path]);
        if (isGPMUpdatingItselfOnWindowsOS) {
          path = ".$path";
        }
        final binaryPath = combinePath([appPath, path]);
        movePath(
          buildPath,
          binaryPath,
        );
      }

      if (isGPMUpdatingItselfOnWindowsOS) {
        await GPMInstanceManager.spawnBinaryReplacer();
      }

      // removing residuals
      if (!isLocalBuild) {
        print('Removing Residuals ...');
        Directory(root).deleteSync(recursive: true);
      }
      print('Adding app to registry ...');
      // creating a registry entry
      PackageRegistryService.registerSource(sourceEntity);

      // handling package type
      if (provider.type == 'cli') {
        print('Checking system environment ...');
        if (!SystemService.doesExecutableExists(platformBuildData.executable)) {
          // notify user about adding this cli to path
          SystemService.addToPath(id, appPath);
        }
        print("Successfully installed $repo.".green.bold);
      } else {
        print("Creating a desktop shortcut ...".blue.bold);
        final packagePath =
            combinePath([appPath, platformBuildData.executable]);
        if (Platform.isWindows) {
          final code = WindowsUtils.createDesktopShortcut(repo, packagePath);
          if (code != 0) {
            print("Sorry, we couldn't create a desktop shortcut for this app."
                .magenta
                .bold);
            print('Although, the download was successful.');
            if (yes('Would you like to open it in explorer? [y/N]: ')) {
              WindowsUtils.openInExlorer(File(packagePath).parent.path);
            }
          }
        } else {
          final code =
              await LinuxUtils.createDesktopShortcut(repo, packagePath);
          if (code != 0) {
            print("Sorry, we couldn't create a desktop shortcut for this app."
                .magenta
                .bold);
            print('Although, the download was successful.');
            LinuxUtils.openInFiles(File(packagePath).parent.path);
          }
        }
        print("Successfully installed $repo.".green.bold);
      }
    }
    return true;
  }
}
