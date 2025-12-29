import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/sheet/sheet_bloc.dart';
import '../theme/app_theme.dart';

/// Login Screen
/// Handles Google Sign-In and initial sheet setup
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Icon/Logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.bed_outlined,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                
                // App Title
                const Text(
                  'Bed Space Management',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                const Text(
                  'Manage your shared accommodation\nwith ease',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                
                // Sign In Button
                BlocConsumer<AuthBloc, AuthState>(
                  listener: (context, authState) {
                    if (authState is AuthAuthenticatedWithoutSheet) {
                      // Create sheet
                      context.read<SheetBloc>().add(
                            SheetCreateRequested(
                              accessToken: authState.accessToken,
                              userEmail: authState.userEmail,
                            ),
                          );
                    } else if (authState is AuthError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(authState.message),
                          backgroundColor: AppTheme.errorColor,
                        ),
                      );
                    }
                  },
                  builder: (context, authState) {
                    return BlocListener<SheetBloc, SheetState>(
                      listener: (context, sheetState) {
                        if (sheetState is SheetCreated) {
                          // Re-check auth to get authenticated state with sheet
                          context.read<AuthBloc>().add(const AuthCheckRequested());
                        } else if (sheetState is SheetError) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(sheetState.message),
                              backgroundColor: AppTheme.errorColor,
                            ),
                          );
                        }
                      },
                      child: ElevatedButton.icon(
                        onPressed: authState is AuthLoading
                            ? null
                            : () {
                                context.read<AuthBloc>().add(const AuthSignInRequested());
                              },
                        icon: authState is AuthLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Text(
                          authState is AuthLoading ? 'Signing in...' : 'Sign in with Google',
                          style: const TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                
                // Disclaimer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '⚠️ Internal use only\nClient-only app with Google Sheets',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

