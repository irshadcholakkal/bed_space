/// Bedspace PWA: Supabase customer identity and customer-owned Google storage.
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:workmanager/workmanager.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/dashboard/dashboard_bloc.dart';
import 'presentation/blocs/room/room_bloc.dart';
import 'presentation/blocs/financial/financial_bloc.dart';
import 'presentation/blocs/notification/notification_bloc.dart';
import 'presentation/blocs/management/management_bloc.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'data/services/database_platform.dart';
import 'data/services/google_sheets_service.dart';
import 'data/repositories/management_repository.dart';
import 'data/repositories/sync_worker.dart';
import 'data/services/saas_service.dart';
import 'presentation/screens/saas_gate.dart';
import 'presentation/screens/billing_admin_screen.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final success = await SyncWorker().processQueue();
    return Future.value(success);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDatabasePlatform();
  await SaasService.initialize();

  // Workmanager supports Android and iOS, and accesses dart:io on creation.
  if (!SaasService.configured &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await Workmanager().initialize(callbackDispatcher);

    await Workmanager().registerPeriodicTask(
      'sync-task',
      'background-sync',
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  // Initialize timezone for notifications
  tz.initializeTimeZones();

  runApp(const BedSpaceApp());
}

class BedSpaceApp extends StatelessWidget {
  const BedSpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bedspace | Shared accommodation management',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const SaasGate(),
      routes: {'/admin': (_) => const BillingAdminScreen()},
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        // Handle auth state changes
        if (authState is AuthAuthenticated) {
          // User is authenticated with sheet
          return _buildAuthenticatedApp(context, authState);
        } else {
          // Not authenticated or no sheet
          return const LoginScreen();
        }
      },
    );
  }

  Widget _buildAuthenticatedApp(
      BuildContext context, AuthAuthenticated authState) {
    final sheetsService = GoogleSheetsService(
      accessToken: authState.accessToken,
      sheetId: authState.sheetId,
    );

    return WorkspaceScope(
      key: ValueKey(authState.sheetId),
      sheetId: authState.sheetId,
      child: Provider<ManagementRepository>(
        create: (context) => ManagementRepository(sheetsService: sheetsService),
        dispose: (context, repository) => repository.dispose(),
        child: Builder(
          builder: (context) {
            final repository = context.read<ManagementRepository>();
            return MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (context) => DashboardBloc(repository: repository)
                    ..add(const DashboardLoadRequested()),
                ),
                BlocProvider(
                  create: (context) => RoomBloc(repository: repository)
                    ..add(const RoomLoadRequested()),
                ),
                BlocProvider(
                  create: (context) => FinancialBloc(repository: repository),
                ),
                BlocProvider(
                  create: (context) => NotificationBloc(repository: repository)
                    ..add(const NotificationInitializeRequested())
                    ..add(const NotificationScheduleRemindersRequested()),
                ),
                BlocProvider(
                  create: (context) => ManagementBloc(repository: repository)
                    ..add(const LoadAllManagementData()),
                ),
              ],
              child: const HomeScreen(),
            );
          },
        ),
      ),
    );
  }
}
