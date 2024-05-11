import 'dart:convert';
import 'dart:io';

import 'package:chalkdart/chalkstrings.dart';

import '../../../extras/extras.dart';
import '../gpm_storage.dart';

const _jsonEncoder = JsonEncoder.withIndent('  ');

class JsonConfigurator {
  late String configName;
  late String configPath;
  dynamic config;

  JsonConfigurator({
    String? configName,
    String? configPath,
    this.config,
    bool atRoot = false,
  }) {
    this.configPath = configPath ??
        combinePath([
          GPMStorage.root,
          if (!atRoot) GPMStorage.registryStorage,
          configName!
        ]);
    if (configName != null) {
      this.configName = configName;
    }
    if (configName == null) {
      this.configName = this
          .configPath
          .substring(this.configPath.lastIndexOf(Platform.pathSeparator) + 1);
    }
    _load();
  }

  void _load() {
    config = jsonDecode("{}");
    try {
      File file = File(configPath);
      if (file.existsSync()) {
        config = jsonDecode(file.readAsStringSync());
      } else {
        // Creating raw session config
        if (!file.parent.existsSync()) {
          file.parent.createSync(recursive: true);
        }
        file.createSync();
        file.writeAsStringSync("{}", flush: true);
        onNewCreation();
      }
    } catch (error) {
      print(
          "Permission Denied when Creating Configuration: $configName, cannot continue!"
              .red);
      rethrow;
    }
  }

  void onNewCreation() {
    // called when the config file is auto created!
  }

  void reload() {
    _load();
  }

  void overwriteAndReload(String content) {
    File file = File(configPath);
    if (!file.existsSync()) {
      file.createSync();
    }
    file.writeAsStringSync(content, flush: true);
    _load();
  }

  void put(key, value) {
    config[key] = value;
    saveSync();
  }

  void add(key, value) {
    var list = config[key];
    if (list != null) {
      config[key] = {...list, value}.toList();
    } else {
      config[key] = [value];
    }
    saveSync();
  }

  void addAll(Map<String, dynamic> map) {
    final entries = map.entries;
    for (final element in entries) {
      put(element.key, element.value);
    }
  }

  void remove(key, value) {
    var list = config[key];
    if (list != null) {
      list.remove(value);
      config[key] = list;
    } else {
      config[key] = [];
    }
    saveSync();
  }

  dynamic get(key) {
    return config[key];
  }

  void saveSync() {
    try {
      File(configPath)
          .writeAsStringSync(_jsonEncoder.convert(config), flush: true);
    } catch (error) {
      print("Permission Denied when Saving Configuration: $configName");
    }
  }

  void deleteSync() {
    config = jsonDecode("{}");
    File(configPath).deleteSync();
  }
}
