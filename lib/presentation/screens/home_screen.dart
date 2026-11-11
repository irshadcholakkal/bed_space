import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dashboard_screen.dart';

class HomeScreen extends StatelessWidget {
  final Widget? child;
  const HomeScreen({super.key, this.child});

  static int tabFor(String path) {
    if (path == '/financials' ||
        path.startsWith('/financials/') ||
        path.endsWith('/rent-balance')) {
      return 2;
    }
    if (path == '/settings') return 3;
    if (path == '/rooms' || path.startsWith('/rooms/')) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final path =
        GoRouter.maybeOf(context)?.routeInformationProvider.value.uri.path ??
            '/dashboard';
    return Scaffold(
      body: child ?? const DashboardScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tabFor(path),
        onTap: (index) => context
            .go(['/dashboard', '/rooms', '/financials', '/settings'][index]),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.grid_view), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.meeting_room_outlined), label: 'Rooms'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              label: 'Financials'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
