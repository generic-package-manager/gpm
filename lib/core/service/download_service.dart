import 'dart:io';

import 'package:gpm/core/service/api_service.dart';
import 'package:http/http.dart' as http;

class DownloadService {
  DownloadService._();

  static Future<void> download({
    required String url,
    required String path,
    required void Function(int progress) onProgress,
    required Future<void> Function(String path) onComplete,
    required void Function() onError,
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    request.headers.addAll(getGitHubAPIHeaders() ?? {});
    final response = await http.Client().send(request);
    if (response.statusCode == 200) {
      final total = response.contentLength ?? 0;
      int received = 0;
      final List<int> bytes = [];
      final subscription = response.stream.listen((value) {
        bytes.addAll(value);
        received += value.length;
        if (total != 0) {
          onProgress(((received * 100) / total).round());
        }
      });
      await subscription.asFuture();
      final file = File(path);
      file.writeAsBytesSync(bytes);
      await onComplete(file.absolute.path);
    } else {
      onError();
    }
  }
}
