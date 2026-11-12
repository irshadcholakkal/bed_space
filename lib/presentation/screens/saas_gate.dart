import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/sheet/sheet_bloc.dart';
import '../../data/services/google_auth_service.dart';
import '../../data/repositories/sheet_repository.dart';
import '../../data/services/saas_service.dart';
import '../../data/services/local_database_service.dart';
import '../../main.dart';
import 'landing_screen.dart';
import 'saas_auth_screen.dart';
import 'subscription_gate.dart';
import 'billing_admin_screen.dart';

/// Supabase identity gates the Google-connected workspace, including named routes.
class SaasGate extends StatefulWidget {
  final Widget? child;
  final bool requiresWorkspace;
  const SaasGate({super.key, this.child, this.requiresWorkspace = true});
  @override
  State<SaasGate> createState() => _SaasGateState();
}

class _SaasGateState extends State<SaasGate> {
  StreamSubscription<dynamic>? _subscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  bool _offline = false;
  int _authRevision = 0;
  @override
  void initState() {
    super.initState();
    Connectivity().checkConnectivity().then((connections) {
      if (mounted) {
        setState(() =>
            _offline = connections.every((c) => c == ConnectivityResult.none));
      }
    });
    _connectivity = Connectivity().onConnectivityChanged.listen((connections) {
      if (!mounted) return;
      final offline = connections.every((c) => c == ConnectivityResult.none);
      setState(() {
        if (_offline && !offline) _authRevision++;
        _offline = offline;
      });
    });
    if (SaasService.configured) {
      _subscription = SaasService.client.auth.onAuthStateChange.listen((data) {
        if (!mounted) return;
        if (data.event == AuthChangeEvent.signedIn) _authRevision++;
        if (SaasService.userId == null) {
          SheetRepository.clearSessionTokens();
        }
        if (GoRouter.maybeOf(context) == null &&
            (SaasService.userId == null ||
                data.event == AuthChangeEvent.signedIn)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          });
        }
        setState(() {});
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
    _connectivity?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (SaasService.userId == null) {
      if (SaasService.startupAuthError != null) {
        return SaasAuthScreen(
            register: false, initialMessage: SaasService.startupAuthError);
      }
      if (kIsWeb &&
          (Uri.base.path == '/app' || Uri.base.path.startsWith('/app/'))) {
        return SaasAuthScreen(
            register: Uri.base.queryParameters['view'] == 'signup',
            billingCycle: Uri.base.queryParameters['billing'] == 'annual'
                ? 'annual'
                : 'monthly');
      }
      return const LandingScreen();
    }
    if (!widget.requiresWorkspace) return widget.child!;
    return BillingAdminShortcut(
        key: ValueKey(SaasService.userId),
        child: SubscriptionGate(
            key: ValueKey(SaasService.userId),
            child: MultiBlocProvider(
                key: ValueKey('${SaasService.userId}:$_authRevision'),
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
                  if (_offline)
                    const Material(
                        color: Color(0xfffff3cd),
                        child: SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              child: Row(children: [
                                Expanded(
                                    child: Text('Offline · Showing saved data',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xff664d03))))
                              ]),
                            ))),
                  Expanded(
                      child: AuthWrapper(
                          key: ValueKey(SaasService.userId),
                          child: widget.child)),
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
