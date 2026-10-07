import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a finished certificate picture to the system share sheet (save to files or Drive, send by message...).
/// Nothing is uploaded by the app: the picture is made on the device and the parent chooses where it goes.
/// Behind an interface so tests use a fake. The share sheet needs no permission.
abstract class CertificateSharer {
  /// True when the share sheet was opened.
  Future<bool> share(Uint8List png, String fileName, {String? text});
}

class SystemCertificateSharer implements CertificateSharer {
  @override
  Future<bool> share(Uint8List png, String fileName, {String? text}) async {
    File? file;
    try {
      final dir = await getTemporaryDirectory();
      file = File('${dir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(png, flush: true);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'image/png')], text: text));
      return true;
    } on Object {
      return false;
    } finally {
      try {
        await file?.delete(); // a temp file; the certificate is always re-made on demand
      } on Object {
        // best effort
      }
    }
  }
}

final certificateSharerProvider = Provider<CertificateSharer>((ref) => SystemCertificateSharer());
