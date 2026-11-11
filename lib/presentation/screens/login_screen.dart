import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/saas_service.dart';
import '../../data/services/business_profile_service.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/sheet/sheet_bloc.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _business = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;
  String? _error;
  static const _ink = Color(0xfff5f5f5);
  static const _muted = Color(0xffa6afad);

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    if (SaasService.userId == null) return;
    try {
      final row = await BusinessProfileService(SaasService.client).load();
      if (!mounted || _busy) return;
      if (_business.text.isEmpty) {
        _business.text = row['business_name'] as String? ?? '';
      }
      if (_phone.text.isEmpty) {
        _phone.text = row['phone_number'] as String? ?? '';
      }
    } catch (_) {
      // The user can enter details manually if restoring them fails.
    }
  }

  @override
  void dispose() {
    _business.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _create(AuthAuthenticatedWithoutSheet auth) async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (SaasService.userId != null) {
        await BusinessProfileService(SaasService.client).save(
          businessName: _business.text,
          phoneNumber: _phone.text,
        );
      }
      if (!mounted) return;
      context.read<SheetBloc>().add(SheetCreateRequested(
          accessToken: auth.accessToken, userEmail: auth.userEmail));
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = BusinessProfileService.errorMessage(error);
        });
      }
    }
  }

  TextStyle _heading(double size) => TextStyle(
      fontFamily: 'HedvigLetters',
      fontSize: size,
      color: _ink,
      height: 1.12,
      letterSpacing: -.8);

  @override
  Widget build(BuildContext context) => BlocListener<SheetBloc, SheetState>(
        listener: (context, state) {
          if (state is SheetCreated) {
            context.read<AuthBloc>().add(const AuthCheckRequested());
          } else if (state is SheetError) {
            setState(() {
              _busy = false;
              _error = state.message;
            });
          }
        },
        child: BlocBuilder<AuthBloc, AuthState>(builder: (context, auth) {
          final loading = _busy || auth is AuthLoading || auth is AuthInitial;
          return Theme(
              data: ThemeData(
                  useMaterial3: true,
                  brightness: Brightness.dark,
                  fontFamily: 'Inter',
                  scaffoldBackgroundColor: const Color(0xff080a0a),
                  colorScheme: const ColorScheme.dark(
                      primary: _ink,
                      onPrimary: Color(0xff080a0a),
                      surface: Color(0xff111414),
                      onSurface: _ink)),
              child: Scaffold(
                  body: SafeArea(child: LayoutBuilder(builder: (context, size) {
                return SingleChildScrollView(
                    child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: size.maxHeight),
                        child: Padding(
                            padding:
                                EdgeInsets.all(size.maxWidth >= 960 ? 48 : 24),
                            child: Center(
                                child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 1120),
                                    child: Row(children: [
                                      if (size.maxWidth >= 960) ...[
                                        Expanded(
                                            child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(24),
                                                child: SizedBox(
                                                    height: 600,
                                                    child: Stack(
                                                        fit: StackFit.expand,
                                                        children: [
                                                          Image.asset(
                                                              'assets/landing/landscape.jpg',
                                                              fit:
                                                                  BoxFit.cover),
                                                          const DecoratedBox(
                                                              decoration: BoxDecoration(
                                                                  gradient: LinearGradient(
                                                                      begin: Alignment
                                                                          .topCenter,
                                                                      end: Alignment.bottomCenter,
                                                                      colors: [
                                                                Color(
                                                                    0x15080a0a),
                                                                Color(
                                                                    0xf5080a0a)
                                                              ]))),
                                                          Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(36),
                                                              child: Align(
                                                                  alignment:
                                                                      Alignment
                                                                          .bottomLeft,
                                                                  child: Text(
                                                                      'A little more room\nto grow.',
                                                                      style: _heading(
                                                                          52)))),
                                                        ])))),
                                        const SizedBox(width: 64),
                                      ],
                                      Expanded(
                                          child: AnimatedSwitcher(
                                              duration: const Duration(
                                                  milliseconds: 350),
                                              child: loading
                                                  ? _loading()
                                                  : _details(auth))),
                                    ]))))));
              }))));
        }),
      );

  Widget _loading() => Column(
          key: const ValueKey('loading'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _ink,
                    backgroundColor: Color(0xff293230))),
            const SizedBox(height: 32),
            Text(
                _busy
                    ? 'Making room\nfor your business.'
                    : 'Connecting your\nworkspace.',
                style: _heading(42)),
            const SizedBox(height: 20),
            Semantics(
                liveRegion: true,
                child: Text(
                    _busy
                        ? 'Preparing your spreadsheet and document folder. Your workspace will open automatically when it is ready.'
                        : 'Checking your Google connection. Just a moment.',
                    style: const TextStyle(color: _muted, height: 1.8))),
            const SizedBox(height: 32),
            const LinearProgressIndicator(
                color: _ink, backgroundColor: Color(0xff293230), minHeight: 2),
          ]);

  Widget _details(AuthState auth) => Column(
          key: const ValueKey('details'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Image.asset('assets/logo.png', width: 32, height: 36),
              const SizedBox(width: 10),
              Text('Bedspace', style: _heading(27))
            ]),
            const SizedBox(height: 40),
            const Text('YOUR WORKSPACE AWAITS',
                style: TextStyle(
                    fontFamily: 'GeistMono',
                    color: _muted,
                    fontSize: 10,
                    letterSpacing: 1.3)),
            const SizedBox(height: 16),
            Text(
                auth is AuthAuthenticatedWithoutSheet
                    ? 'Make it\nyour own.'
                    : 'Connect your\nGoogle workspace.',
                style: _heading(44)),
            const SizedBox(height: 18),
            Text(
                auth is AuthAuthenticatedWithoutSheet
                    ? 'Tell us about your business before we prepare your workspace.'
                    : 'Connect Google to keep your accommodation records in your own Sheets and Drive.',
                style: const TextStyle(color: _muted, height: 1.8)),
            const SizedBox(height: 28),
            Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: const Color(0xff111414),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x20ffffff))),
                child: auth is AuthAuthenticatedWithoutSheet
                    ? _fields(auth)
                    : FilledButton.icon(
                        onPressed: () => context
                            .read<AuthBloc>()
                            .add(const AuthSignInRequested()),
                        icon: Image.asset('assets/auth/google_g.png',
                            width: 20, height: 20),
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                            shape: const StadiumBorder()),
                        label: const Text('Connect Google Sheets & Drive'))),
            if (_error != null || auth is AuthError) ...[
              const SizedBox(height: 16),
              Semantics(
                  liveRegion: true,
                  child: Text(_error ?? (auth as AuthError).message,
                      style: const TextStyle(
                          color: Color(0xffffc4b5), height: 1.6))),
            ],
            const SizedBox(height: 24),
            const Text('Shared spaces, thoughtfully managed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 11)),
          ]);

  Widget _fields(AuthAuthenticatedWithoutSheet auth) => Form(
      key: _form,
      child: AutofillGroup(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(auth.userEmail,
            style: const TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 24),
        TextFormField(
            controller: _business,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.organizationName],
            textInputAction: TextInputAction.next,
            decoration: _decoration('Business name', 'e.g. Palm Living'),
            validator: (value) => (value?.trim().length ?? 0) < 2
                ? 'Enter your business name'
                : null),
        const SizedBox(height: 18),
        TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            textInputAction: TextInputAction.done,
            decoration: _decoration('Phone number', 'e.g. +971 50 123 4567'),
            validator: (value) {
              final phone = value?.trim() ?? '';
              final digits = phone.replaceAll(RegExp(r'\D'), '');
              return RegExp(r'^\+?[0-9 ()-]+$').hasMatch(phone) &&
                      digits.length >= 7 &&
                      digits.length <= 15
                  ? null
                  : 'Enter a valid phone number with country code';
            },
            onFieldSubmitted: (_) => _create(auth)),
        const SizedBox(height: 24),
        FilledButton(
            onPressed: () => _create(auth),
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: const StadiumBorder()),
            child: const Text('Create my workspace')),
      ])));

  InputDecoration _decoration(String label, String hint) => InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xff080a0a),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18));
}
