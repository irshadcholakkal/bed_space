import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bed_space/presentation/routing/app_router.dart';
import 'package:bed_space/presentation/routing/app_routes.dart';
import 'package:bed_space/presentation/screens/home_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('All application pages have explicit routes', () {
    final refresh = ValueNotifier(0);
    final router = createAppRouter(refresh);
    for (final path in [
      ...AppRoutes.pages,
      '/login',
      '/signup',
      '/rooms/room-101/expenses',
      '/tenants/tenant-1/rent-balance',
      '/auth/callback',
      '/billing/return'
    ]) {
      expect(router.configuration.findMatch(Uri.parse(path)).isError, isFalse,
          reason: path);
    }
    expect(
        router.configuration.findMatch(Uri.parse('/missing')).isError, isTrue);
    router.dispose();
    refresh.dispose();
  });

  test('Return destinations reject external URLs and remove OAuth fields', () {
    expect(AppRoutes.safeDestination('https://other.example/settings'), isNull);
    expect(AppRoutes.safeDestination('//other.example/settings'), isNull);
    expect(AppRoutes.safeDestination('/login'), isNull);
    expect(AppRoutes.safeDestination('/not-a-page'), isNull);
    expect(
        AppRoutes.safeDestination(
            '/rooms/room-1/expenses?code=private#access_token=secret'),
        '/rooms/room-1/expenses');
  });

  test('Google round trip remembers a safe destination once', () async {
    await AppRouteIntent.save('/tenants/person-1/rent-balance');
    await AppRouteIntent.restore();
    expect(AppRouteIntent.take(), '/tenants/person-1/rent-balance');
    expect(AppRouteIntent.take(), isNull);
    await AppRouteIntent.save('https://other.example');
    expect(AppRouteIntent.take(), isNull);
  });

  testWidgets('Direct protected links go to login and keep their destination',
      (tester) async {
    final refresh = ValueNotifier(0);
    final router = createAppRouter(refresh);
    router.go('/rooms/room-101/expenses');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/login');
    expect(router.routeInformationProvider.value.uri.queryParameters['from'],
        '/rooms/room-101/expenses');
    expect(find.text('Sign in to Bedspace'), findsOneWidget);
    await tester.ensureVisible(find.text('Create an account'));
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/signup');
    expect(router.routeInformationProvider.value.uri.queryParameters['from'],
        '/rooms/room-101/expenses');
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    refresh.dispose();
  });

  testWidgets('Unknown URLs show a not-found page', (tester) async {
    final refresh = ValueNotifier(0);
    final router = createAppRouter(refresh)..go('/missing');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('This page could not be found.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    refresh.dispose();
  });

  testWidgets('Bottom navigation updates URL and browser route content',
      (tester) async {
    final router = GoRouter(initialLocation: '/dashboard', routes: [
      ShellRoute(builder: (_, __, child) => HomeScreen(child: child), routes: [
        for (final page in [
          'dashboard',
          'rooms',
          'financials',
          'tenants',
          'settings'
        ])
          GoRoute(
              path: '/$page',
              builder: (_, __) => Center(child: Text('page:$page'))),
      ]),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/settings');
    expect(find.text('page:settings'), findsOneWidget);
    expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        4);
    final back = router.push<void>('/rooms');
    await tester.pumpAndSettle();
    expect(find.text('page:rooms'), findsOneWidget);
    expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        1);
    router.pop();
    await tester.pumpAndSettle();
    await back;
    expect(find.text('page:settings'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/settings');
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
}
