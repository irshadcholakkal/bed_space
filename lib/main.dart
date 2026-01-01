/// Bed Space Management App
/// 
/// IMPORTANT DISCLAIMER:
/// This app:
/// - Is client-only (no backend, no Firebase)
/// - Uses Google Sign-In for authentication
/// - Uses Google Sheets API directly as database
/// - Does not guarantee uniqueness across devices
/// - Is not suitable for high-security financial data
/// - Is designed for internal / prototype usage
/// 
/// One Google user → one Google Sheet per device
/// Sheet ID is stored locally in SharedPreferences
/// On app reinstall, a new sheet may be created

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timezone/data/latest_all.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/sheet/sheet_bloc.dart';
import 'presentation/blocs/dashboard/dashboard_bloc.dart';
import 'presentation/blocs/room/room_bloc.dart';
import 'presentation/blocs/financial/financial_bloc.dart';
import 'presentation/blocs/notification/notification_bloc.dart';
import 'presentation/blocs/management/management_bloc.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/buildings_management_screen.dart';
import 'presentation/screens/rooms_management_screen.dart';
import 'presentation/screens/tenants_management_screen.dart';
import 'data/services/google_auth_service.dart';
import 'data/services/google_sheets_service.dart';
import 'data/repositories/sheet_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize timezone for notifications
  initializeTimeZones();
  
  runApp(const BedSpaceApp());
}

class BedSpaceApp extends StatelessWidget {
  const BedSpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Services
        BlocProvider(
          create: (context) => AuthBloc(
            authService: GoogleAuthService(),
            sheetRepository: SheetRepository(),
          )..add(const AuthCheckRequested()),
        ),
        BlocProvider(
          create: (context) => SheetBloc(
            sheetRepository: SheetRepository(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Bed Space Management',
        theme: AppTheme.theme,
        debugShowCheckedModeBanner: false,
        home: const AuthWrapper(),
        routes: {
          '/buildings': (context) => const BuildingsManagementScreen(),
          '/rooms-management': (context) => const RoomsManagementScreen(),
          '/tenants': (context) => const TenantsManagementScreen(),
        },
      ),
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

  Widget _buildAuthenticatedApp(BuildContext context, AuthAuthenticated authState) {
    final sheetsService = GoogleSheetsService(
      accessToken: authState.accessToken,
      sheetId: authState.sheetId,
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => DashboardBloc(sheetsService: sheetsService)
            ..add(const DashboardLoadRequested()),
        ),
        BlocProvider(
          create: (context) => RoomBloc(sheetsService: sheetsService)
            ..add(const RoomLoadRequested()),
        ),
        BlocProvider(
          create: (context) => FinancialBloc(sheetsService: sheetsService),
        ),
        BlocProvider(
          create: (context) => NotificationBloc(sheetsService: sheetsService)
            ..add(const NotificationInitializeRequested())
            ..add(const NotificationScheduleRemindersRequested()),
        ),
        BlocProvider(
          create: (context) => ManagementBloc(sheetsService: sheetsService)
            ..add(const LoadAllManagementData()),
        ),
      ],
      child: const HomeScreen(),
    );
  }
}
