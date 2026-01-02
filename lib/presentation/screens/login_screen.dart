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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // Logo Area (Minimalist)
              Icon(
                Icons.bed_outlined, // Or a better home/business icon
                size: 48,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 32),
              
              // Big Staggered Heading
              Text(
                'Welcome to\nBed Space.',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  height: 1.1,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                'Manage your shared accommodation seamlessly.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.subtitleColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
              
              const Spacer(),
              
              // Sign In Button
              BlocConsumer<AuthBloc, AuthState>(
                listener: (context, authState) {
                  if (authState is AuthAuthenticatedWithoutSheet) {
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
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: (authState is AuthLoading || authState is AuthAuthenticatedWithoutSheet)
                            ? null
                            : () {
                                context.read<AuthBloc>().add(const AuthSignInRequested());
                              },
                        icon: (authState is AuthLoading || authState is AuthAuthenticatedWithoutSheet)
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Text(
                          (authState is AuthLoading || authState is AuthAuthenticatedWithoutSheet) 
                              ? 'Initializing workspace...' 
                              : 'Continue with Google',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              
              // Footer / Disclaimer
              Center(
                child: Text(
                  'Internal prototype • Client-side only',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

