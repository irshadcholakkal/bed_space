import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/saas_service.dart';

class SaasAuthScreen extends StatefulWidget {
  final bool register;
  const SaasAuthScreen({super.key, required this.register});
  @override
  State<SaasAuthScreen> createState() => _SaasAuthScreenState();
}

class _SaasAuthScreenState extends State<SaasAuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _business = TextEditingController();
  final _email = TextEditingController(), _password = TextEditingController();
  late bool _register;
  bool _busy = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    _register = widget.register;
  }

  @override
  void dispose() {
    for (final c in [_name, _business, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_register) {
        final result = await SaasService.client.auth.signUp(
            email: _email.text.trim(),
            password: _password.text,
            emailRedirectTo:
                Uri.base.replace(path: '/', query: '', fragment: '').toString(),
            data: {
              'display_name': _name.text.trim(),
              'business_name': _business.text.trim()
            });
        if (result.session == null) {
          if (mounted) {
            setState(() => _message =
                'Check your email to confirm your account, then sign in.');
          }
          return;
        }
      } else {
        await SaasService.client.auth.signInWithPassword(
            email: _email.text.trim(), password: _password.text);
      }
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'Unable to reach the account service. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xfff7f6f0),
        appBar: AppBar(
            title: const Text('bedspace'),
            backgroundColor: const Color(0xfff7f6f0)),
        body: Center(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Card(
                        child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Form(
                                key: _form,
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.bed_outlined,
                                          size: 42, color: Color(0xff122c2a)),
                                      const SizedBox(height: 22),
                                      Text(
                                          _register
                                              ? 'Your next chapter starts here.'
                                              : 'Welcome back.',
                                          style: const TextStyle(
                                              fontSize: 30,
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 12),
                                      Text(_register
                                          ? 'Create your account. Connect your own Google storage after signing in.'
                                          : 'Sign in to your Bedspace account.'),
                                      const SizedBox(height: 24),
                                      if (!SaasService.configured)
                                        const Padding(
                                            padding:
                                                EdgeInsets.only(bottom: 18),
                                            child: Text(
                                                'Registration is not available yet. The account service needs to be configured.')),
                                      if (_register) ...[
                                        TextFormField(
                                            controller: _name,
                                            enabled: !_busy,
                                            decoration: const InputDecoration(
                                                labelText: 'Your name'),
                                            validator: (v) =>
                                                (v?.trim().isEmpty ?? true)
                                                    ? 'Enter your name'
                                                    : null),
                                        const SizedBox(height: 16),
                                        TextFormField(
                                            controller: _business,
                                            enabled: !_busy,
                                            decoration: const InputDecoration(
                                                labelText: 'Business name'),
                                            validator: (v) =>
                                                (v?.trim().isEmpty ?? true)
                                                    ? 'Enter your business name'
                                                    : null),
                                        const SizedBox(height: 16),
                                      ],
                                      TextFormField(
                                          controller: _email,
                                          enabled: !_busy,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          autofillHints: const [
                                            AutofillHints.email
                                          ],
                                          decoration: const InputDecoration(
                                              labelText: 'Email address'),
                                          validator: (v) =>
                                              RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                                      .hasMatch(v?.trim() ?? '')
                                                  ? null
                                                  : 'Enter a valid email'),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                          controller: _password,
                                          enabled: !_busy,
                                          obscureText: true,
                                          autofillHints: [
                                            _register
                                                ? AutofillHints.newPassword
                                                : AutofillHints.password
                                          ],
                                          decoration: const InputDecoration(
                                              labelText: 'Password'),
                                          validator: (v) => (v?.length ?? 0) < 8
                                              ? 'Use at least 8 characters'
                                              : null,
                                          onFieldSubmitted: (_) {
                                            if (!_busy &&
                                                SaasService.configured) {
                                              _submit();
                                            }
                                          }),
                                      const SizedBox(height: 22),
                                      if (_message != null)
                                        Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 18),
                                            child: Semantics(
                                                liveRegion: true,
                                                child: Text(_message!))),
                                      FilledButton(
                                          style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xff122c2a),
                                              foregroundColor: Colors.white),
                                          onPressed:
                                              _busy || !SaasService.configured
                                                  ? null
                                                  : _submit,
                                          child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Text(_busy
                                                  ? 'Please wait…'
                                                  : _register
                                                      ? 'Create account'
                                                      : 'Sign in'))),
                                      TextButton(
                                          onPressed: _busy
                                              ? null
                                              : () => setState(() {
                                                    _register = !_register;
                                                    _message = null;
                                                  }),
                                          child: Text(_register
                                              ? 'Already registered? Sign in'
                                              : 'New to Bedspace? Create an account')),
                                      const SizedBox(height: 10),
                                      const Text(
                                          'Account details stay in Supabase. Your accommodation records stay in your connected Google Sheets.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 12, height: 1.6)),
                                    ]))))))),
      );
}
