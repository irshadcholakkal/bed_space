import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../routing/app_routes.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/google_auth_service.dart';
import '../../data/services/saas_service.dart';

const _background = Color(0xff080a0a);
const _surface = Color(0xff111414);
const _ink = Color(0xfff5f5f5);
const _secondary = Color(0xffa6afad);
const _line = Color(0x20ffffff);

class SaasAuthScreen extends StatefulWidget {
  final bool register;
  final String billingCycle;
  final String? initialMessage;
  const SaasAuthScreen(
      {super.key,
      required this.register,
      this.billingCycle = 'monthly',
      this.initialMessage});
  @override
  State<SaasAuthScreen> createState() => _SaasAuthScreenState();
}

class _SaasAuthScreenState extends State<SaasAuthScreen> {
  late bool _register = widget.register;
  bool _busy = false;
  late String? _message = widget.initialMessage;
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;

  Future<void> _goHome() async {
    if (kIsWeb && Uri.base.path.startsWith('/app')) {
      await launchUrl(Uri.base.replace(path: '/', query: '', fragment: ''),
          webOnlyWindowName: '_self');
    } else if (mounted) {
      Navigator.maybePop(context);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    if (!_form.currentState!.validate() || !SaasService.configured) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      SaasService.startupAuthError = null;
      await _rememberDestination();
      if (_register) {
        final result = await SaasService.client.auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          emailRedirectTo: SaasService.authRedirectUrl,
          data: {'preferred_billing': widget.billingCycle},
        );
        if (result.session == null && mounted) {
          setState(() => _message =
              'Check your email to confirm your Bedspace account, then sign in.');
        }
      } else {
        await SaasService.client.auth.signInWithPassword(
            email: _email.text.trim(), password: _password.text);
      }
      if (mounted && SaasService.userId != null) {
        final router = GoRouter.maybeOf(context);
        if (router != null) {
          router.refresh();
        } else {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'Could not reach the account service. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rememberDestination() async {
    final router = GoRouter.maybeOf(context);
    await AppRouteIntent.save(
        router?.routeInformationProvider.value.uri.queryParameters['from']);
  }

  void _switchMode() {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      final parameters =
          router.routeInformationProvider.value.uri.queryParameters;
      router.go(Uri(path: _register ? '/login' : '/signup', queryParameters: {
        if (parameters['from'] != null) 'from': parameters['from']!,
        if (parameters['billing'] == 'annual') 'billing': 'annual',
      }).toString());
      return;
    }
    setState(() {
      _register = !_register;
      _message = null;
      _password.clear();
      _form.currentState?.reset();
    });
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      SaasService.startupAuthError = null;
      await _rememberDestination();
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

  TextStyle _serif(double size) => TextStyle(
      fontFamily: 'HedvigLetters',
      fontSize: size,
      color: _ink,
      fontWeight: FontWeight.w400,
      height: 1.12,
      letterSpacing: -.8);

  @override
  Widget build(BuildContext context) => Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: _background,
        colorScheme: const ColorScheme.dark(
            primary: _ink,
            onPrimary: _background,
            surface: _surface,
            onSurface: _ink,
            outline: _line),
        textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
                foregroundColor: _ink,
                textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13))),
      ),
      child: Scaffold(body: SafeArea(child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 960;
          return Column(children: [
            _navigation(constraints.maxWidth < 480),
            Expanded(
                child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    minHeight:
                        (constraints.maxHeight - 89).clamp(0, double.infinity)),
                child: Center(
                    child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      wide ? 48 : 20, wide ? 36 : 24, wide ? 48 : 20, 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                                Expanded(flex: 6, child: _landscape()),
                                const SizedBox(width: 64),
                                Expanded(flex: 5, child: _account()),
                              ])
                        : ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: _account()),
                  ),
                )),
              ),
            )),
          ]);
        },
      ))));

  Widget _navigation(bool compact) => Container(
      decoration:
          const BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
      padding:
          EdgeInsets.symmetric(horizontal: compact ? 16 : 40, vertical: 16),
      child: Row(children: [
        TextButton(
          onPressed: _busy ? null : _goHome,
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/logo.png',
                width: 32, height: 36, semanticLabel: 'Bedspace logo'),
            const SizedBox(width: 10),
            Text('Bedspace', style: _serif(compact ? 23 : 27)),
          ]),
        ),
        const Spacer(),
        if (compact)
          IconButton(
            tooltip: 'Back to home',
            onPressed: _busy ? null : _goHome,
            icon: const Icon(CupertinoIcons.arrow_left, size: 18),
          )
        else
          TextButton.icon(
            onPressed: _busy ? null : _goHome,
            icon: const Icon(CupertinoIcons.arrow_left, size: 15),
            label: const Text('Back to home'),
          ),
      ]));

  Widget _landscape() => ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
          height: 660,
          child: Stack(fit: StackFit.expand, children: [
            Image.asset('assets/landing/landscape.jpg',
                fit: BoxFit.cover, excludeFromSemantics: true),
            const DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                  Color(0x15080a0a),
                  Color(0x60080a0a),
                  Color(0xf5080a0a)
                ]))),
            Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                              color: const Color(0x35080a0a),
                              border:
                                  Border.all(color: const Color(0x45ffffff)),
                              borderRadius: BorderRadius.circular(30)),
                          child: const Text('A LITTLE MORE ROOM TO FOCUS',
                              style: TextStyle(
                                  fontFamily: 'GeistMono',
                                  fontSize: 10,
                                  color: _ink,
                                  letterSpacing: 1))),
                      const Spacer(),
                      Text('Shared spaces.\nSimpler days.', style: _serif(60)),
                      const SizedBox(height: 20),
                      const Text(
                          'A calmer place for your buildings, tenants and rent. Connected to the Google account you already use.',
                          style: TextStyle(
                              color: Color(0xffd0d7d4),
                              fontSize: 15,
                              height: 1.8)),
                      const SizedBox(height: 32),
                      const Divider(color: Color(0x45ffffff)),
                      const SizedBox(height: 16),
                      const Row(children: [
                        Icon(CupertinoIcons.folder, color: _ink, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                            child: Text('Your records. Your Google account.',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xffd0d7d4)))),
                      ]),
                    ])),
          ])));

  Widget _account() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_register ? 'MAKE YOURSELF AT HOME' : 'YOUR WORKSPACE AWAITS',
                style: const TextStyle(
                    fontFamily: 'GeistMono',
                    color: _secondary,
                    fontSize: 10,
                    letterSpacing: 1.3,
                    height: 1.8)),
            const SizedBox(height: 18),
            Text(
                _register
                    ? 'Make room for\na simpler day.'
                    : 'Welcome back.\nSettle right in.',
                style: _serif(44)),
            const SizedBox(height: 20),
            Text(
                _register
                    ? 'Start your Bedspace workspace with Google or your email. A little less admin, a lot more clarity.'
                    : 'Your spaces, people and rent records, together again. Choose how you sign in to your workspace.',
                style: const TextStyle(
                    color: _secondary, fontSize: 14, height: 1.85)),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: _surface,
                  border: Border.all(color: _line),
                  borderRadius: BorderRadius.circular(20)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                        _register
                            ? 'Create your account'
                            : 'Sign in to Bedspace',
                        style: const TextStyle(
                            color: _ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 10),
                    const Text(
                        'Choose Google or your Bedspace email and password.',
                        style: TextStyle(
                            color: _secondary, fontSize: 12, height: 1.7)),
                    const SizedBox(height: 24),
                    FilledButton(
                        onPressed:
                            _busy || !SaasService.configured ? null : _submit,
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xff1f1f1f),
                            side: const BorderSide(color: Color(0xff747775)),
                            disabledBackgroundColor: const Color(0xff333a38),
                            disabledForegroundColor: const Color(0xffa6afad),
                            minimumSize: const Size.fromHeight(54),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16)),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_busy)
                                const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                              else
                                Image.asset('assets/auth/google_g.png',
                                    width: 20,
                                    height: 20,
                                    excludeFromSemantics: true),
                              const SizedBox(width: 12),
                              Flexible(
                                  child: Text(
                                      _busy
                                          ? 'Connecting...'
                                          : 'Continue with Google',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600))),
                            ])),
                    const SizedBox(height: 24),
                    const Row(children: [
                      Expanded(child: Divider(color: _line)),
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or use email',
                              style:
                                  TextStyle(color: _secondary, fontSize: 12))),
                      Expanded(child: Divider(color: _line)),
                    ]),
                    const SizedBox(height: 20),
                    _emailForm(),
                    if (_message != null || !SaasService.configured) ...[
                      const SizedBox(height: 16),
                      Semantics(
                          liveRegion: true,
                          child: Text(
                              _message ??
                                  'Account sign-in is not configured for this deployment. Please contact the site administrator.',
                              style: const TextStyle(
                                  color: Color(0xffffc4b5),
                                  fontSize: 12,
                                  height: 1.7))),
                    ],
                    const SizedBox(height: 22),
                    const Divider(color: _line, height: 1),
                    const SizedBox(height: 20),
                    const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(CupertinoIcons.lock,
                              size: 16, color: _secondary),
                          SizedBox(width: 10),
                          Expanded(
                              child: Text(
                                  'Google sign-in also connects Sheets and Drive. With email sign-in, you will connect Google separately. Use a Bedspace password here, never your Google password.',
                                  style: TextStyle(
                                      color: _secondary,
                                      fontSize: 11,
                                      height: 1.8))),
                        ]),
                  ]),
            ),
            const SizedBox(height: 22),
            Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(_register ? 'Already at home here?' : 'New to Bedspace?',
                      style: const TextStyle(color: _secondary, fontSize: 12)),
                  TextButton(
                      onPressed: _busy ? null : _switchMode,
                      child: Text(_register ? 'Sign in' : 'Create an account')),
                ]),
            const SizedBox(height: 18),
            const Text('Shared spaces, thoughtfully managed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _secondary, fontSize: 10, height: 1.8)),
          ]);

  Widget _emailForm() => Form(
        key: _form,
        child: AutofillGroup(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              style: const TextStyle(color: _ink),
              decoration: _fieldDecoration('Email address'),
              validator: (value) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                      .hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Enter a valid email address',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              enabled: !_busy,
              obscureText: _hidePassword,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: [
                _register ? AutofillHints.newPassword : AutofillHints.password
              ],
              style: const TextStyle(color: _ink),
              decoration: _fieldDecoration('Bedspace password').copyWith(
                suffixIcon: IconButton(
                  tooltip: _hidePassword ? 'Show password' : 'Hide password',
                  onPressed: _busy
                      ? null
                      : () => setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(
                      _hidePassword
                          ? CupertinoIcons.eye
                          : CupertinoIcons.eye_slash,
                      size: 20),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Enter your Bedspace password';
                }
                if (_register && value.length < 8) {
                  return 'Use at least 8 characters';
                }
                return null;
              },
              onFieldSubmitted: (_) {
                if (!_busy) _submitEmail();
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy || !SaasService.configured ? null : _submitEmail,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: const StadiumBorder()),
              child: Text(_busy
                  ? 'Please wait...'
                  : _register
                      ? 'Sign up with email'
                      : 'Sign in with email'),
            ),
          ],
        )),
      );

  InputDecoration _fieldDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _secondary, fontSize: 13),
        filled: true,
        fillColor: _background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _line)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _line)),
        errorMaxLines: 2,
      );
}
