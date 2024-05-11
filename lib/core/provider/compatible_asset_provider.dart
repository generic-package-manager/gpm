import '../../constants/enums.dart';
import '../../entity/asset_entity.dart';
import '../../extras/extras.dart';

class CompatibleReleaseAssetProvider {
  final List<ReleaseAssetEntity> _primary;
  final List<ReleaseAssetEntity> _secondary;
  final List<ReleaseAssetEntity> _others;

  bool get hasPrimary => _primary.isNotEmpty;

  bool get hasSecondary => _secondary.isNotEmpty;

  bool get hasOthers => _others.isNotEmpty;

  List<ReleaseAssetEntity> get primary => _primary;

  List<ReleaseAssetEntity> get secondary => _secondary;

  List<ReleaseAssetEntity> get others => _others;

  CompatibleReleaseAssetProvider({
    required List<ReleaseAssetEntity> primary,
    required List<ReleaseAssetEntity> secondary,
    required List<ReleaseAssetEntity> others,
  })  : _others = others,
        _secondary = secondary,
        _primary = primary;

  factory CompatibleReleaseAssetProvider.fromList({
    required List<ReleaseAssetEntity> assets,
    required OS target,
  }) {
    // Getting OS Compatible Extensions
    final acceptableExtensions =
        ExtensionPriorities.getExtensionsWithPriorityOrder(target);

    // Finding OS Compatible Assets
    Map<String, List<ReleaseAssetEntity>> compatibleAssets = {};

    for (final ext in acceptableExtensions) {
      compatibleAssets[ext] = <ReleaseAssetEntity>[];
    }

    for (final ext in acceptableExtensions) {
      compatibleAssets[ext]!.addAll(_findTargetAssets(assets, ext, target));
    }

    List<ReleaseAssetEntity> primary = [];
    List<ReleaseAssetEntity> secondary = [];
    List<ReleaseAssetEntity> others = [];

    if (compatibleAssets.isNotEmpty) {
      final primaryExtension = acceptableExtensions[0];
      primary = compatibleAssets[primaryExtension]!;
      if (acceptableExtensions.length > 1) {
        // this means this is a supported os
        final secondaryExtension = acceptableExtensions[1];
        secondary = compatibleAssets[secondaryExtension]!;
        if (acceptableExtensions.length > 2) {
          // this means this is a well-known supported os
          final entries = compatibleAssets.entries;
          for (final compatibleAsset in entries) {
            final ext = compatibleAsset.key;
            if (ext != primaryExtension && ext != secondaryExtension) {
              others.addAll(compatibleAsset.value);
            }
          }
        }
      }
    }

    return CompatibleReleaseAssetProvider(
      primary: primary,
      secondary: secondary,
      others: others,
    );
  }

  static List<ReleaseAssetEntity> _findTargetAssets(
    List<ReleaseAssetEntity> assets,
    String targetExtension,
    OS target,
  ) {
    List<ReleaseAssetEntity> results = [];
    final isUniversalTargetExtension = ExtensionPriorities
        .universalArtifactsExtensions
        .contains(targetExtension);
    for (final asset in assets) {
      final ext = getExtension(asset.name);
      if (ext == targetExtension) {
        if (isUniversalTargetExtension) {
          // this means this is a universal artifact
          // we need to check if it's compatible with the target os
          if (asset.isCompatibleWithOS()) {
            results.add(asset);
          }
        } else {
          results.add(asset);
        }
      }
    }
    return results;
  }
}

class ExtensionPriorities {
  ExtensionPriorities._();

  static final universalArtifactsExtensions = [
    'zip',
    'xz',
    'gz',
  ];

  static final otherLinuxArtifactsExtensions = [
    'AppImage',
    ...universalArtifactsExtensions,
  ];

  static final windows = OSCompatibleExtensions(OS.windows, [
    'msi',
    'exe',
    ...universalArtifactsExtensions,
  ]);
  static final macos = OSCompatibleExtensions(OS.macos, [
    'dmg',
    ...universalArtifactsExtensions,
  ]);
  static final debian = OSCompatibleExtensions(OS.debian, [
    'deb',
    ...otherLinuxArtifactsExtensions,
  ]);
  static final fedora = OSCompatibleExtensions(OS.fedora, [
    'rpm',
    ...otherLinuxArtifactsExtensions,
  ]);
  static final arch = OSCompatibleExtensions(OS.arch, [
    'zst',
    ...otherLinuxArtifactsExtensions,
  ]);
  static final linux = OSCompatibleExtensions(OS.linux, [
    ...otherLinuxArtifactsExtensions,
  ]);
  static final unrecognized = OSCompatibleExtensions(OS.unrecognized, [
    ...universalArtifactsExtensions,
  ]);

  static final List<OSCompatibleExtensions> priorities = [
    windows,
    macos,
    linux,
    debian,
    fedora,
    arch,
    unrecognized,
  ];

  static List<String> getExtensionsWithPriorityOrder(OS target) {
    return priorities
        .firstWhere((priority) => priority.os == target)
        .extensions;
  }
}

class OSCompatibleExtensions {
  final OS os;
  final List<String> extensions;

  OSCompatibleExtensions(this.os, this.extensions);
}
