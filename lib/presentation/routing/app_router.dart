import '../screens/bookings_screen.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../data/services/saas_service.dart';
import '../../data/services/subscription_service.dart';
import '../blocs/management/management_bloc.dart';
import '../screens/saas_gate.dart';
import '../screens/saas_auth_screen.dart';
import '../screens/landing_screen.dart';
import '../screens/home_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/rooms_screen.dart';
import '../screens/financials_screen.dart';
import '../screens/tenant_payments_screen.dart';
import '../screens/room_occupancy_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/buildings_management_screen.dart';
import '../screens/rooms_management_screen.dart';
import '../screens/tenants_management_screen.dart';
import '../screens/vacant_beds_screen.dart';
import '../screens/room_expenses_screen.dart';
import '../screens/billing_admin_screen.dart';
import '../screens/billing_screen.dart';
import 'app_routes.dart';

class AuthRouterRefresh extends ChangeNotifier {
  StreamSubscription<dynamic>? _subscription;
  AuthRouterRefresh() {
    if (SaasService.configured) {
      _subscription = SaasService.client.auth.onAuthStateChange.listen(
          (_) => notifyListeners(),
          onError: (Object _) => notifyListeners());
    }
  }
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

GoRouter createAppRouter(Listenable refresh) {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  return GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final path = state.uri.path;
      final signedIn = SaasService.userId != null;
      final authPage = path == '/login' || path == '/signup';
      if (path == '/') {
        if (state.uri.queryParameters['view'] == 'signup' && !signedIn) {
          return Uri(path: '/signup', queryParameters: {
            if (state.uri.queryParameters['billing'] == 'annual')
              'billing': 'annual',
          }).toString();
        }
        if (signedIn) {
          if (state.uri.queryParameters['billing'] == 'return') {
            return '/billing';
          }
          return AppRouteIntent.take() ??
              AppSessionRoute.lastRoute ??
              AppRoutes.dashboard;
        }
        if (state.uri.queryParameters['billing'] == 'return') {
          return '/login?from=%2Fbilling';
        }
        if (!kIsWeb) return null;
        return '/login';
      }
      if (!signedIn && !authPage) {
        final from = AppRoutes.safeDestination(path);
        if (from == null) return null; // Render a real not-found page.
        return Uri(path: '/login', queryParameters: {'from': from}).toString();
      }
      if (signedIn && authPage) {
        return AppRoutes.safeDestination(state.uri.queryParameters['from']) ??
            AppRouteIntent.take() ??
            AppSessionRoute.lastRoute ??
            AppRoutes.dashboard;
      }
      return null;
    },
    errorBuilder: (context, state) => const RouteNotFound(),
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LandingScreen()),
      for (final register in [false, true])
        GoRoute(
            path: register ? '/signup' : '/login',
            builder: (_, state) => SaasAuthScreen(
                  register: register,
                  billingCycle: state.uri.queryParameters['billing'] == 'annual'
                      ? 'annual'
                      : 'monthly',
                  initialMessage: SaasService.startupAuthError,
                )),
      GoRoute(
          path: '/admin',
          builder: (_, __) => const SaasGate(
              requiresWorkspace: false,
              child: AccountRouteFrame(child: BillingAdminScreen()))),
      GoRoute(
          path: '/billing',
          builder: (_, __) => const SaasGate(
              requiresWorkspace: false,
              child: AccountRouteFrame(child: MembershipRoute()))),
      GoRoute(path: '/auth/callback', redirect: (_, state) => '/'),
      GoRoute(path: '/billing/return', redirect: (_, state) => '/billing'),
      ShellRoute(
          builder: (_, __, child) => SaasGate(child: HomeScreen(child: child)),
          routes: [
            GoRoute(
                path: '/dashboard',
                builder: (_, __) => const DashboardScreen()),
            GoRoute(
                path: '/rooms',
                builder: (_, state) => RoomsScreen(
                    period: state.uri.queryParameters['period'],
                    buildingId: state.uri.queryParameters['building'],
                    roomId: state.uri.queryParameters['room'])),
            GoRoute(
                path: '/rooms/occupancy',
                builder: (_, __) => const RoomOccupancyScreen()),
            GoRoute(
                path: '/financials/tenants',
                builder: (_, __) => const TenantPaymentsScreen()),
            GoRoute(
                path: '/financials',
                builder: (_, __) => const FinancialsScreen()),
            GoRoute(
                path: '/settings', builder: (_, __) => const SettingsScreen()),
            GoRoute(
                path: '/buildings',
                builder: (_, __) => const BuildingsManagementScreen()),
            GoRoute(
                path: '/rooms/manage',
                builder: (_, __) => const RoomsManagementScreen()),
            GoRoute(
                path: '/bookings', builder: (_, __) => const BookingsScreen()),
            GoRoute(
                path: '/tenants',
                builder: (_, __) => const TenantsManagementScreen()),
            GoRoute(
                path: '/rooms/available',
                builder: (_, __) => const VacantBedsScreen()),
            GoRoute(
                path: '/vacant-beds',
                builder: (_, __) => const VacantBedsScreen()),
            GoRoute(
                path: '/connect-google',
                builder: (_, __) => const ConnectedRoute()),
            GoRoute(
                path: '/rooms/:roomId/expenses',
                builder: (_, state) =>
                    RoomExpensesRoute(roomId: state.pathParameters['roomId']!)),
            GoRoute(
                path: '/tenants/:tenantId/rent-balance',
                builder: (_, state) => RentBalanceScreen(
                    tenantId: state.pathParameters['tenantId']!)),
          ]),
    ],
  );
}

class RouteNotFound extends StatelessWidget {
  const RouteNotFound({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Page not found')),
        body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('This page could not be found.'),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Go to dashboard')),
        ])),
      );
}

class AccountRouteFrame extends StatelessWidget {
  final Widget child;
  const AccountRouteFrame({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Column(children: [
        Material(
            child: SafeArea(
                bottom: false,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/dashboard'),
                      icon: const Icon(CupertinoIcons.arrow_left),
                      label: const Text('Back to workspace')),
                ))),
        Expanded(child: child),
      ]);
}

class RoomExpensesRoute extends StatelessWidget {
  final String roomId;
  const RoomExpensesRoute({super.key, required this.roomId});
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<ManagementBloc, ManagementState>(
        builder: (context, state) {
          if (state is! ManagementLoaded || state.isLoading) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          final rooms = state.rooms.where((room) => room.roomId == roomId);
          if (rooms.isEmpty) return const RouteNotFound();
          return RoomExpensesScreen(room: rooms.first);
        },
      );
}

/// The surrounding workspace gate shows Google connection until authenticated.
class ConnectedRoute extends StatelessWidget {
  const ConnectedRoute({super.key});
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/dashboard');
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class MembershipRoute extends StatefulWidget {
  const MembershipRoute({super.key});
  @override
  State<MembershipRoute> createState() => _MembershipRouteState();
}

class _MembershipRouteState extends State<MembershipRoute> {
  late Future<AccountAccess> _access = SubscriptionService.access();
  @override
  Widget build(BuildContext context) => FutureBuilder<AccountAccess>(
      future: _access,
      builder: (_, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return BillingScreen(
            access: snapshot.data,
            onRefresh: () => setState(() {
                  _access = SubscriptionService.access();
                }));
      });
}
