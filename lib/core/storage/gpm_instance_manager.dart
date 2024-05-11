/// [GPMInstanceManager]
/// This code is only needed to be executed on windows operating system
/// unlike linux or unix, windows doesn't allow rewriting or deleting
/// the process's source file which ultimately prevents gpm
/// from updating itself on windows.

import 'dart:io';

import 'package:gpm/core/logging/logger.dart';
import 'package:gpm/core/storage/gpm_storage.dart';
import 'package:gpm/core/storage/omegaui/json_configurator.dart';
import 'package:gpm/extras/extras.dart';

class GPMInstanceManager {
  static final instancesConfig =
      JsonConfigurator(configName: "activity.json", atRoot: true);

  static final replacersConfig =
      JsonConfigurator(configName: "replacer-activity.json", atRoot: true);

  static void registerAliveInstance(id) {
    if (Platform.isWindows) {
      debugPrint('Registering instance $id');
      instancesConfig.add('instances', id);
    }
  }

  static void removeTerminatedInstance(id) {
    if (Platform.isWindows) {
      debugPrint('Removed Terminated instance $id');
      instancesConfig.remove('instances', id);
      if (instancesConfig.get('instances').isEmpty) {
        instancesConfig.deleteSync();
      }
    }
  }

  static void registerAliveReplacer(id) {
    if (Platform.isWindows) {
      replacersConfig.add('replacers', id);
    }
  }

  static void removeTerminatedReplacer(id) {
    if (Platform.isWindows) {
      replacersConfig.remove('replacers', id);
      if (replacersConfig.get('replacers').isEmpty) {
        replacersConfig.deleteSync();
      }
    }
  }

  static bool isAnyReplacerAlive() {
    if (Platform.isWindows) {
      if (replacersConfig.config != null) {
        return false;
      }
      final replacers = replacersConfig.get('replacers');
      return replacers != null && replacers.isNotEmpty;
    }
    return false;
  }

  static Future<void> spawnBinaryReplacer() async {
    if (Platform.isWindows) {
      if (!GPMInstanceManager.isAnyReplacerAlive()) {
        print("Initializing GPM Update Helper ...");
        await Process.start(
          combinePath([
            GPMStorage.appsDir.path,
            'omegaui',
            'gpm',
            'gpm-binary-replacer.exe'
          ]),
          [],
          mode: ProcessStartMode.detached,
        );
        await Future.delayed(Duration(seconds: 2));
      }
    }
  }

  static void helpTheHelper() {
    if (Platform.isWindows) {
      try {
        // doing just the same
        // the helper does to update gpm
        final targetFile = File(combinePath([
          GPMStorage.appsDir.path,
          'omegaui',
          'gpm',
          '.gpm-binary-replacer.exe'
        ]));
        if (targetFile.existsSync()) {
          targetFile.renameSync(combinePath([
            GPMStorage.appsDir.path,
            'omegaui',
            'gpm',
            'gpm-binary-replacer.exe'
          ]));
        }
      } catch (e) {
        // we may encounter issue saying the helper is already running
        // so, we just ignore it this time
      }
    }
  }
}
