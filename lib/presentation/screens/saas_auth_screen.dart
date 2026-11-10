import 'package:flutter/material.dart';
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
  const SaasAuthScreen(
      {super.key, required this.register, this.billingCycle = 'monthly'});
  @override
  State<SaasAuthScreen> createState() => _SaasAuthScreenState();
}

class _SaasAuthScreenState extends State<SaasAuthScreen> {
  late bool _register = widget.register;
  bool _busy = false;
  String? _message;

  void _switchMode() => setState(() {
        _register = !_register;
        _message = null;
      });

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
          onPressed: _busy ? null : () => Navigator.maybePop(context),
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
            onPressed: _busy ? null : () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back, size: 18),
          )
        else
          TextButton.icon(
            onPressed: _busy ? null : () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back, size: 15),
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
                        Icon(Icons.folder_outlined, color: _ink, size: 18),
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
                    ? 'Start your Bedspace workspace with one Google account. A little less admin, a lot more clarity.'
                    : 'Your spaces, people and rent records, together again. Continue with the Google account linked to your workspace.',
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
                    const Text('One sign-in for Bedspace, Sheets and Drive.',
                        style: TextStyle(
                            color: _secondary, fontSize: 12, height: 1.7)),
                    const SizedBox(height: 24),
                    FilledButton(
                        onPressed:
                            _busy || !SaasService.configured ? null : _submit,
                        style: FilledButton.styleFrom(
                            backgroundColor: _ink,
                            foregroundColor: _background,
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
                                const Text('G',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700)),
                              const SizedBox(width: 12),
                              Flexible(
                                  child: Text(
                                      _busy
                                          ? 'Connecting...'
                                          : 'Continue with Google',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600))),
                              const SizedBox(width: 12),
                              const Icon(Icons.arrow_forward, size: 17),
                            ])),
                    if (_message != null || !SaasService.configured) ...[
                      const SizedBox(height: 16),
                      Semantics(
                          liveRegion: true,
                          child: Text(
                              _message ??
                                  'Sign-in is currently unavailable. Please try again later.',
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
                          Icon(Icons.lock_outline, size: 16, color: _secondary),
                          SizedBox(width: 10),
                          Expanded(
                              child: Text(
                                  'Allow Sheets and Drive access when Google asks. Your accommodation records stay in your Google account.',
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
}
