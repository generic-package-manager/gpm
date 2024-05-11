import 'dart:io';

import 'package:gpm/extras/version_utils.dart';
import 'package:yaml/yaml.dart';

import '../service/system_service.dart';

class BuildDataProvider {
  final String type;
  final List<PlatformBuildData> data;

  BuildDataProvider({required this.type, required this.data});

  factory BuildDataProvider.fromMap(dynamic spec) {
    return BuildDataProvider(
      type: spec['type'],
      data: List<PlatformBuildData>.from(
        () {
          final supportedPlatforms = spec['build'] as YamlList;
          List<PlatformBuildData> platformData = [];
          for (final element in supportedPlatforms) {
            final platformMap = element.value as YamlMap;
            final platform = platformMap.keys.first;
            final map = Map<dynamic, dynamic>.fromEntries(
                platformMap.value[platform].entries);
            map['platform'] = platform;
            platformData.add(PlatformBuildData.fromMap(map));
          }
          return platformData;
        }(),
      ),
    );
  }

  bool isHostSupported() {
    if (Platform.isLinux) {
      final hostMime = <String>{'linux', SystemService.os};
      final supported = data.any((e) => hostMime.contains(e.platform));
      return supported;
    }
    return data.any((element) => element.platform == SystemService.os);
  }

  PlatformBuildData getTargetPlatformBuildInstructions() {
    if (Platform.isLinux) {
      final hostMime = <String>{'linux', SystemService.os};
      final supported = data.firstWhere((e) => hostMime.contains(e.platform));
      return supported;
    }
    final target =
        data.firstWhere((element) => element.platform == SystemService.os);
    return target;
  }
}

class PlatformBuildData {
  final String executable;
  final String note;
  final String platform;
  final List<String> appData;
  final List<DependencyData> dependencies;
  final List<Step> steps;

  bool get hasDependencies => dependencies.isNotEmpty;

  factory PlatformBuildData.fromMap(dynamic spec) {
    final List<String> appData = [];
    final List<DependencyData> dependencies = [];
    final List<Step> steps = [];

    // adding all to be add data files
    appData.addAll(List<String>.from(spec['appData'] ?? []));

    // parsing dependency data
    final dependenciesMap = spec['dependencies'] ?? {};
    for (final dependency in dependenciesMap) {
      dependencies.add(DependencyData.fromMap(dependency));
    }

    // parsing steps
    final stepsMap = spec['steps'];
    for (final step in stepsMap) {
      steps.add(Step.fromMap(step));
    }

    return PlatformBuildData(
      executable: spec['executable'] ?? '',
      note: spec['note'] ?? '',
      platform: spec['platform'],
      appData: appData,
      dependencies: dependencies,
      steps: steps,
    );
  }

  PlatformBuildData({
    required this.note,
    required this.executable,
    required this.platform,
    required this.appData,
    required this.dependencies,
    required this.steps,
  });
}

class DependencyData {
  final String executable;
  final String version;
  final String installCommand;
  final String help;

  DependencyData({
    required this.executable,
    required this.version,
    required this.installCommand,
    required this.help,
  });

  bool get hasVersion => version.isNotEmpty;
  bool get hasInstallCommand => installCommand.isNotEmpty;
  bool get hasHelp => help.isNotEmpty;

  factory DependencyData.fromMap(map) {
    return DependencyData(
      executable: map['executable'],
      version: map['version'] ?? '',
      installCommand: map['installCommand'] ?? '',
      help: map['help'] ?? '',
    );
  }

  bool isVersionSatisfied() {
    if (!hasVersion) {
      return true;
    }
    final version = getVersionString(executable);
    if (version == null) {
      return false;
    }
    return isVersionResolved(
      requiredVersion: this.version,
      installedVersion: version,
    );
  }
}

class Step {
  final String name;
  final String run;
  final bool ignoreError;

  Step(this.name, this.run, this.ignoreError);

  factory Step.fromMap(dynamic map) {
    return Step(
      map['name'],
      map['run'],
      map['ignoreError'] ?? false,
    );
  }

  Future<int> executeAsync(String workingDir) async {
    final exitCode = await SystemService.execute(
      run,
      workingDir,
      false,
    );
    return exitCode;
  }
}
