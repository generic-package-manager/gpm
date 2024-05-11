/// [version_utils.dart] has version resolving utility functions,
/// at the time of building from source, it performs checks to identify
/// whether the installed version of any dependency is satisfied or not.

import 'dart:io';

enum VersionRequirementMode {
  /// uses ^ symbol
  /// e.g: ^1.2.3
  /// the installed version should be greater than or equal to 1.2.3.
  moreOrEqual,

  /// uses ~ symbol
  /// e.g: ~1.2.3
  /// the installed version's major version should be 1.x.x.
  about,

  /// uses > symbol
  /// e.g: >1.2.3
  /// the installed version should be greater than 1.2.3.
  greater,

  /// uses < symbol
  /// e.g: <1.2.3
  /// the installed version should be less than 1.2.3.
  lower,

  /// uses no symbol
  /// e.g: 1.2.3
  /// the installed version should be 1.2.3.
  exact,
}

/// Parses the version data out of the outputs of various commands
/// example: [runs] dart --version
///          [output] Dart SDK version: 3.2.6 (stable) (Wed Jan 24 13:41:58 2024 +0000) on "windows_x64"
///          [result] 3.2.6
String? getVersionString(String executable) {
  RegExp versionRegex = RegExp(r'\b(\d+(\.\d+)+)\b');

  final result = Process.runSync(
    executable,
    ['--version'],
    runInShell: true,
    environment: Platform.environment,
  );
  final output = result.stdout;
  Match? match = versionRegex.firstMatch(output);
  if (match != null) {
    return match.group(0)!;
  } else {
    return null;
  }
}

/// Checks if the required version by the dependency is installed or not.
bool isVersionResolved({
  required String requiredVersion,
  required String installedVersion,
}) {
  // identifying requirement mode
  final mode = getRequirementMode(requiredVersion);
  if (mode != VersionRequirementMode.exact) {
    // removing leading symbol
    requiredVersion = requiredVersion.substring(1);
  } else {
    // there is no brainstorming for exact matching
    return requiredVersion == installedVersion;
  }
  // segmenting versions into major, minor & patch
  final requiredSegmentMap = _segmentVersion(requiredVersion);
  final installedSegmentMap = _segmentVersion(installedVersion);
  // parsing in advance for similar cases
  int installedVersionNumber = int.parse(installedSegmentMap.values.join());
  int requiredVersionNumber = int.parse(requiredSegmentMap.values.join());
  // checking if version could be resolved
  bool resolved = true;
  switch (mode) {
    case VersionRequirementMode.moreOrEqual:
      bool isEqual = requiredVersion == installedVersion;
      if (!isEqual) {
        if (installedVersionNumber < requiredVersionNumber) {
          resolved = false;
        }
      }
      break;
    case VersionRequirementMode.about:
      // the major versions should be same
      resolved = requiredSegmentMap['major'] == installedSegmentMap['major'];
      break;
    case VersionRequirementMode.greater:
      if (installedVersionNumber < requiredVersionNumber) {
        resolved = false;
      }
      break;
    case VersionRequirementMode.lower:
      if (installedVersionNumber > requiredVersionNumber) {
        resolved = false;
      }
      break;
    case VersionRequirementMode.exact:
  }
  return resolved;
}

/// Parses the [VersionRequirementMode] out of the dependency's [version] key
VersionRequirementMode getRequirementMode(String version) {
  VersionRequirementMode mode = VersionRequirementMode.exact;
  List<String> symbols = ['^', '~', '>', '<'];
  final symbolChar = version[0];
  final index = symbols.indexOf(symbolChar);
  if (index >= 0) {
    mode = VersionRequirementMode.values[index];
  }
  return mode;
}

/// Breaks down the version into major, minor & patch
/// e.g: for 1.2.3
/// major: 1
/// minor: 2
/// patch: 3
Map<String, String> _segmentVersion(String version) {
  final segmented = version.split('.');
  String? major = segmented.elementAtOrNull(0) ?? "0";
  String? minor = segmented.elementAtOrNull(1) ?? "0";
  String? patch = segmented.elementAtOrNull(2) ?? "0";
  return {
    'major': major,
    'minor': minor,
    'patch': patch,
  };
}
