import 'dart:io';

import 'package:gpm/core/logging/logger.dart';
import 'package:gpm/core/storage/gpm_instance_manager.dart';
import 'package:gpm/gpm_cli.dart';

void main(List<String> arguments) async {
  GPMInstanceManager.registerAliveInstance(instanceID);

  currentIsolateReceivePort.listen((message) {
    debugPrint("Received message: $message");
    if (message == "exit") {
      debugPrint("Exiting GPM Instance");
      GPMInstanceManager.removeTerminatedInstance(instanceID);
      exit(instanceExitCode);
    }
  });
  run(arguments);
}
