import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/services/google_auth_service.dart';
import '../../../data/repositories/sheet_repository.dart';
import '../../../data/services/google_sheets_service.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final GoogleAuthService _authService;
  final SheetRepository _sheetRepository;

  AuthBloc({
    required GoogleAuthService authService,
    required SheetRepository sheetRepository,
  })  : _authService = authService,
        _sheetRepository = sheetRepository,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthSignInRequested>(_onAuthSignInRequested);
    on<AuthSignOutRequested>(_onAuthSignOutRequested);
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      // Try silent sign-in to restore session
      final accessToken = await _authService.signInSilently();
      
      if (accessToken != null) {
        final user = await _authService.getCurrentUser();
        if (user != null) {
          final sheetId = await _sheetRepository.getSheetId();
          // Cache the latest token for offline access/background sync
          await _sheetRepository.saveToken(accessToken);
          
          if (sheetId != null) {
            emit(AuthAuthenticated(
              userEmail: user.email,
              accessToken: accessToken,
              sheetId: sheetId,
            ));
          } else {
            emit(AuthAuthenticatedWithoutSheet(
              userEmail: user.email,
              accessToken: accessToken,
            ));
          }
        } else {
          // Attempt offline fallback if getCurrentUser is null (no network)
          await _handleOfflineAuthFallback(emit, accessToken);
        }
      } else {
        // Attempt offline fallback if silent sign-in fails (likely offline)
        await _handleOfflineAuthFallback(emit, null);
      }
    } catch (e) {
      await _handleOfflineAuthFallback(emit, null);
    }
  }

  Future<void> _handleOfflineAuthFallback(Emitter<AuthState> emit, String? accessToken) async {
    final cachedEmail = await _sheetRepository.getUserEmail();
    final cachedSheetId = await _sheetRepository.getSheetId();
    final cachedToken = accessToken ?? await _sheetRepository.getToken();

    if (cachedEmail != null && cachedSheetId != null) {
      emit(AuthAuthenticated(
        userEmail: cachedEmail,
        accessToken: cachedToken ?? '', // Provide token if available
        sheetId: cachedSheetId,
      ));
    } else if (cachedEmail != null) {
       emit(AuthAuthenticatedWithoutSheet(
        userEmail: cachedEmail,
        accessToken: cachedToken ?? '',
      ));
    } else {
      emit(AuthUnauthenticated());
    }
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

