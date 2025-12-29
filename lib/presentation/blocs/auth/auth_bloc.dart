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
      final isSignedIn = await _authService.isSignedIn();
      if (isSignedIn) {
        final user = await _authService.getCurrentUser();
        final accessToken = await _authService.getAccessToken();
        if (user != null && accessToken != null) {
          final sheetId = await _sheetRepository.getSheetId();
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
          emit(AuthUnauthenticated());
        }
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(e.toString()));
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
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}

