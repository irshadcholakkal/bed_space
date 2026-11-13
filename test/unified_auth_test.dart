import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:bed_space/data/services/google_auth_service.dart';
import 'package:bed_space/data/repositories/sheet_repository.dart';
import 'package:bed_space/presentation/blocs/auth/auth_bloc.dart';

class _GoogleSession extends GoogleAuthService {
  int interactiveCalls = 0;
  @override
  Future<String?> signInSilently() async => 'google-token';
  @override
  Future<String?> getCurrentUserEmail() async => 'owner@example.com';
  @override
  Future<String?> signIn() async {
    interactiveCalls++;
    return null;
  }
}

class _Workspace extends SheetRepository {
  _Workspace(this.sheetId, {this.matches = true});
  final String? sheetId;
  final bool matches;
  String? token;
  @override
  Future<String?> getSheetId() async => sheetId;
  @override
  Future<bool> isSheetIdForUser(String email) async => matches;
  @override
  Future<void> saveToken(String value) async {
    token = value;
  }
}

class _InterruptedGoogleSession extends _GoogleSession {
  bool renewed = false;
  String? owner = 'customer';
  @override
  String? get accountUserId => owner;
  @override
  Future<String?> signInSilently() async => renewed ? 'renewed-token' : null;
}

class _SavedWorkspace extends _Workspace {
  _SavedWorkspace({super.matches = true}) : super('saved-sheet');
  @override
  Future<String?> getCachedSheetId() async => 'saved-sheet';
}

class _PendingGoogleSession extends _InterruptedGoogleSession {
  int restoreCalls = 0;
  @override
  Future<String?> signInSilently() {
    restoreCalls++;
    return Completer<String?>().future;
  }
}

class _NoSavedWorkspace extends _Workspace {
  _NoSavedWorkspace() : super(null);
  @override
  Future<String?> getCachedSheetId() async => null;
}

class _RemoteWorkspace extends _Workspace {
  _RemoteWorkspace() : super('server-sheet');
  @override
  Future<String?> getCachedSheetId() async => null;
}

class _PendingWorkspace extends _NoSavedWorkspace {
  @override
  Future<String?> getSheetId() => Completer<String?>().future;
}

void main() {
  test(
      'account workspace restores from server without a cache or Google renewal',
      () async {
    final google = _PendingGoogleSession();
    final bloc =
        AuthBloc(authService: google, sheetRepository: _RemoteWorkspace());
    final restored =
        bloc.stream.firstWhere((state) => state is AuthAuthenticated);
    bloc.add(const AuthCheckRequested());
    expect(
        (await restored.timeout(const Duration(seconds: 1))
                as AuthAuthenticated)
            .sheetId,
        'server-sheet');
    expect(google.restoreCalls, 0);
    await bloc.close();
  });
  test('saved workspace opens without waiting for Google renewal', () async {
    final google = _PendingGoogleSession();
    final bloc =
        AuthBloc(authService: google, sheetRepository: _SavedWorkspace());
    final restored =
        bloc.stream.firstWhere((state) => state is AuthAuthenticated);
    bloc.add(const AuthCheckRequested());
    expect(
        (await restored.timeout(const Duration(seconds: 1))
                as AuthAuthenticated)
            .sheetId,
        'saved-sheet');
    expect(google.restoreCalls, 0);
    await bloc.close();
  });

  test('hung remote restoration ends with a retryable error', () async {
    final bloc = AuthBloc(
        authService: _PendingGoogleSession(),
        sheetRepository: _PendingWorkspace(),
        restoreTimeout: const Duration(milliseconds: 20));
    final failed = bloc.stream.firstWhere((state) => state is AuthError);
    bloc.add(const AuthCheckRequested());
    expect(
        (await failed.timeout(const Duration(seconds: 1)) as AuthError).message,
        contains('WORKSPACE_TIMEOUT'));
    await bloc.close();
  });
  test(
      'missing server binding asks to reconnect without waiting for Google renewal',
      () async {
    final google = _PendingGoogleSession();
    final bloc =
        AuthBloc(authService: google, sheetRepository: _NoSavedWorkspace());
    final failed = bloc.stream.firstWhere((state) => state is AuthError);
    bloc.add(const AuthCheckRequested());
    expect(
        (await failed.timeout(const Duration(seconds: 1)) as AuthError).message,
        contains('WORKSPACE_NOT_LINKED'));
    expect(google.restoreCalls, 0);
    await bloc.close();
  });
  test(
      'temporary Google renewal failure preserves the signed-in customer workspace',
      () async {
    final google = _InterruptedGoogleSession();
    final bloc =
        AuthBloc(authService: google, sheetRepository: _SavedWorkspace());
    final restored =
        bloc.stream.firstWhere((state) => state is AuthAuthenticated);
    bloc.add(const AuthCheckRequested());
    final saved = await restored as AuthAuthenticated;
    expect(saved.sheetId, 'saved-sheet');
    expect(saved.accessToken, isEmpty);
    expect(google.interactiveCalls, 0);
    google.renewed = true;
    bloc.add(const AuthCheckRequested());
    await Future<void>.delayed(Duration.zero);
    expect((bloc.state as AuthAuthenticated).sheetId, 'saved-sheet');
    await bloc.close();
  });

  test(
      'session fallback never restores a workspace linked to a different Google account',
      () async {
    final bloc = AuthBloc(
        authService: _InterruptedGoogleSession(),
        sheetRepository: _SavedWorkspace(matches: false));
    final rejected = bloc.stream.firstWhere((state) => state is AuthError);
    bloc.add(const AuthCheckRequested());
    expect((await rejected as AuthError).message, contains('already linked'));
    await bloc.close();
  });
  test(
      'Restored Google session starts new workspace setup without another login',
      () async {
    final google = _GoogleSession();
    final workspace = _Workspace(null);
    final bloc = AuthBloc(authService: google, sheetRepository: workspace);
    final ready =
        bloc.stream.firstWhere((s) => s is AuthAuthenticatedWithoutSheet);
    bloc.add(const AuthCheckRequested());
    final state = await ready as AuthAuthenticatedWithoutSheet;
    expect(state.userEmail, 'owner@example.com');
    expect(state.accessToken, 'google-token');
    expect(workspace.token, 'google-token');
    expect(google.interactiveCalls, 0);
    await bloc.close();
  });

  test('Restored session opens the saved workspace', () async {
    final bloc = AuthBloc(
        authService: _GoogleSession(),
        sheetRepository: _Workspace('saved-sheet'));
    final ready = bloc.stream.firstWhere((s) => s is AuthAuthenticated);
    bloc.add(const AuthCheckRequested());
    expect((await ready as AuthAuthenticated).sheetId, 'saved-sheet');
    await bloc.close();
  });

  test('A different Google email never opens the saved sheet', () async {
    final bloc = AuthBloc(
        authService: _GoogleSession(),
        sheetRepository: _Workspace('saved-sheet', matches: false));
    final ready =
        bloc.stream.firstWhere((s) => s is AuthAuthenticatedWithoutSheet);
    bloc.add(const AuthCheckRequested());
    expect(await ready, isA<AuthAuthenticatedWithoutSheet>());
    await bloc.close();
  });
}
