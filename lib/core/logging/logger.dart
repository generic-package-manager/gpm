import 'package:gpm/gpm_cli.dart';

void debugPrint(
  dynamic message, {
  String? tag,
}) {
  // logs that help in debugging
  // can only be enabled in verbose mode
  if (verbose) {
    tag ??= 'GPM';
    print("[$tag] $message");
  }
}
