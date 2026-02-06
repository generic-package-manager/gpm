import 'dart:io';

import 'package:gpm/core/service/system_service.dart';

class ReleaseAssetEntity {
  final String owner;
  final String repo;
  final String tag;
  final String name;
  final String label;
  final String license;
  final int size;
  final String downloadURL;
  final num downloads;
  final String contentType;
  final DateTime updatedAt;
  late int index;
  late String type;
  late bool explicitVersion;
  late List<String> versions;

  String get appID => '$owner/$repo';

  ReleaseAssetEntity({
    required this.owner,
    required this.repo,
    required this.tag,
    required this.name,
    required this.label,
    required this.license,
    required this.size,
    required this.downloadURL,
    required this.downloads,
    required this.contentType,
    required this.updatedAt,
  });

  ReleaseAssetEntity.fromMap(
      this.owner, this.repo, this.tag, Map<String, dynamic> map)
      : name = map['name'],
        size = map['size'],
        label = map['label'] ?? "",
        license = map['license'] ?? "Unknown",
        index = map['index'] ?? 0,
        explicitVersion = map['explicit_version'] ?? false,
        versions = List<String>.from(map['versions'] ?? []),
        type = map['type'] ?? 'others',
        downloadURL = map['browser_download_url'],
        contentType = map['content_type'] ?? "",
        updatedAt = DateTime.parse(map['updated_at'] ?? DateTime.now()),
        downloads = map['download_count'];

  Map<String, dynamic> toMap() {
    return {
      'owner': owner,
      'repo': repo,
      'index': index,
      'type': type,
      'tag': tag,
      'explicit_version': explicitVersion,
      'versions': versions,
      'name': name,
      'size': size,
      'label': label,
      'license': license,
      'browser_download_url': downloadURL,
      'content_type': contentType,
      'updated_at': updatedAt.toString(),
      'download_count': downloads,
    };
  }

  bool isCompatibleWithOS() {
    final keywords = SystemService.getOSKeywords();
    for (final key in keywords) {
      if (name.toLowerCase().contains(key)) {
        return true;
      }
    }
    return false;
  }

  bool isSetup() {
    if (Platform.isWindows) {
      String lowerCaseName = name.toLowerCase();

      bool containsSetupKeyword = lowerCaseName.contains('setup');
      bool containsInstallerKeyword = lowerCaseName.contains('installer');

      bool hasMSIExtension = lowerCaseName.endsWith('.msi');
      bool hasEXEExtension = lowerCaseName.endsWith('.exe');

      bool isSetupFile = hasMSIExtension ||
          (hasEXEExtension &&
              (containsSetupKeyword || containsInstallerKeyword));
      return isSetupFile;
    }
    if (Platform.isLinux) {
      return type == 'primary';
    }
    return false;
  }

  @override
  String toString() {
    return name;
  }
}
