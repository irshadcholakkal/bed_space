import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        title: Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppTheme.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          if (authState is AuthAuthenticated ||
              authState is AuthAuthenticatedWithoutSheet) {
            final userEmail = authState is AuthAuthenticated
                ? authState.userEmail
                : (authState as AuthAuthenticatedWithoutSheet).userEmail;

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Account Section
                Text(
                  'Account',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: AppTheme.cardDecoration,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        child: Text(
                          userEmail.isNotEmpty
                              ? userEmail[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userEmail,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Authenticated via Google',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Sheet Info Section
                if (authState is AuthAuthenticated) ...[
                  Text(
                    'Data Source',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    margin: const EdgeInsets.only(bottom: 32),
                    decoration: AppTheme.cardDecoration,
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          leading: const Icon(
                            Icons.grid_on_outlined,
                            color: AppTheme.primaryColor,
                          ),
                          title: const Text(
                            'Sheet Name',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textColor,
                            ),
                          ),
                          subtitle: Text(
                            'BedSpace_$userEmail',
                            style: TextStyle(
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                        ),
                        Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          leading: const Icon(
                            Icons.link,
                            color: AppTheme.primaryColor,
                          ),
                          title: const Text(
                            'Sheet ID',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textColor,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.copy,
                              size: 20,
                              color: AppTheme.primaryColor,
                            ),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: authState.sheetId),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Sheet ID copied to clipboard'),
                                  backgroundColor: AppTheme.successColor,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Actions Section
                Text(
                  'Actions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: AppTheme.cardDecoration,
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        leading: const Icon(
                          Icons.sync_outlined,
                          color: AppTheme.primaryColor,
                        ),
                        title: const Text(
                          'Re-sync Sheet',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Refresh data from Google Sheets',
                          style: TextStyle(color: AppTheme.secondaryTextColor),
                        ),
                        onTap: () {
                          context.read<SheetBloc>().add(
                            const SheetSyncRequested(),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sheet synced'),
                              backgroundColor: AppTheme.successColor,
                            ),
                          );
                        },
                      ),
                      Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        leading: const Icon(
                          Icons.delete_outline,
                          color: AppTheme.errorColor,
                        ),
                        title: const Text(
                          'Reset Local Data',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textColor,
                          ),
                        ),
                        subtitle: Text(
                          'Clear local sheet reference',
                          style: TextStyle(color: AppTheme.secondaryTextColor),
                        ),
                        onTap: () {
                          _showResetConfirmation(context);
                        },
                      ),
                      Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        leading: const Icon(
                          Icons.logout,
                          color: AppTheme.textColor,
                        ),
                        title: const Text(
                          'Logout',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onTap: () {
                          _showLogoutConfirmation(context);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Disclaimer
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.warningColor.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppTheme.warningColor,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Disclaimer',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'This application does not guarantee data uniqueness across devices and is intended for prototyping purposes. Not for high-security financial data.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textColor.withOpacity(0.8),
                          height: 1.5,
                        ),
                      ),
                    ],
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text(
          'Reset Local Sheet?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will clear the local sheet reference. You will need to create a new sheet on next login.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.secondaryTextColor),
            ),
          ),
          ElevatedButton(
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text(
          'Logout?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.secondaryTextColor),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<AuthBloc>().add(const AuthSignOutRequested());
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
