// #PENDING

import 'dart:io';

import 'package:chalkdart/chalkstrings.dart';
import 'package:gpm/core/storage/gpm_storage.dart';
import 'package:gpm/extras/extras.dart';

class Lock {
  static final File _lockFile = File(combinePath([GPMStorage.root, '.alive']));

  static void find() {
    if (exists()) {
      print('Another instance of gpm is already running.'.red.bold);
      exit(401);
    } else {
      lock();
    }
  }

  static bool exists() {
    return _lockFile.existsSync();
  }

  static void lock() {
    if (!_lockFile.existsSync()) {
      _lockFile.createSync();
    }
  }

  static void unlock() {
    if (_lockFile.existsSync()) {
      _lockFile.deleteSync();
    }
  }
}
