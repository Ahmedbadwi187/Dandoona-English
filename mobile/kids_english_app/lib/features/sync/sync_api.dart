import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

enum SyncErrorKind { network, auth, validation, notFound, server }

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

/// A child as the server stores it.
class ServerChild {
  const ServerChild({required this.id, required this.name, required this.avatarKey, required this.birthYear, required this.track, this.birthMonth, this.goalMinutes, this.skills, this.updatedAt});
  final String id;
  final String name;
  final String avatarKey;
  final int birthYear;
  final String track;
  final int? birthMonth;
  final int? goalMinutes;
  final Set<String>? skills;

  /// When the profile was last changed on a device (null when an older app wrote it).
  final DateTime? updatedAt;
}

/// A progress record as the server stores it (the `clientRecordId` is the GUID the app made for it).
class ServerProgress {
  const ServerProgress({
    required this.clientRecordId,
    required this.lessonId,
    required this.activity,
    required this.stars,
    required this.attempts,
    required this.timeSpentSeconds,
    required this.completedAt,
  });
  final String clientRecordId;
  final String lessonId;
  final String activity;
  final int stars;
  final int attempts;
  final int timeSpentSeconds;
  final DateTime completedAt;
}

/// A certificate, opened chest, passed review, read story or placement, as the server keeps it (union of every phone).
class ServerAchievement {
  const ServerAchievement({required this.kind, required this.key, required this.earnedAt});
  final String kind; // certificate | chest | review | story | placed
  final String key; // a unit id, review id or "castle"
  final DateTime earnedAt;

  Map<String, Object?> toJson() => {'kind': kind, 'key': key, 'earnedAt': earnedAt.toUtc().toIso8601String()};
}

/// The slice of the Kids English API the app uses. Behind an interface so sync logic is tested without a server.
abstract class SyncApi {
  Future<AuthTokens> register({required String email, required String password, required String displayName, bool guardianConfirmed = false, bool termsAccepted = false});
  Future<AuthTokens> login({required String email, required String password});
  Future<AuthTokens> refresh(String refreshToken);

  /// Asks the server to e-mail a 6-digit code (it answers the same for any address, so nobody can find out who has an account).
  Future<void> forgotPassword(String email);

  /// Sets a new password with the code from the e-mail.
  Future<void> resetPassword({required String email, required String code, required String newPassword});
  Future<String> createChild(String accessToken,
      {required String name, required String avatarKey, required int birthYear, required String track, int? birthMonth, int? goalMinutes, Set<String>? skills, DateTime? updatedAt});

  /// Sends the profile fields of an existing child. The server keeps the most recent change; what it holds afterwards comes back.
  Future<ServerChild> updateChild(String accessToken, String serverChildId,
      {required String name, required String avatarKey, required int birthYear, required String track, int? birthMonth, int? goalMinutes, Set<String>? skills, DateTime? updatedAt});
  Future<SubmitResult> submitProgress(String accessToken, String serverChildId, List<Map<String, Object?>> items);

  /// Every child of the signed-in parent (used right after sign-in to bring the family's data to this device).
  Future<List<ServerChild>> listChildren(String accessToken);

  /// Every progress record of one child.
  Future<List<ServerProgress>> listProgress(String accessToken, String serverChildId);

  /// Sends a child's achievements; the server keeps the union with the earliest date (sending again changes nothing).
  Future<void> submitAchievements(String accessToken, String serverChildId, List<ServerAchievement> items);

  /// A child's achievements from every phone.
  Future<List<ServerAchievement>> listAchievements(String accessToken, String serverChildId);

  /// Permanently deletes the account and all its data on the server (needs the password again).
  Future<void> deleteAccount(String accessToken, String password);

  /// Hard-deletes one child (profile and all progress) on the server. A child that is already gone is `notFound`.
  Future<void> deleteChild(String accessToken, String serverChildId);
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
      case 404:
        throw SyncException(SyncErrorKind.notFound, detail);
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
  Future<AuthTokens> register({required String email, required String password, required String displayName, bool guardianConfirmed = false, bool termsAccepted = false}) async =>
      _tokens(await _post('api/auth/register', {
        'email': email,
        'password': password,
        'displayName': displayName,
        'guardianConfirmed': guardianConfirmed,
        'termsAccepted': termsAccepted,
      }));

  @override
  Future<AuthTokens> login({required String email, required String password}) async =>
      _tokens(await _post('api/auth/login', {'email': email, 'password': password}));

  @override
  Future<AuthTokens> refresh(String refreshToken) async =>
      _tokens(await _post('api/auth/refresh', {'refreshToken': refreshToken}));

  @override
  Future<void> forgotPassword(String email) async {
    await _send('POST', 'api/auth/forgot-password', {'email': email}, null);
  }

  @override
  Future<void> resetPassword({required String email, required String code, required String newPassword}) async {
    await _send('POST', 'api/auth/reset-password', {'email': email, 'token': code, 'newPassword': newPassword}, null);
  }

  Map<String, Object?> _childBody({required String name, required String avatarKey, required int birthYear, required String track, int? birthMonth, int? goalMinutes, Set<String>? skills, DateTime? updatedAt}) => {
        'name': name,
        'avatarKey': avatarKey,
        'birthYear': birthYear,
        'track': track,
        'birthMonth': ?birthMonth,
        'goalMinutes': ?goalMinutes,
        if (skills != null) 'skills': (skills.toList()..sort()),
        if (updatedAt != null) 'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  static ServerChild _child(Map<String, dynamic> e) => ServerChild(
        id: e['id'] as String,
        name: e['name'] as String,
        avatarKey: e['avatarKey'] as String,
        birthYear: e['birthYear'] as int,
        track: (e['track'] as String?) ?? 'little-learners',
        birthMonth: e['birthMonth'] as int?,
        goalMinutes: e['goalMinutes'] as int?,
        skills: (e['skills'] as List<dynamic>?)?.cast<String>().toSet(),
        updatedAt: e['updatedAt'] == null ? null : DateTime.parse(e['updatedAt'] as String),
      );

  @override
  Future<String> createChild(String accessToken,
      {required String name, required String avatarKey, required int birthYear, required String track, int? birthMonth, int? goalMinutes, Set<String>? skills, DateTime? updatedAt}) async {
    final json = await _post('api/children', _childBody(name: name, avatarKey: avatarKey, birthYear: birthYear, track: track, birthMonth: birthMonth, goalMinutes: goalMinutes, skills: skills, updatedAt: updatedAt), token: accessToken);
    return json['id'] as String;
  }

  @override
  Future<ServerChild> updateChild(String accessToken, String serverChildId,
      {required String name, required String avatarKey, required int birthYear, required String track, int? birthMonth, int? goalMinutes, Set<String>? skills, DateTime? updatedAt}) async {
    final json = await _send('PUT', 'api/children/$serverChildId', _childBody(name: name, avatarKey: avatarKey, birthYear: birthYear, track: track, birthMonth: birthMonth, goalMinutes: goalMinutes, skills: skills, updatedAt: updatedAt), accessToken);
    return _child(json as Map<String, dynamic>);
  }

  @override
  Future<SubmitResult> submitProgress(String accessToken, String serverChildId, List<Map<String, Object?>> items) async {
    final json = await _post('api/children/$serverChildId/progress', {'items': items}, token: accessToken);
    return SubmitResult(accepted: json['accepted'] as int, duplicates: json['duplicates'] as int);
  }

  @override
  Future<List<ServerChild>> listChildren(String accessToken) async {
    final json = await _send('GET', 'api/children', null, accessToken) as List<dynamic>;
    return [for (final e in json.cast<Map<String, dynamic>>()) _child(e)];
  }

  @override
  Future<List<ServerProgress>> listProgress(String accessToken, String serverChildId) async {
    final json = await _send('GET', 'api/children/$serverChildId/progress', null, accessToken) as List<dynamic>;
    return [
      for (final e in json.cast<Map<String, dynamic>>())
        ServerProgress(
          clientRecordId: e['clientRecordId'] as String,
          lessonId: e['lessonId'] as String,
          activity: e['activity'] as String,
          stars: e['stars'] as int,
          attempts: e['attempts'] as int,
          timeSpentSeconds: e['timeSpentSeconds'] as int,
          completedAt: DateTime.parse(e['completedAt'] as String),
        ),
    ];
  }

  @override
  Future<void> submitAchievements(String accessToken, String serverChildId, List<ServerAchievement> items) async {
    await _post('api/children/$serverChildId/achievements', {'items': [for (final i in items) i.toJson()]}, token: accessToken);
  }

  @override
  Future<List<ServerAchievement>> listAchievements(String accessToken, String serverChildId) async {
    final json = await _send('GET', 'api/children/$serverChildId/achievements', null, accessToken) as List<dynamic>;
    return [
      for (final e in json.cast<Map<String, dynamic>>())
        ServerAchievement(kind: e['kind'] as String, key: e['key'] as String, earnedAt: DateTime.parse(e['earnedAt'] as String)),
    ];
  }

  @override
  Future<void> deleteAccount(String accessToken, String password) async {
    await _send('POST', 'api/account/delete', {'password': password}, accessToken);
  }

  @override
  Future<void> deleteChild(String accessToken, String serverChildId) async {
    await _send('DELETE', 'api/children/$serverChildId', null, accessToken);
  }
}
