import 'dart:convert';

import 'package:gpm/gpm_cli.dart';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';

import '../../entity/asset_entity.dart';
import '../../extras/extras.dart';
import '../logging/logger.dart';
import 'package_registry_service.dart';

class APIService {
  APIService._();

  static Future<Map<String, String>> searchOnGitHub(String repo) async {
    final url =
        'https://api.github.com/search/repositories?q=$repo&per_page=10&sort=stars';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: getGitHubAPIHeaders(),
      );
      if (response.statusCode == 200) {
        final body = response.body;
        final map = jsonDecode(body);
        final items = map['items'];
        if (items != null) {
          final resultMap = <String, String>{};
          for (final item in items) {
            resultMap.putIfAbsent(
                item['full_name'], () => item['stargazers_count'].toString());
          }
          return resultMap;
        }
      }
    } catch (e) {
      debugPrint(e);
      print("Unable to connect with $url");
      debugPrint(
        "Either the app id format is incorrect or it is some network error",
        tag: 'SERVICE',
      );
    }
    return <String, String>{};
  }

  static Future<String?> getLatestCommit(String id) async {
    final url = 'https://api.github.com/repos/$id/commits';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: getGitHubAPIHeaders(),
      );
      final body = response.body;
      final map = jsonDecode(body);
      final firstCommit = map[0];
      if (firstCommit != null) {
        final sha = firstCommit['sha'];
        if (sha != null) {
          return sha.toString().substring(0, 7);
        }
      }
    } catch (e) {
      debugPrint(e);
      print("Unable to connect with $url");
      debugPrint(
        "Either the app id format is incorrect or it is some network error",
        tag: 'SERVICE',
      );
    }
    return null;
  }

  static Future<dynamic> getGPMSpecification(String id) async {
    final url = 'https://api.github.com/repos/$id/contents/gpm.yaml';
    try {
      if (commitHash != null) {
        final url = 'https://github.com/$id/raw/$commitHash/gpm.yaml';
        final response = await http.get(
          Uri.parse(url),
          headers: getGitHubAPIHeaders(),
        );
        if (response.statusCode == 200) {
          final body = response.body;
          return loadYaml(body);
        } else {
          print(
              '[WARNING] ${parseRepoName(id)} does not support gpm in its $commitHash commit');
          print('[WARNING] We\'ll instead use the latest build instructions.');
        }
      }
      final response = await http.get(
        Uri.parse(url),
        headers: getGitHubAPIHeaders(),
      );
      final body = response.body;
      final map = jsonDecode(body);
      if (map['size'] != null && map['size'] > 0) {
        final contentWithLineFeedChar = map['content'].toString();
        String content = '';
        final chars = contentWithLineFeedChar.codeUnits;
        for (final ch in chars) {
          if (ch != 10) {
            content += String.fromCharCode(ch);
          }
        }
        final baseDecoded = base64Decode(content);
        final contentString = String.fromCharCodes(baseDecoded);
        return loadYaml(contentString);
      }
    } catch (e) {
      debugPrint(e);
      print("Unable to connect with $url");
      debugPrint(
        "Either the app id format is incorrect or it is some network error",
        tag: 'SERVICE',
      );
    }
    return null;
  }

  static Future<String?> getLatestTag(String id) async {
    final url = 'https://api.github.com/repos/$id/releases/latest';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: getGitHubAPIHeaders(),
      );
      final body = response.body;
      final map = jsonDecode(body);
      final tag = map['tag_name'];
      return tag;
    } catch (e) {
      debugPrint(e);
      print("Unable to connect with $url");
      debugPrint(
        "Either the app id format is incorrect or it is some network error",
        tag: 'SERVICE',
      );
    }
    return null;
  }

  static Future<List<ReleaseAssetEntity>> fetchAssets(String id) async {
    List<ReleaseAssetEntity> assets = [];
    var prefix = targetTag == 'latest' ? '' : 'tags/';
    var url = 'https://api.github.com/repos/$id/releases/$prefix$targetTag';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: getGitHubAPIHeaders(),
      );
      final body = response.body;
      final map = jsonDecode(body);
      final assetsList = map['assets'] ?? [];
      final versions = [];
      if (PackageRegistryService.isPackageInstalledViaReleaseMode(id)) {
        final installedRelease = PackageRegistryService.getReleaseObject(id);
        versions.addAll(installedRelease.versions);
      }
      final license = await getRepoLicense(id);
      for (final assetData in assetsList) {
        assets.add(ReleaseAssetEntity.fromMap(
          parseOwnerName(id),
          parseRepoName(id),
          map['tag_name'] ?? 'none',
          assetData
            ..['explicit_version'] = targetTag != 'latest'
            ..['license'] = license
            ..['versions'] = versions,
        ));
      }
    } catch (e) {
      print(e);
      print("Unable to connect with $url");
      if (verbose) {
        print(
            "Either the app id format is incorrect or it is some network error");
      }
    }
    return assets;
  }

  static Future<bool> doesRepoExists(String id) async {
    final url = 'https://api.github.com/repos/$id';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: getGitHubAPIHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Unable to connect with $url");
      debugPrint(
          "Either the app id format is incorrect or it is some network error",
          tag: 'SERVICE');
      return false;
    }
  }

  static Future<String> getRepoLicense(String id) async {
    final url = 'https://api.github.com/repos/$id';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: getGitHubAPIHeaders(),
      );
      final license = jsonDecode(response.body)['license'] ?? jsonDecode('{}');
      return license['name'] ?? "Unknown";
    } catch (e) {   
      return "Unknown";
    }
  }
}

Map<String, String>? getGitHubAPIHeaders() {
  if (token != null && token!.isNotEmpty) {
    return {
      'Authorization': 'Bearer $token',
    };
  }
  return null;
}
