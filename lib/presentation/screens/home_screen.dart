import 'package:flutter/cupertino.dart';
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
    if (path == '/tenants') return 3;
    if (path == '/settings') return 4;
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
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        currentIndex: tabFor(path),
        onTap: (index) => context.go([
          '/dashboard',
          '/rooms',
          '/financials',
          '/tenants',
          '/settings'
        ][index]),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.square_grid_2x2_fill),
              label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.rectangle_split_3x1), label: 'Rooms'),
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.creditcard), label: 'Financials'),
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.person_2), label: 'Tenants'),
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.gear), label: 'Settings'),
        ],
      ),
    );
  }
}
