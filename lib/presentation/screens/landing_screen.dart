import 'package:flutter/material.dart';
import '../../data/services/saas_service.dart';
import 'saas_auth_screen.dart';

const _ink = Color(0xff122c2a);
const _paper = Color(0xfff7f6f0);
const _accent = Color(0xffd5ed9e);

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});
  void _open(BuildContext context, {bool register = true}) {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SaasAuthScreen(register: register)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _paper,
        body: SelectionArea(
            child: SingleChildScrollView(
                child: Center(
                    child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 24,
                          runSpacing: 16,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bed_rounded,
                                      size: 32, color: _ink),
                                  SizedBox(width: 10),
                                  Text('bedspace',
                                      style: TextStyle(
                                          fontSize: 25,
                                          fontWeight: FontWeight.w800,
                                          color: _ink)),
                                ]),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              TextButton(
                                  onPressed: () =>
                                      _open(context, register: false),
                                  child: const Text('Sign in')),
                              const SizedBox(width: 12),
                              FilledButton(
                                  style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xff122c2a),
                                      foregroundColor: Colors.white),
                                  onPressed: () => _open(context),
                                  child: const Text('Get started')),
                            ]),
                          ]),
                    ),
                    const Divider(color: Color(0xffd9ddd4)),
                    LayoutBuilder(builder: (context, constraints) {
                      final wide = constraints.maxWidth > 850;
                      final copy = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _Tag('BUILT FOR SHARED ACCOMMODATION'),
                            const SizedBox(height: 26),
                            Text('Every bed.\nEvery payment.\nOne clear view.',
                                style: TextStyle(
                                    fontSize: wide ? 64 : 43,
                                    height: 1.06,
                                    letterSpacing: -2.2,
                                    color: _ink,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 24),
                            const Text(
                                'Bring your buildings, tenants and rent together.\nKeep your business records in your own Google Sheets and Drive.',
                                style: TextStyle(
                                    fontSize: 18,
                                    height: 1.65,
                                    color: Color(0xff52635c))),
                            const SizedBox(height: 30),
                            Wrap(
                                spacing: 16,
                                runSpacing: 14,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xff122c2a),
                                          foregroundColor: Colors.white),
                                      onPressed: () => _open(context),
                                      icon: const Icon(Icons.arrow_forward,
                                          size: 18),
                                      label: const Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 15),
                                          child: Text('Create your account'))),
                                  const Text(
                                      'Your workspace. Your Google account.',
                                      style:
                                          TextStyle(fontSize: 13, color: _ink)),
                                ]),
                          ]);
                      return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 54),
                          child: wide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                      Expanded(flex: 6, child: copy),
                                      const SizedBox(width: 40),
                                      const Expanded(flex: 5, child: _Preview())
                                    ])
                              : Column(children: [
                                  copy,
                                  const SizedBox(height: 36),
                                  const _Preview()
                                ]));
                    }),
                    Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(26),
                        decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(18)),
                        child:
                            const Wrap(spacing: 40, runSpacing: 16, children: [
                          _Point(Icons.grid_view_rounded,
                              'Buildings, rooms & beds'),
                          _Point(Icons.receipt_long_outlined,
                              'Rent & expense tracking'),
                          _Point(Icons.cloud_outlined,
                              'Customer-owned Google storage'),
                        ])),
                    const SizedBox(height: 80),
                    const _Tag('LESS ADMIN. MORE CLARITY.'),
                    const SizedBox(height: 18),
                    const Text('A better rhythm for your rentals.',
                        style: TextStyle(
                            fontSize: 36,
                            letterSpacing: -1,
                            color: _ink,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 30),
                    LayoutBuilder(builder: (context, constraints) {
                      final width = constraints.maxWidth > 800
                          ? (constraints.maxWidth - 40) / 3
                          : constraints.maxWidth;
                      return Wrap(spacing: 20, runSpacing: 20, children: [
                        _Feature(
                            width,
                            '01',
                            'Know what’s available',
                            'Organize buildings and rooms. See occupied and vacant beds before placing your next tenant.',
                            Icons.bed_outlined),
                        _Feature(
                            width,
                            '02',
                            'Keep rent in focus',
                            'Track payments, balances and expenses in the same workspace as your tenants.',
                            Icons.payments_outlined),
                        _Feature(
                            width,
                            '03',
                            'Keep your records close',
                            'Connect your Google account for accommodation records in Sheets and a dedicated Drive folder.',
                            Icons.folder_outlined),
                      ]);
                    }),
                    const SizedBox(height: 80),
                    Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                            color: _ink,
                            borderRadius: BorderRadius.circular(24)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                  'The software is ours.\nThe business data is yours.',
                                  style: TextStyle(
                                      fontSize: 34,
                                      height: 1.2,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 20),
                              const Text(
                                  'Supabase manages your account and business profile. Your connected Google account holds your accommodation spreadsheet and document folder. No automatic sharing with the developer.',
                                  style: TextStyle(
                                      color: Color(0xffd7e3de),
                                      fontSize: 17,
                                      height: 1.7)),
                              const SizedBox(height: 28),
                              const Wrap(
                                  spacing: 28,
                                  runSpacing: 20,
                                  children: [
                                    _Step('1', 'Register',
                                        'Create your business account.'),
                                    _Step('2', 'Connect Google',
                                        'Authorize your own Sheets and Drive.'),
                                    _Step('3', 'Start managing',
                                        'Set up buildings, beds and tenants.'),
                                  ]),
                            ])),
                    const SizedBox(height: 72),
                    const Text('A few things to know',
                        style: TextStyle(
                            fontSize: 30,
                            color: _ink,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    const ExpansionTile(
                        title: Text('Where does my data live?'),
                        children: [
                          Padding(
                              padding: EdgeInsets.all(18),
                              child: Text(
                                  'Your identity and business profile are stored in Supabase. Accommodation records are stored in your connected Google Sheet. Your Drive folder is reserved for business documents. Temporary workspace copies are cached on your device.'))
                        ]),
                    const ExpansionTile(
                        title: Text('Do I need a Google account?'),
                        children: [
                          Padding(
                              padding: EdgeInsets.all(18),
                              child: Text(
                                  'Yes. Create your Bedspace account with email, then connect the Google account that will own your spreadsheet and Drive folder.'))
                        ]),
                    const ExpansionTile(
                        title: Text('Can I install it on my phone?'),
                        children: [
                          Padding(
                              padding: EdgeInsets.all(18),
                              child: Text(
                                  'Yes. Bedspace is a progressive web app. Use Install app in Chrome or Add to Home Screen in Safari. Google authorization and synchronization need an internet connection.'))
                        ]),
                    const SizedBox(height: 56),
                    Center(
                        child: Column(children: [
                      const Text('Make room for simpler management.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 32,
                              color: _ink,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 24),
                      FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xff122c2a),
                              foregroundColor: Colors.white),
                          onPressed: () => _open(context),
                          child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('Get started with Bedspace'))),
                      if (!SaasService.configured)
                        const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text(
                                'Account registration opens when the service is configured.',
                                textAlign: TextAlign.center)),
                    ])),
                    const SizedBox(height: 64),
                    const Divider(),
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                            'BEDSPACE  /  Shared accommodation, thoughtfully managed.',
                            style: TextStyle(color: Color(0xff52635c)))),
                  ])),
        )))),
      );
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: Color(0xff647445),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8));
}

class _Point extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Point(this.icon, this.text);
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: _ink),
        const SizedBox(width: 10),
        Flexible(
            child: Text(text,
                style:
                    const TextStyle(color: _ink, fontWeight: FontWeight.w600)))
      ]);
}

class _Feature extends StatelessWidget {
  final double width;
  final String number, title, body;
  final IconData icon;
  const _Feature(this.width, this.number, this.title, this.body, this.icon);
  @override
  Widget build(BuildContext context) => Container(
      width: width,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffe1e4db))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(icon, color: _ink, size: 30),
          Text(number, style: const TextStyle(color: Color(0xff84917a)))
        ]),
        const SizedBox(height: 30),
        Text(title,
            style: const TextStyle(
                fontSize: 22, color: _ink, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Text(body,
            style: const TextStyle(height: 1.7, color: Color(0xff52635c))),
      ]));
}

class _Step extends StatelessWidget {
  final String n, title, body;
  const _Step(this.n, this.title, this.body);
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 260,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$n / $title',
            style: const TextStyle(
                color: _accent, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(body, style: const TextStyle(color: Colors.white70, height: 1.5)),
      ]));
}

class _Preview extends StatelessWidget {
  const _Preview();
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: const Color(0xffe7ebdf),
          borderRadius: BorderRadius.circular(28)),
      child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.dashboard_outlined, color: _ink),
              SizedBox(width: 8),
              Expanded(
                  child: Text('Workspace overview',
                      style: TextStyle(fontWeight: FontWeight.w700))),
              Text('DEMO',
                  style: TextStyle(fontSize: 10, color: Color(0xff647445)))
            ]),
            const SizedBox(height: 28),
            const Text('A good day to be in control.',
                style: TextStyle(
                    fontSize: 23, fontWeight: FontWeight.w700, color: _ink)),
            const SizedBox(height: 24),
            const Row(children: [
              Expanded(child: _Metric('Total beds', '48')),
              SizedBox(width: 12),
              Expanded(child: _Metric('Occupied', '42'))
            ]),
            const SizedBox(height: 24),
            const Text('Room availability',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            for (final row in [
              ('Room 101', 'Full', 1.0),
              ('Room 102', '2 available', 0.5),
              ('Room 103', '1 available', 0.75)
            ])
              Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: Text(row.$1)),
                          Flexible(
                              child: Text(row.$2,
                                  style: const TextStyle(
                                      fontSize: 12, color: Color(0xff647445))))
                        ]),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                        value: row.$3,
                        minHeight: 7,
                        color: _ink,
                        backgroundColor: _accent,
                        borderRadius: BorderRadius.circular(5)),
                  ])),
            const Divider(),
            const SizedBox(height: 8),
            const _Point(
                Icons.check_circle_outline, 'Connected to your Google Sheets'),
          ])));
}

class _Metric extends StatelessWidget {
  final String label, value;
  const _Metric(this.label, this.value);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration:
          BoxDecoration(color: _paper, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                fontSize: 32, fontWeight: FontWeight.w700, color: _ink))
      ]));
}
