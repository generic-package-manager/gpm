import 'dart:io';
import 'dart:isolate';

import 'package:gpm/core/storage/gpm_instance_manager.dart';
import 'package:gpm/core/storage/gpm_storage.dart';
import 'package:gpm/extras/extras.dart';

void main() async {
  // next we get a unique id
  final id = generateGPMIsolateID();

  // next, we register the instance
  GPMInstanceManager.registerAliveReplacer(id);

  // creating our own isolate
  final isolate = await Isolate.spawn((_) => run(), id);

  // next, we create a receive port for the current isolate
  ReceivePort port = ReceivePort(id);
  port.listen((message) {
    if (message == id) {
      // and when the current instance finishes,
      // we remove it from the list
      GPMInstanceManager.removeTerminatedReplacer(id);
    }
    port.close();
  });
  isolate.addOnExitListener(port.sendPort, response: id);
}

void run() async {
  // before even starting the replacer isolate
  // we'll check if there is a need for it
  // which is basically checking that .gpm.exe exists or not

  final extension = Platform.isWindows ? ".exe" : "";

  final targetFile = File(combinePath(
      [GPMStorage.appsDir.path, 'omegaui', 'gpm', '.gpm$extension']));
  if (!targetFile.existsSync()) {
    print("Target doesn't exists: $targetFile");
    exit(0);
  }

  final gpmActivityFile = File(combinePath([GPMStorage.root, 'activity.json']));

  // not every file system may allow watching a file
  // so, we use a periodic check approach

  while (gpmActivityFile.existsSync()) {
    await Future.delayed(Duration(seconds: 1));
  }

  // now, that every instance of gpm has terminated
  // we'll silently replace its binary with the updated version

  targetFile.renameSync(combinePath(
      [GPMStorage.appsDir.path, 'omegaui', 'gpm', 'gpm$extension']));

  print('Replacing Finished Successfully.');
}
