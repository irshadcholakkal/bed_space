import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/services/google_auth_service.dart';
import '../../../data/repositories/sheet_repository.dart';
import '../../../data/services/saas_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final GoogleAuthService _authService;
  final SheetRepository _sheetRepository;
  final Duration restoreTimeout;

  AuthBloc({
    required GoogleAuthService authService,
    required SheetRepository sheetRepository,
    this.restoreTimeout = const Duration(seconds: 30),
  })  : _authService = authService,
        _sheetRepository = sheetRepository,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthSignInRequested>(_onAuthSignInRequested);
    on<AuthSignOutRequested>(_onAuthSignOutRequested);
  }

  Future<AuthAuthenticated?> _savedWorkspace() async {
    final owner = _authService.accountUserId;
    if (SaasService.configured && owner == null) return null;
    final email = owner == null
        ? await _sheetRepository.getUserEmail()
        : await _authService.getCurrentUserEmail();
    final sheetId = await _sheetRepository.getCachedSheetId();
    if (email == null ||
        sheetId == null ||
        !await _sheetRepository.isSheetIdForUser(email) ||
        owner != _authService.accountUserId) {
      return null;
    }
    return AuthAuthenticated(
        userEmail: email,
        accessToken:
            owner == null ? await _sheetRepository.getToken() ?? '' : '',
        sheetId: sheetId);
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      AuthAuthenticated? saved;
      try {
        saved = await _savedWorkspace().timeout(const Duration(seconds: 3));
      } catch (_) {
        // A cache read failure must still allow remote restoration.
      }
      if (saved != null) {
        // Sheets and Drive renew credentials on demand after the workspace opens.
        emit(saved);
        return;
      }
      final restored = await _restoreSession().timeout(restoreTimeout);
      emit(restored);
    } on TimeoutException {
      emit(const AuthError(
          'Workspace lookup timed out. Retry opening the workspace, or reconnect Google. Reference: WORKSPACE_TIMEOUT'));
    } on AuthException {
      emit(const AuthError(
          'Your account session needs renewal. Reconnect Google to continue. Reference: WORKSPACE_SESSION'));
    } on PostgrestException catch (error) {
      final sessionError =
          ['PGRST301', 'PGRST302', 'PGRST303'].contains(error.code);
      emit(AuthError(sessionError
          ? 'Your account session needs renewal. Reconnect Google to continue. Reference: WORKSPACE_SESSION'
          : 'The server could not load your linked workspace. Reference: WORKSPACE_STORAGE'));
    } catch (_) {
      emit(const AuthError(
          'Your saved workspace could not be read. Reconnect Google to reopen it. Reference: WORKSPACE_RESTORE'));
    }
  }

  Future<AuthState> _restoreSession() async {
    final owner = _authService.accountUserId;
    if (owner != null) {
      // A restored app account can recover its server-side workspace binding
      // even when this device has no cache or Google renewal is unavailable.
      final sheetId = await _sheetRepository.getSheetId();
      final email = await _authService.getCurrentUserEmail();
      if (owner != _authService.accountUserId) return AuthUnauthenticated();
      if (sheetId != null && email != null) {
        if (!await _sheetRepository.isSheetIdForUser(email)) {
          return const AuthError(
              'Connect the Google account already linked to this workspace.');
        }
        return AuthAuthenticated(
            userEmail: email, accessToken: '', sheetId: sheetId);
      }
      if (email != null && sheetId == null) {
        // Show business details before requesting Google storage credentials.
        // Workspace creation checks those credentials on form submission.
        return AuthAuthenticatedWithoutSheet(userEmail: email, accessToken: '');
      }
      return const AuthError(
          'Your account is signed in, but no linked workspace was found. Connect Google Sheets & Drive to reopen your spreadsheet. Reference: WORKSPACE_NOT_LINKED');
    }
    final accessToken = await _authService.signInSilently();
    if (accessToken == null) return AuthUnauthenticated();
    final email = await _authService.getCurrentUserEmail();
    if (email == null) {
      return const AuthError(
          'Could not read your Google account. Please reconnect Google.');
    }
    final sheetId = await _sheetRepository.getSheetId();
    await _sheetRepository.saveToken(accessToken);
    if (sheetId != null && await _sheetRepository.isSheetIdForUser(email)) {
      return AuthAuthenticated(
          userEmail: email, accessToken: accessToken, sheetId: sheetId);
    }
    if (SaasService.configured && sheetId != null) {
      return const AuthError(
          'Connect the Google account already linked to this workspace.');
    }
    return AuthAuthenticatedWithoutSheet(
        userEmail: email, accessToken: accessToken);
  }

  Future<void> _onAuthSignInRequested(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final accessToken = await _authService.signIn();
      if (accessToken != null) {
        final userEmail = await _authService.getCurrentUserEmail();
        if (userEmail != null) {
          // Cache token
          await _sheetRepository.saveToken(accessToken);

          // Check if sheet exists for this user
          final savedSheetId = await _sheetRepository.getSheetId();
          final isForCurrentUser =
              await _sheetRepository.isSheetIdForUser(userEmail);

          if (SaasService.configured &&
              savedSheetId != null &&
              !isForCurrentUser) {
            throw StateError(
                'Connect the Google account already linked to this workspace.');
          }

          if (savedSheetId != null && isForCurrentUser) {
            emit(AuthAuthenticated(
              userEmail: userEmail,
              accessToken: accessToken,
              sheetId: savedSheetId,
            ));
          } else {
            emit(AuthAuthenticatedWithoutSheet(
              userEmail: userEmail,
              accessToken: accessToken,
            ));
          }
        } else {
          emit(AuthError('Failed to get user email'));
        }
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onAuthSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _authService.signOut();
      await _sheetRepository.clearSheetId(); // Optionally clear local session?
      // For now just sign out from Google
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}
