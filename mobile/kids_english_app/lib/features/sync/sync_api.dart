import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

enum SyncErrorKind { network, auth, validation, server }

class SyncException implements Exception {
  const SyncException(this.kind, this.message);
  final SyncErrorKind kind;
  final String message;
  @override
  String toString() => 'SyncException(${kind.name}): $message';
}

class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});
  final String accessToken;
  final String refreshToken;
}

class SubmitResult {
  const SubmitResult({required this.accepted, required this.duplicates});
  final int accepted;
  final int duplicates;
}

/// The slice of the Kids English API the app uses. Behind an interface so sync logic is tested without a server.
abstract class SyncApi {
  Future<AuthTokens> register({required String email, required String password, required String displayName});
  Future<AuthTokens> login({required String email, required String password});
  Future<AuthTokens> refresh(String refreshToken);
  Future<String> createChild(String accessToken,
      {required String name, required String avatarKey, required int birthYear, required String track});
  Future<SubmitResult> submitProgress(String accessToken, String serverChildId, List<Map<String, Object?>> items);

  /// Permanently deletes the account and all its data on the server (needs the password again).
  Future<void> deleteAccount(String accessToken, String password);
}

/// HTTP implementation. Release builds must point at an https:// server (Android blocks cleartext by default;
/// only the debug manifest allows http for the emulator).
class HttpSyncApi implements SyncApi {
  HttpSyncApi(String baseUrl, {http.Client? client, this.timeout = const Duration(seconds: 20)})
      : _base = _normalize(baseUrl),
        _client = client ?? http.Client();

  final Uri _base;
  final http.Client _client;
  final Duration timeout;

  static Uri _normalize(String url) {
    final trimmed = url.trim();
    final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https')) || uri.host.isEmpty) {
      throw const SyncException(SyncErrorKind.validation, 'Invalid server address');
    }
    return uri.replace(path: uri.path.endsWith('/') ? uri.path : '${uri.path}/');
  }

  Future<Map<String, dynamic>> _post(String path, Object body, {String? token}) async =>
      (await _send('POST', path, body, token)) as Map<String, dynamic>;

  Future<Object?> _send(String method, String path, Object? body, String? token) async {
    final request = http.Request(method, _base.resolve(path))
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);

    http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request).timeout(timeout));
    } on TimeoutException {
      throw const SyncException(SyncErrorKind.network, 'Request timed out');
    } on Object catch (e) {
      throw SyncException(SyncErrorKind.network, 'Could not reach the server: $e');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body.isEmpty ? null : jsonDecode(response.body);
    }
    final detail = _problemText(response.body);
    switch (response.statusCode) {
      case 400:
      case 422:
        throw SyncException(SyncErrorKind.validation, detail);
      case 401:
      case 403:
        throw SyncException(SyncErrorKind.auth, detail);
      default:
        throw SyncException(SyncErrorKind.server, 'Server error ${response.statusCode}: $detail');
    }
  }

  /// Reads an RFC 7807 ProblemDetails body (the API's error format) without ever echoing request data.
  static String _problemText(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final errors = json['errors'];
      if (errors is Map && errors.isNotEmpty) return errors.values.expand((v) => v is List ? v : [v]).join('; ');
      return (json['detail'] ?? json['title'] ?? 'Request failed').toString();
    } on Object {
      return 'Request failed';
    }
  }

  AuthTokens _tokens(Map<String, dynamic> json) =>
      AuthTokens(accessToken: json['accessToken'] as String, refreshToken: json['refreshToken'] as String);

  @override
  Future<AuthTokens> register({required String email, required String password, required String displayName}) async =>
      _tokens(await _post('api/auth/register', {'email': email, 'password': password, 'displayName': displayName}));

  @override
  Future<AuthTokens> login({required String email, required String password}) async =>
      _tokens(await _post('api/auth/login', {'email': email, 'password': password}));

  @override
  Future<AuthTokens> refresh(String refreshToken) async =>
      _tokens(await _post('api/auth/refresh', {'refreshToken': refreshToken}));

  @override
  Future<String> createChild(String accessToken,
      {required String name, required String avatarKey, required int birthYear, required String track}) async {
    final json = await _post('api/children', {'name': name, 'avatarKey': avatarKey, 'birthYear': birthYear, 'track': track}, token: accessToken);
    return json['id'] as String;
  }

  @override
  Future<SubmitResult> submitProgress(String accessToken, String serverChildId, List<Map<String, Object?>> items) async {
    final json = await _post('api/children/$serverChildId/progress', {'items': items}, token: accessToken);
    return SubmitResult(accepted: json['accepted'] as int, duplicates: json['duplicates'] as int);
  }

  @override
  Future<void> deleteAccount(String accessToken, String password) async {
    await _send('POST', 'api/account/delete', {'password': password}, accessToken);
  }
}
