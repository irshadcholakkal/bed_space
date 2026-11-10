import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/sheet/sheet_bloc.dart';
import '../../data/services/google_auth_service.dart';
import '../../data/repositories/sheet_repository.dart';
import '../../data/services/saas_service.dart';
import '../../data/services/local_database_service.dart';
import '../../main.dart';
import 'landing_screen.dart';
import 'subscription_gate.dart';
import 'billing_admin_screen.dart';

/// Supabase identity gates the Google-connected workspace, including named routes.
class SaasGate extends StatefulWidget {
  const SaasGate({super.key});
  @override
  State<SaasGate> createState() => _SaasGateState();
}

class _SaasGateState extends State<SaasGate> {
  StreamSubscription<dynamic>? _subscription;
  @override
  void initState() {
    super.initState();
    if (SaasService.configured) {
      _subscription = SaasService.client.auth.onAuthStateChange.listen((_) {
        if (SaasService.userId == null) {
          SheetRepository.clearSessionTokens();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          });
        }
        if (mounted) setState(() {});
      }, onError: (Object error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Session could not be refreshed. Please sign in again.')),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (SaasService.userId == null) return const LandingScreen();
    return BillingAdminShortcut(
        key: ValueKey(SaasService.userId),
        child: SubscriptionGate(
            key: ValueKey(SaasService.userId),
            child: MultiBlocProvider(
                key: ValueKey(SaasService.userId),
                providers: [
                  BlocProvider(
                      create: (_) => AuthBloc(
                          authService: GoogleAuthService(),
                          sheetRepository: SheetRepository())
                        ..add(const AuthCheckRequested())),
                  BlocProvider(
                      create: (_) =>
                          SheetBloc(sheetRepository: SheetRepository())),
                ],
                child: Column(children: [
                  Material(
                      color: const Color(0xff122c2a),
                      child: SafeArea(
                          bottom: false,
                          child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 6),
                              child: Row(children: [
                                const Icon(Icons.bed_outlined,
                                    color: Colors.white),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(
                                        SaasService.client.auth.currentUser
                                                ?.email ??
                                            'Your workspace',
                                        style: const TextStyle(
                                            color: Colors.white),
                                        overflow: TextOverflow.ellipsis)),
                                TextButton(
                                    onPressed: () async {
                                      try {
                                        await GoogleAuthService().signOut();
                                        await SaasService.client.auth.signOut();
                                      } catch (_) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text(
                                                      'Could not sign out. Please try again.')));
                                        }
                                      }
                                    },
                                    child: const Text('Sign out of account',
                                        style: TextStyle(color: Colors.white))),
                              ])))),
                  Expanded(
                      child: AuthWrapper(key: ValueKey(SaasService.userId))),
                ]))));
  }
}

class WorkspaceScope extends StatefulWidget {
  final String sheetId;
  final Widget child;
  const WorkspaceScope({super.key, required this.sheetId, required this.child});
  @override
  State<WorkspaceScope> createState() => _WorkspaceScopeState();
}

class _WorkspaceScopeState extends State<WorkspaceScope> {
  late Future<void> _ready;
  @override
  void initState() {
    super.initState();
    _ready = LocalDatabaseService.selectWorkspace(widget.sheetId);
  }

  @override
  void didUpdateWidget(WorkspaceScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sheetId != widget.sheetId) {
      _ready = LocalDatabaseService.selectWorkspace(widget.sheetId);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
              body: Center(
                  child: Text('Could not open workspace. Please reload.')));
        }
        return snapshot.connectionState == ConnectionState.done
            ? widget.child
            : const Center(child: CircularProgressIndicator());
      });
}
