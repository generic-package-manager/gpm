import 'dart:io';
import 'dart:isolate';

import 'package:args/args.dart';
import 'package:chalkdart/chalkstrings.dart';
import 'package:gpm/core/logging/exit_codes.dart';
import 'package:gpm/core/provider/compatible_asset_provider.dart';
import 'package:gpm/core/service/package_registry_service.dart';
import 'package:gpm/core/service/package_service.dart';
import 'package:gpm/core/service/system_service.dart';
import 'package:gpm/core/service/upgrade_service.dart';
import 'package:gpm/core/storage/gpm_instance_manager.dart';
import 'package:gpm/core/storage/gpm_storage.dart';
import 'package:gpm/extras/extras.dart';

final instanceID = generateGPMIsolateID();
int instanceExitCode = ExitCodes.fine;
ReceivePort currentIsolateReceivePort = ReceivePort(instanceID);

void terminateInstance({exitCode}) {
  instanceExitCode = exitCode ?? instanceExitCode;
  currentIsolateReceivePort.sendPort.send('exit');
}

final String _message = """

._____  ._______ ._____.___ 
:_ ___\\ : ____  |:         |
|   |___|    :  ||   \\  /  |
|   /  ||   |___||   |\\/   |
|. __  ||___|    |___| |   |
 :/ |. |               |___|
 :   :/                     
     :

${"Generic Package Manager".bold}
""";

/// cli version
const String version = '0.0.1+224';

// testing compatibility with gui

/// verbose flag
bool verbose = false;

// additional cli options
String? targetTag = 'latest';
String? mode = 'release';
String? listMode;
String? listType = 'all';
String? commitHash;
String? token; // used to access private repositories
String? option;

ArgParser buildParser() {
  return ArgParser()
    ..addSeparator('Options & Flags:')
    ..addFlag(
      'yes',
      negatable: false,
      help:
          'When passed, gpm will not ask for confirmation before any operation.',
      callback: (value) => yesToAll = value,
    )
    ..addOption(
      'option',
      help:
          'Should be an integer, used to automatically select the release target without asking the user.',
      valueHelp: "1, 2, 3 ...",
      callback: (value) => option = value,
    )
    ..addSeparator("")
    ..addOption(
      'list-mode',
      allowed: ['release', 'source'],
      help: 'List apps installed via specific mode.',
      callback: (value) => listMode = value,
    )
    ..addOption(
      'list-type',
      allowed: ['primary', 'secondary', 'others', 'all'],
      defaultsTo: 'all',
      help:
          'List apps installed via specific types.\nHere\'s the priority list for your operating system: ${ExtensionPriorities.getExtensionsWithPriorityOrder(SystemService.osObject).join(', ')}.',
      callback: (value) => listType = value,
    )
    ..addFlag(
      'list',
      negatable: false,
      help: 'List all apps with installed versions.',
      callback: PackageRegistryService.listInstalledApps,
    )
    ..addSeparator("")
    ..addOption(
      'tag',
      defaultsTo: 'latest',
      help:
          'Specify the release tag you want to install along with --install option.',
      callback: (value) => targetTag = value,
    )
    ..addOption(
      'commit',
      abbr: 'c',
      help:
          'Specify the commit hash you want to build from source along with --build option.',
      callback: (value) => commitHash = value,
    )
    ..addOption(
      'token',
      help:
          'Specify your access token for fetching private repos, defaults to GITHUB_TOKEN Environment Variable.',
      callback: (value) {
        token = value;
        if (token == null || token!.isEmpty) {
          token = Platform.environment['GITHUB_TOKEN'];
        }
      },
    )
    ..addSeparator("")
    ..addOption(
      'lock',
      help: 'Pauses update for an app.',
      callback: (value) => PackageRegistryService.lockUpdates(id: value),
    )
    ..addOption(
      'unlock',
      help: 'Resumes update for an app.',
      callback: (value) => PackageRegistryService.unlockUpdates(id: value),
    )
    ..addSeparator("")
    ..addOption(
      'install',
      abbr: 'i',
      help: 'Install an app from a user\'s repo, updates if already installed.',
      callback: (value) =>
          PackageService.handleInstall(value, explicitCall: true),
    )
    ..addOption(
      'build',
      abbr: 'b',
      help: 'Build an app from source.',
      callback: (value) {
        if (value != null && value.isNotEmpty) {
          mode = 'source';
          PackageService.handleInstall(value, explicitCall: true);
        }
      },
    )
    ..addOption(
      'build-locally',
      help: 'Build from source using the local `gpm.yaml` specification.',
      callback: (value) => PackageService.buildLocally(value),
    )
    ..addOption(
      'remove',
      abbr: 'r',
      help: 'Remove an installed app.',
      callback: PackageService.handleRemove,
    )
    ..addOption(
      'update',
      abbr: 'u',
      help: 'Updates an already installed app.',
      callback: (value) =>
          PackageService.handleUpdate(value, explicitCall: true),
    )
    ..addSeparator("")
    ..addOption(
      'roll-back',
      help: 'Rollback an app to its previously installed release version.',
      callback: (value) =>
          PackageService.handleRollback(value, explicitCall: true),
    )
    ..addOption(
      'roll-forward',
      help: 'Invert of `--rollback`.',
      callback: (value) =>
          PackageService.handleRollforward(value, explicitCall: true),
    )
    ..addSeparator("")
    ..addFlag(
      'clean',
      negatable: false,
      help: 'Removes any left over or temporary downloaded files.',
      callback: GPMStorage.cleanDownloads,
    )
    ..addFlag(
      'upgrade',
      negatable: false,
      help: 'Updates all apps to their latest versions.',
      callback: PackageService.handleUpgrade,
    )
    ..addFlag(
      'check-for-updates',
      negatable: false,
      help:
          'Checks for updates and generates a update-data.json file at ~/.gpm.',
      callback: (value) {
        if (value) {
          UpgradeService.checkUpdates(explicitCall: true);
        }
      },
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Show additional command output.',
    )
    ..addFlag(
      'version',
      negatable: false,
      help: 'Print the tool version.',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    );
}

void printUsage(ArgParser argParser) {
  print('Usage: gpm <options> [arguments]\n');
  print(argParser.usage);
}

void checkSyntax(List<String> arguments) {
  if (arguments.isNotEmpty && !arguments[0].startsWith('-')) {
    print("Incorrect usage. Use --help for more information.");
    print("May be you mean: gpm --${arguments[0]}");
  }
}

void run(List<String> arguments) {
  // Lock.find();
  checkSyntax(arguments);
  SystemService.init();
  GPMStorage.init();
  final ArgParser argParser = buildParser();
  try {
    final ArgResults results = argParser.parse(arguments);

    if (arguments.isEmpty || results.wasParsed('help')) {
      printUsage(argParser);
      terminateInstance();
    }
    GPMInstanceManager.helpTheHelper();
    if (results.wasParsed('version')) {
      stdout.write(_message);
      print('gpm cli version: $version');
      terminateInstance();
    }
    if (results.wasParsed('verbose')) {
      verbose = true;
      if (results.arguments.length == 1) {
        terminateInstance();
      }
    }
  } on FormatException catch (e) {
    // Print usage information if an invalid argument was provided.
    print(e.message);
    print('');
    printUsage(argParser);
    terminateInstance(exitCode: ExitCodes.error);
  }
}
