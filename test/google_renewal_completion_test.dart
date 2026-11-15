import 'dart:async';
import 'package:bed_space/data/services/google_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('successful account renewal completes and permits the next renewal',
      () async {
    final auth = GoogleAuthService();
    expect(
        await auth
            .restoreForAccount('success', () async => 'first')
            .timeout(const Duration(seconds: 1)),
        'first');
    expect(
        await auth
            .restoreForAccount('success', () async => 'second')
            .timeout(const Duration(seconds: 1)),
        'second');
  });

  test('missing Google credentials complete without hanging setup', () async {
    expect(
        await GoogleAuthService()
            .restoreForAccount('missing', () async => null)
            .timeout(const Duration(seconds: 1)),
        isNull);
  });

  test('concurrent account requests share one renewal and both complete',
      () async {
    final auth = GoogleAuthService();
    final pending = Completer<String?>();
    var calls = 0;
    Future<String?> restore() {
      calls++;
      return pending.future;
    }

    final first = auth.restoreForAccount('shared', restore);
    final second = auth.restoreForAccount('shared', restore);
    expect(calls, 1);
    pending.complete('shared-token');
    expect(
        await Future.wait([first, second]).timeout(const Duration(seconds: 1)),
        ['shared-token', 'shared-token']);
  });

  test('failed renewal preserves the error and allows a retry', () async {
    final auth = GoogleAuthService();
    await expectLater(
        auth.restoreForAccount('failure', () async {
          throw StateError('renewal failed');
        }).timeout(const Duration(seconds: 1)),
        throwsStateError);
    expect(
        await auth
            .restoreForAccount('failure', () async => 'retry')
            .timeout(const Duration(seconds: 1)),
        'retry');
  });
}
