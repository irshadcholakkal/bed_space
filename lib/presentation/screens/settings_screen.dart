import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/sheet/sheet_bloc.dart';
import '../theme/app_theme.dart';

/// Settings Screen
/// Shows logged-in account, sync, reset, and logout options
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          if (authState is AuthAuthenticated || authState is AuthAuthenticatedWithoutSheet) {
            final userEmail = authState is AuthAuthenticated
                ? authState.userEmail
                : (authState as AuthAuthenticatedWithoutSheet).userEmail;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Account Info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Account',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.account_circle, size: 48, color: AppTheme.primaryColor),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Logged in as',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textColor,
                                    ),
                                  ),
                                  Text(
                                    userEmail,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Sheet Info
                if (authState is AuthAuthenticated)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sheet Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Sheet ID: ${authState.sheetId}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sheet Name: BedSpace_$userEmail',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Actions
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.sync, color: AppTheme.primaryColor),
                        title: const Text('Re-sync Sheet'),
                        subtitle: const Text('Refresh sheet data'),
                        onTap: () {
                          context.read<SheetBloc>().add(const SheetSyncRequested());
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sheet synced'),
                              backgroundColor: AppTheme.successColor,
                            ),
                          );
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                        title: const Text('Reset Local Sheet'),
                        subtitle: const Text('Clear local sheet reference (danger)'),
                        onTap: () {
                          _showResetConfirmation(context);
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.logout, color: AppTheme.textColor),
                        title: const Text('Logout'),
                        onTap: () {
                          _showLogoutConfirmation(context);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Disclaimer
                Card(
                  color: AppTheme.warningColor.withOpacity(0.3),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: AppTheme.textColor),
                            SizedBox(width: 8),
                            Text(
                              'Important Disclaimer',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          'This app:\n'
                          '• Is client-only\n'
                          '• Does not guarantee uniqueness across devices\n'
                          '• Is not suitable for high-security financial data\n'
                          '• Is designed for internal / prototype usage',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _showResetConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Local Sheet?'),
        content: const Text(
          'This will clear the local sheet reference. You will need to create a new sheet on next login.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<SheetBloc>().add(const SheetResetRequested());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Local sheet reference cleared'),
                  backgroundColor: AppTheme.warningColor,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<AuthBloc>().add(const AuthSignOutRequested());
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

