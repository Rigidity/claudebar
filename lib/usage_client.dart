import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'usage.dart';

class UsageException implements Exception {
  const UsageException(this.message);

  final String message;

  static const noCredentials = UsageException('No Claude Code login found. Run `claude` and log in.');
  static const unauthorized = UsageException('Token expired. Run `claude` once to refresh it.');
  factory UsageException.http(int code) => UsageException('Usage request failed (HTTP $code).');

  @override
  String toString() => message;
}

class UsageClient {
  static final _url = Uri.parse('https://api.anthropic.com/api/oauth/usage');

  static Future<UsageSnapshot> fetch() async {
    final token = await _readAccessToken();

    final response = await http.get(_url, headers: {
      'Authorization': 'Bearer $token',
      'anthropic-beta': 'oauth-2025-04-20',
      'User-Agent': 'claude-code/2.0',
    }).timeout(const Duration(seconds: 20));

    final status = response.statusCode;
    if (status == 401 || status == 403) throw UsageException.unauthorized;
    if (status < 200 || status >= 300) throw UsageException.http(status);
    return UsageSnapshot.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Reads the OAuth token Claude Code stores. Re-read on every fetch so we pick up
  /// tokens Claude Code has refreshed. Shelling out to `security` avoids a keychain
  /// prompt every time this ad-hoc signed app is rebuilt.
  static Future<String> _readAccessToken() async {
    final fromKeychain = await _keychainItem('Claude Code-credentials');
    final keychainToken = fromKeychain == null ? null : _parseToken(fromKeychain);
    if (keychainToken != null) return keychainToken;

    final home = Platform.environment['HOME'];
    if (home != null) {
      try {
        final token = _parseToken(await File('$home/.claude/.credentials.json').readAsString());
        if (token != null) return token;
      } on FileSystemException {
        // fall through to noCredentials
      }
    }
    throw UsageException.noCredentials;
  }

  static Future<String?> _keychainItem(String service) async {
    try {
      final result = await Process.run('/usr/bin/security', ['find-generic-password', '-s', service, '-w']);
      return result.exitCode == 0 ? result.stdout as String : null;
    } on ProcessException {
      return null;
    }
  }

  static String? _parseToken(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return (json['claudeAiOauth'] as Map?)?['accessToken'] as String?;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}
