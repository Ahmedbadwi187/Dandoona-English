import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

final Random _secure = Random.secure();

String _hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

String _format(List<int> b) {
  final h = _hex(b);
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20, 32)}';
}

/// A random (version 4) UUID. Progress records use these as client record ids, which the API needs as GUIDs
/// so a retried sync never stores the same record twice.
String newUuid() {
  final b = List<int>.generate(16, (_) => _secure.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  return _format(b);
}

final RegExp _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

/// The GUID to send to the server for a local record id. Real UUIDs pass through; ids written by older app
/// versions are mapped deterministically (name-based, version 5 style) so the same record always gets the same GUID.
String guidFor(String clientRecordId) {
  if (_uuid.hasMatch(clientRecordId)) return clientRecordId.toLowerCase();
  final digest = sha1.convert(utf8.encode('kids-english:$clientRecordId')).bytes.sublist(0, 16);
  digest[6] = (digest[6] & 0x0f) | 0x50;
  digest[8] = (digest[8] & 0x3f) | 0x80;
  return _format(digest);
}

bool isUuid(String s) => _uuid.hasMatch(s);
