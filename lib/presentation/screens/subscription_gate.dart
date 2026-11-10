import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/services/subscription_service.dart';
import '../../data/services/saas_service.dart';
import 'billing_screen.dart';

class SubscriptionGate extends StatefulWidget {
  final Widget child;
  final Future<AccountAccess> Function()? loadAccess;
  const SubscriptionGate({super.key, required this.child, this.loadAccess});
  @override
  State<SubscriptionGate> createState() => _SubscriptionGateState();
}

class _SubscriptionGateState extends State<SubscriptionGate>
    with WidgetsBindingObserver {
  AccountAccess? _access;
  MembershipCheckFailure _failure = MembershipCheckFailure.connection;
  Timer? _timer;
  bool _loading = true, _failed = false, _requesting = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (_requesting) return;
    _requesting = true;
    try {
      final access = await (widget.loadAccess ?? SubscriptionService.access)();
      if (!mounted) return;
      setState(() {
        _access = access;
        _loading = false;
        _failed = false;
      });
      _timer?.cancel();
      final remaining = access.accessUntil.difference(access.serverNow);
      final delay = access.allowed && remaining < const Duration(minutes: 1)
          ? remaining
          : const Duration(minutes: 1);
      _timer = Timer(delay.isNegative ? Duration.zero : delay, () {
        if (mounted) {
          if (access.allowed && remaining <= const Duration(minutes: 1)) {
            setState(() {
              _loading = true;
              _access = null;
            });
          }
          _refresh();
        }
      });
      if (!access.allowed) _closeWorkspaceRoutes();
    } catch (error) {
      if (mounted) {
        setState(() {
          _failed = true;
          _failure = MembershipCheckFailure.fromError(error);
          _loading = false;
          _access = null;
        });
        _closeWorkspaceRoutes();
      }
    } finally {
      _requesting = false;
    }
  }

  void _closeWorkspaceRoutes() =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_failed) {
      return Scaffold(
          body: Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_failure.message, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('Reference: ${_failure.reference}',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: _refresh, child: const Text('Try again')),
                    TextButton(
                        onPressed: () => SaasService.client.auth.signOut(),
                        child: const Text('Sign out')),
                  ]))));
    }
    if (_access?.allowed != true) {
      return BillingScreen(access: _access, onRefresh: _refresh);
    }
    return Column(children: [
      Material(
          color: const Color(0xfff0f3ee),
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
              child: Row(children: [
                Expanded(
                    child: Text(
                        _access!.paidUntil == null
                            ? 'Your one-month free trial is active'
                            : 'Your membership is active',
                        style: const TextStyle(fontSize: 12))),
                TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => BillingScreen(access: _access))),
                    child: const Text('Membership')),
              ]))),
      Expanded(child: widget.child),
    ]);
  }
}
