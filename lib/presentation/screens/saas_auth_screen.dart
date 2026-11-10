import 'package:flutter/material.dart';
import '../../data/services/google_auth_service.dart';
import '../../data/services/saas_service.dart';

class SaasAuthScreen extends StatefulWidget {
  final bool register;
  final String billingCycle;
  const SaasAuthScreen(
      {super.key, required this.register, this.billingCycle = 'monthly'});
  @override
  State<SaasAuthScreen> createState() => _SaasAuthScreenState();
}

class _SaasAuthScreenState extends State<SaasAuthScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await GoogleAuthService().signIn();
    } catch (_) {
      if (mounted) {
        setState(() =>
            _message = 'Could not continue with Google. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xfff7f6f0),
        appBar: AppBar(title: const Text('bedspace')),
        body: Center(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
                child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.bed_outlined,
                        size: 42, color: Color(0xff122c2a)),
                    const SizedBox(height: 22),
                    Text(
                        widget.register
                            ? 'Get started with Google.'
                            : 'Welcome back.',
                        style: const TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    const Text(
                        'One Google sign-in creates or opens your Bedspace account and connects your Google Sheets and Drive.'),
                    const SizedBox(height: 24),
                    if (!SaasService.configured)
                      const Text('The account service needs to be configured.'),
                    if (_message != null)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Semantics(
                              liveRegion: true, child: Text(_message!))),
                    FilledButton.icon(
                        onPressed:
                            _busy || !SaasService.configured ? null : _submit,
                        icon: const Icon(Icons.login),
                        label: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(_busy
                                ? 'Please wait...'
                                : 'Continue with Google'))),
                    const SizedBox(height: 18),
                    const Text(
                        'Allow Sheets and Drive access on the Google consent screen. Your accommodation records stay in your Google account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, height: 1.6)),
                  ]),
            )),
          ),
        )),
      );
}
