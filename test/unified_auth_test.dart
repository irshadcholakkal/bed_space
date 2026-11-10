import 'package:flutter_test/flutter_test.dart';
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

void main() {
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
