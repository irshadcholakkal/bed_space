import 'dart:convert';
import 'package:bed_space/data/services/google_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const permissions =
    'https://www.googleapis.com/auth/spreadsheets https://www.googleapis.com/auth/drive.file';

GoogleAuthService service(Map<String, dynamic> claims) => GoogleAuthService(
    httpClient:
        MockClient((_) async => http.Response(jsonEncode(claims), 200)));

void main() {
  test('Google email comparison ignores case and surrounding whitespace',
      () async {
    final auth = service({
      'email': 'Owner@example.com',
      'scope': permissions,
      'expires_in': '3600',
    });
    expect(await auth.validateGoogleToken('case-token', ' owner@example.com '),
        isTrue);
    expect(auth.connectionError, isNull);
  });

  test('missing Drive permission explains the consent failure', () async {
    final auth = service({
      'email': 'owner@example.com',
      'scope': 'https://www.googleapis.com/auth/spreadsheets',
      'expires_in': '3600',
    });
    expect(await auth.validateGoogleToken('scopes-token', 'owner@example.com'),
        isFalse);
    expect(auth.connectionError, contains('GOOGLE_SCOPES'));
  });

  test('another Google account is rejected with a specific error', () async {
    final auth = service({
      'email': 'another@example.com',
      'scope': permissions,
      'expires_in': '3600',
    });
    expect(await auth.validateGoogleToken('other-token', 'owner@example.com'),
        isFalse);
    expect(auth.connectionError, contains('GOOGLE_ACCOUNT'));
  });

  test('verification network failure is visible without exposing tokens',
      () async {
    final auth = GoogleAuthService(httpClient: MockClient((_) async {
      throw Exception('sensitive-token');
    }));
    expect(await auth.validateGoogleToken('network-token', 'owner@example.com'),
        isFalse);
    expect(auth.connectionError, contains('GOOGLE_VERIFY'));
    expect(auth.connectionError, isNot(contains('sensitive-token')));
  });
}
