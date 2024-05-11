import 'dart:io';

import 'package:chalkdart/chalkstrings.dart';
import 'package:cli_spin/cli_spin.dart';
import 'package:gpm/core/logging/exit_codes.dart';
import 'package:gpm/gpm_cli.dart';

import '../../constants/typedefs.dart';
import '../../entity/asset_entity.dart';
import '../../extras/extras.dart';
import '../provider/compatible_asset_provider.dart';
import '../storage/gpm_storage.dart';
import 'download_service.dart';
import 'package_integration_service.dart';

class InstallationService {
  InstallationService._();

  static Future<void> initReleaseInstall(
    String repo,
    CompatibleReleaseAssetProvider provider,
    List<String> extensions,
    bool explicitCall,
  ) async {
    // the target release to install
    ReleaseAssetEntity? target;

    // primary Assets are considered first
    if (provider.hasPrimary) {
      target = _selectTarget(provider.primary, 'primary');
    } else if (provider.hasSecondary) {
      target = _selectTarget(provider.secondary, 'secondary');
    } else {
      target = _selectTarget(provider.others, 'others');
    }
    if (target != null) {
      await _installRelease(target, explicitCall);
    } else {
      print("Aborting Install.");
    }
  }

  static ReleaseAssetEntity? _selectTarget(
      List<ReleaseAssetEntity> assets, String type) {
    int input = 1;
    if (assets.length > 1) {
      for (final asset in assets) {
        final index = assets.indexOf(asset) + 1;
        print("${"#$index".bold} - $asset (${formatBytes(asset.size)})");
      }
      stdout.write(
          "Please select the target you want to install (default=${option ?? 1}): "
              .bold);
      var line = option ?? stdin.readLineSync();
      if (line != null && line.isEmpty) {
        line = null;
      }
      input = int.tryParse(line ?? "1") ?? -1;
      if (input < 1 || input > assets.length) {
        print("Invalid Selection.".red);
        return null;
      }
    } else {
      final asset = assets.first;
      print("${"#1".bold} - $asset (${formatBytes(asset.size)})");
      if (!yes("Proceed to install (y/N): ")) {
        return null;
      }
    }
    return assets[input - 1]
      ..index = input - 1
      ..type = type;
  }

  static Future<void> _installRelease(
      ReleaseAssetEntity target, bool explicitCall) async {
    await downloadRelease(target, explicitCall);
  }

  static Future<void> downloadRelease(ReleaseAssetEntity target, explicitCall,
      {VoidCallback? onComplete}) async {
    String generateText(int progress) {
      return "${"$progress %".blue.bold} Downloading $target from GitHub ... ";
    }

    final startTime = DateTime.now();
    final spinner = CliSpin(
      text: generateText(0),
      spinner: CliSpinners.pipe,
    ).start();

    // Release file path
    final path = GPMStorage.toPath(target);
    final total = target.size;

    // Checking if its already downloaded
    final file = File(path);
    if (file.existsSync()) {
      if (file.statSync().size == total) {
        spinner.stopAndPersist(
          text: '➜ ${'[OK]'.green.bold} Using cached download',
        );
        await PackageIntegrationService.integrate(target, path, explicitCall);
      }
    } else {
      await DownloadService.download(
        url: target.downloadURL,
        path: path,
        onProgress: (progress) {
          spinner.text = generateText(progress);
        },
        onComplete: (path) async {
          final endTime = DateTime.now();
          spinner.stopAndPersist(
            text:
                '➜ ${'[OK]'.green.bold} Download Completed, ${'[took ${formatTime(endTime.difference(startTime))}]'}.',
          );
          await PackageIntegrationService.integrate(target, path, explicitCall);
        },
        onError: () {
          spinner.fail('Downloaded Failed.'.red);
          
    if(explicitCall) terminateInstance(exitCode: ExitCodes.error);
        },
      );
    }

    onComplete?.call();
  }
}
