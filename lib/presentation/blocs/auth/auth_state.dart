part of 'auth_bloc.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthUnauthenticated extends AuthState {}

class AuthAuthenticatedWithoutSheet extends AuthState {
  final String userEmail;
  final String accessToken;

  const AuthAuthenticatedWithoutSheet({
    required this.userEmail,
    required this.accessToken,
  });

  @override
  List<Object> get props => [userEmail, accessToken];
}

class AuthAuthenticated extends AuthState {
  final String userEmail;
  final String accessToken;
  final String sheetId;

  const AuthAuthenticated({
    required this.userEmail,
    required this.accessToken,
    required this.sheetId,
  });

  @override
  List<Object> get props => [userEmail, accessToken, sheetId];
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object> get props => [message];
}

