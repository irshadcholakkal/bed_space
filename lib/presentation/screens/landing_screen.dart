import 'package:flutter/material.dart';
import 'saas_auth_screen.dart';

const _ink = Color(0xff172222);
const _muted = Color(0xff687373);
const _line = Color(0xffe0e5e3);

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _features = GlobalKey(), _pricing = GlobalKey(), _faq = GlobalKey();
  bool _annual = false;
  void _scroll(GlobalKey key) => Scrollable.ensureVisible(key.currentContext!,
      duration: const Duration(milliseconds: 550), curve: Curves.easeInOut);
  void _open({bool register = true}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => SaasAuthScreen(
              register: register,
              billingCycle: _annual ? 'annual' : 'monthly')));
  @override
  Widget build(BuildContext context) => Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context)
            .textTheme
            .apply(fontFamily: 'Inter', bodyColor: _ink, displayColor: _ink),
        colorScheme: ColorScheme.fromSeed(seedColor: _ink, primary: _ink),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
                backgroundColor: _ink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 19))),
      ),
      child: Scaffold(
          backgroundColor: Colors.white,
          body: SelectionArea(
              child: SingleChildScrollView(
                  child: Column(children: [
            _Landscape(
                child: _Width(
                    child: Column(children: [
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: LayoutBuilder(
                      builder: (context, c) => Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              runSpacing: 14,
                              spacing: 24,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const _Brand(light: true),
                                Wrap(
                                    spacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      if (c.maxWidth > 650)
                                        _nav('Features',
                                            () => _scroll(_features)),
                                      _nav('Pricing', () => _scroll(_pricing)),
                                      if (c.maxWidth > 650)
                                        _nav('FAQs', () => _scroll(_faq)),
                                      _nav('Sign in',
                                          () => _open(register: false)),
                                      const SizedBox(width: 12),
                                      FilledButton(
                                          style: FilledButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor: _ink,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 18,
                                                      vertical: 15)),
                                          onPressed: _open,
                                          child: const Text('Try free')),
                                    ]),
                              ]))),
              const SizedBox(height: 92),
              const _Eyebrow('A LITTLE MORE SPACE. A LOT LESS ADMIN.',
                  light: true),
              const SizedBox(height: 24),
              LayoutBuilder(
                  builder: (context, c) => Text(
                      'A calmer way to manage\nyour shared spaces.',
                      textAlign: TextAlign.center,
                      style: _serif(c.maxWidth > 700 ? 76 : 43, light: true))),
              const SizedBox(height: 24),
              const SizedBox(
                  width: 610,
                  child: Text(
                      'Buildings, beds, tenants and rent. Beautifully in sync, with business records that stay in your own Google Sheets and Drive.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Color(0xffe1e8e6),
                          fontSize: 17,
                          height: 1.8))),
              const SizedBox(height: 30),
              FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.white, foregroundColor: _ink),
                  onPressed: _open,
                  icon: const Icon(Icons.arrow_forward, size: 17),
                  label: const Text('Start your 1-month free trial')),
              const SizedBox(height: 14),
              const Text('Then AED 50/month + other charges.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xffd0d9d7), fontSize: 12)),
              const SizedBox(height: 72),
              const _DashboardPreview(),
              const SizedBox(height: 48),
            ]))),
            _Width(
                child: Column(children: [
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 42,
                      runSpacing: 20,
                      children: [
                        _Integration(
                            Icons.table_chart_outlined, 'Google Sheets'),
                        _Integration(Icons.folder_outlined, 'Google Drive'),
                        _Integration(
                            Icons.verified_user_outlined, 'Supabase accounts'),
                        _Integration(
                            Icons.install_mobile_outlined, 'Installable PWA'),
                      ])),
              const Divider(color: _line),
              SizedBox(key: _features, height: 90),
              const _Eyebrow('ROOM TO FOCUS ON WHAT MATTERS'),
              const SizedBox(height: 20),
              Text('Everything in its place.',
                  textAlign: TextAlign.center, style: _serif(46)),
              const SizedBox(height: 18),
              const SizedBox(
                  width: 590,
                  child: Text(
                      'From the next available bed to the next rent payment. Bring the daily details together in one thoughtful workspace.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: _muted, height: 1.8, fontSize: 16))),
              const SizedBox(height: 44),
              LayoutBuilder(builder: (context, c) {
                final width =
                    c.maxWidth > 800 ? (c.maxWidth - 40) / 3 : c.maxWidth;
                return Wrap(spacing: 20, runSpacing: 28, children: [
                  _Feature(
                      width: width,
                      icon: Icons.bed_outlined,
                      title: 'A home for every detail',
                      body:
                          'Organize buildings, rooms and beds. Keep vacancy and tenant information close, without the scattered spreadsheets.',
                      tint: const Color(0xffedf2ee),
                      lines: const [
                        'Buildings & rooms',
                        'Occupied & available',
                        'Tenant details'
                      ]),
                  _Feature(
                      width: width,
                      icon: Icons.receipt_long_outlined,
                      title: 'Rent, without the guesswork',
                      body:
                          'See payments, balances and expenses. Prepare invoices and receipts, then save a copy to your own Drive.',
                      tint: const Color(0xffeef0f5),
                      lines: const [
                        'Rent payments',
                        'Invoices & receipts',
                        'Monthly expenses'
                      ]),
                  _Feature(
                      width: width,
                      icon: Icons.cloud_outlined,
                      title: 'Your data. Your Google.',
                      body:
                          'Your account lives in Supabase. Your accommodation records and documents live in your connected Google account.',
                      tint: const Color(0xfff4f0e9),
                      lines: const [
                        'Customer-owned Sheets',
                        'Private Drive folder',
                        'No automatic sharing'
                      ]),
                ]);
              }),
              const SizedBox(height: 100),
              Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                      color: const Color(0xfff5f6f3),
                      borderRadius: BorderRadius.circular(16)),
                  child: Column(children: [
                    const _Eyebrow('A SIMPLE START'),
                    const SizedBox(height: 16),
                    Text('Your workspace, in three steps.',
                        textAlign: TextAlign.center, style: _serif(36)),
                    const SizedBox(height: 30),
                    const Wrap(
                        spacing: 32,
                        runSpacing: 28,
                        alignment: WrapAlignment.center,
                        children: [
                          _Step('01', 'Create your account',
                              'Register your business and start your one-month trial.'),
                          _Step('02', 'Connect your Google',
                              'Set up your own spreadsheet and private document folder.'),
                          _Step('03', 'Make yourself at home',
                              'Add buildings, beds and tenants. Take control of the day.'),
                        ]),
                  ])),
              SizedBox(key: _pricing, height: 100),
              const _Eyebrow('ONE WORKSPACE. SIMPLE PRICING.'),
              const SizedBox(height: 20),
              Text('Start with a month on us.',
                  textAlign: TextAlign.center, style: _serif(46)),
              const SizedBox(height: 18),
              const Text(
                  'Get to know Bedspace. Choose the billing rhythm that suits your business.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 16, height: 1.8)),
              const SizedBox(height: 28),
              SegmentedButton<bool>(segments: const [
                ButtonSegment(value: false, label: Text('Monthly')),
                ButtonSegment(
                    value: true, label: Text('Annual \u00b7 save 10%'))
              ], selected: {
                _annual
              }, onSelectionChanged: (s) => setState(() => _annual = s.first)),
              const SizedBox(height: 32),
              ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: LayoutBuilder(builder: (context, c) {
                    final width =
                        c.maxWidth > 650 ? (c.maxWidth - 24) / 2 : c.maxWidth;
                    return Wrap(spacing: 24, runSpacing: 24, children: [
                      Container(
                          width: width,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                              border: Border.all(color: _line),
                              borderRadius: BorderRadius.circular(15)),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _Eyebrow('YOUR FIRST MONTH'),
                                const SizedBox(height: 20),
                                Text('Free to settle in.', style: _serif(32)),
                                const SizedBox(height: 20),
                                const Text('AED 0',
                                    style: TextStyle(
                                        fontSize: 48, letterSpacing: -2)),
                                const Text('for one calendar month',
                                    style: TextStyle(color: _muted)),
                                const SizedBox(height: 24),
                                const Divider(color: _line),
                                const SizedBox(height: 16),
                                for (final text in [
                                  'Full workspace access during the trial',
                                  'Connect your own Sheets and Drive',
                                  'No payment required to begin'
                                ])
                                  _Check(text),
                                const SizedBox(height: 24),
                                SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                        onPressed: _open,
                                        child: const Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 16),
                                            child: Text('Start free trial')))),
                              ])),
                      Container(
                          width: width,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                              color: _ink,
                              borderRadius: BorderRadius.circular(15)),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Eyebrow(
                                    _annual
                                        ? 'ANNUAL \u00b7 SAVE 10%'
                                        : 'MONTHLY MEMBERSHIP',
                                    light: true),
                                const SizedBox(height: 20),
                                Text('Space to keep growing.',
                                    style: _serif(32, light: true)),
                                const SizedBox(height: 20),
                                Text(_annual ? 'AED 540' : 'AED 50',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 48,
                                        letterSpacing: -2)),
                                Text(
                                    _annual
                                        ? '/year + other charges'
                                        : '/month + other charges',
                                    style:
                                        const TextStyle(color: Colors.white70)),
                                const SizedBox(height: 12),
                                Text(
                                    _annual
                                        ? 'AED 45/month equivalent. Save AED 60/year.'
                                        : 'One month of access per renewal payment.',
                                    style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        height: 1.6)),
                                const SizedBox(height: 24),
                                const Divider(color: Colors.white24),
                                const SizedBox(height: 16),
                                for (final text in [
                                  'Buildings, rooms, beds and tenants',
                                  'Rent, expenses, invoices and receipts',
                                  'Your Google Sheets and Drive storage'
                                ])
                                  _Check(text, light: true),
                                const SizedBox(height: 24),
                                SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                        style: FilledButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: _ink),
                                        onPressed: _open,
                                        child: const Text('Get started'))),
                              ])),
                    ]);
                  })),
              const SizedBox(height: 20),
              const SizedBox(
                  width: 760,
                  child: Text(
                      'Other charges are additional to the plan price and will be shown before payment. When the trial or paid period ends, workspace access is paused until payment is confirmed. Your Google files remain in your account.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: _muted, fontSize: 12, height: 1.9))),
              SizedBox(key: _faq, height: 100),
              Text('A little more clarity.',
                  textAlign: TextAlign.center, style: _serif(42)),
              const SizedBox(height: 30),
              const _Faq('How does the free trial work?',
                  'Your trial lasts one calendar month from account creation. You can set up and use your workspace without making a payment. After the trial, a confirmed subscription payment is required to continue.'),
              const _Faq('What if I miss a payment?',
                  'Your workspace is paused when your trial or paid period ends without a new payment. You can still sign in to renew. Access resumes after Paymob confirms a successful payment.'),
              const _Faq('How much is the annual plan?',
                  'The annual base price is AED 540 plus other charges, paid for the year. That is 10% less than twelve monthly base payments of AED 50: a saving of AED 60 per year.'),
              const _Faq('Where are my records stored?',
                  'Supabase holds your account and subscription details. Your accommodation records stay in your connected Google Sheet; document copies are saved to your Drive folder. Pausing your subscription does not delete those Google files.'),
              const _Faq('Can I use Bedspace on my phone?',
                  'Yes. Bedspace is an installable Flutter PWA. Use Install app in Chrome or Add to Home Screen in Safari. Account verification, payments and Google synchronization need an internet connection.'),
              const SizedBox(height: 90),
            ])),
            _Landscape(
                child: _Width(
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 90),
                        child: Column(children: [
                          Text('Make room for\na simpler day.',
                              textAlign: TextAlign.center,
                              style: _serif(56, light: true)),
                          const SizedBox(height: 24),
                          const Text(
                              'One month to find your rhythm. Your own data, every step of the way.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white70, height: 1.8)),
                          const SizedBox(height: 28),
                          FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: _ink),
                              onPressed: _open,
                              child: const Text('Try Bedspace free')),
                        ])))),
            _Width(
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Column(children: [
                      Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          runSpacing: 22,
                          spacing: 40,
                          children: [
                            const _Brand(),
                            Wrap(spacing: 22, children: [
                              TextButton(
                                  onPressed: () => _scroll(_features),
                                  child: const Text('Features')),
                              TextButton(
                                  onPressed: () => _scroll(_pricing),
                                  child: const Text('Pricing')),
                              TextButton(
                                  onPressed: () => _scroll(_faq),
                                  child: const Text('FAQs'))
                            ])
                          ]),
                      const Divider(height: 50, color: _line),
                      const Text(
                          'Bedspace by The Percentage Company. Shared spaces, thoughtfully managed.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: _muted)),
                    ]))),
          ])))));
  Widget _nav(String title, VoidCallback onPressed) => TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: Colors.white),
      child: Text(title));
}

TextStyle _serif(double size, {bool light = false}) => TextStyle(
    fontFamily: 'HedvigLetters',
    fontWeight: FontWeight.w400,
    fontSize: size,
    height: 1.12,
    letterSpacing: -1.5,
    color: light ? Colors.white : _ink);

class _Width extends StatelessWidget {
  final Widget child;
  const _Width({required this.child});
  @override
  Widget build(BuildContext context) => Center(
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1220),
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(width: double.infinity, child: child))));
}

class _Landscape extends StatelessWidget {
  final Widget child;
  const _Landscape({required this.child});
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      decoration: const BoxDecoration(
          color: Color(0xff172b30),
          image: DecorationImage(
              image: AssetImage('assets/landing/landscape.jpg'),
              fit: BoxFit.cover)),
      child: Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                Color(0x44102326),
                Color(0x55102326),
                Color(0xdd0b181b)
              ])),
          child: child));
}

class _Brand extends StatelessWidget {
  final bool light;
  const _Brand({this.light = false});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.bed_outlined, color: light ? Colors.white : _ink, size: 28),
        const SizedBox(width: 10),
        Text('bedspace',
            style: TextStyle(
                fontFamily: 'HedvigLetters',
                fontSize: 29,
                color: light ? Colors.white : _ink))
      ]);
}

class _Eyebrow extends StatelessWidget {
  final String text;
  final bool light;
  const _Eyebrow(this.text, {this.light = false});
  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: TextAlign.center,
      style: TextStyle(
          fontSize: 10,
          letterSpacing: 2,
          height: 1.5,
          fontWeight: FontWeight.w500,
          color: light ? Colors.white70 : _muted));
}

class _Integration extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Integration(this.icon, this.text);
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 20, color: _muted),
        const SizedBox(width: 9),
        Text(text, style: const TextStyle(fontSize: 13, color: _muted))
      ]);
}

class _Check extends StatelessWidget {
  final String text;
  final bool light;
  const _Check(this.text, {this.light = false});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.check, size: 16, color: light ? Colors.white70 : _muted),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    color: light ? Colors.white70 : _muted,
                    fontSize: 12,
                    height: 1.6)))
      ]));
}

class _Feature extends StatelessWidget {
  final double width;
  final IconData icon;
  final String title, body;
  final Color tint;
  final List<String> lines;
  const _Feature(
      {required this.width,
      required this.icon,
      required this.title,
      required this.body,
      required this.tint,
      required this.lines});
  @override
  Widget build(BuildContext context) => SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: double.infinity,
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
                color: tint, borderRadius: BorderRadius.circular(14)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, size: 30, color: _ink),
              const SizedBox(height: 24),
              for (final line in lines)
                Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 9),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .8),
                        borderRadius: BorderRadius.circular(6)),
                    child: Row(children: [
                      const Icon(Icons.check_circle_outline,
                          size: 14, color: _muted),
                      const SizedBox(width: 10),
                      Expanded(
                          child:
                              Text(line, style: const TextStyle(fontSize: 12)))
                    ]))
            ])),
        const SizedBox(height: 23),
        Text(title, style: _serif(27)),
        const SizedBox(height: 14),
        Text(body,
            style: const TextStyle(fontSize: 14, color: _muted, height: 1.85)),
      ]));
}

class _Step extends StatelessWidget {
  final String n, title, body;
  const _Step(this.n, this.title, this.body);
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 290,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(n, style: const TextStyle(color: _muted, fontSize: 11)),
        const SizedBox(height: 14),
        Text(title, style: _serif(25)),
        const SizedBox(height: 12),
        Text(body,
            style: const TextStyle(color: _muted, height: 1.8, fontSize: 13))
      ]));
}

class _Faq extends StatelessWidget {
  final String title, body;
  const _Faq(this.title, this.body);
  @override
  Widget build(BuildContext context) => ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          title: Text(title, style: const TextStyle(fontSize: 15)),
          children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 30, 24),
                child: Text(body,
                    style: const TextStyle(
                        color: _muted, height: 1.9, fontSize: 14)))
          ]));
}

class _DashboardPreview extends StatelessWidget {
  const _DashboardPreview();
  @override
  Widget build(BuildContext context) => ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 920),
      child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.white24)),
          child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: const Color(0xfffbfcfa),
                  borderRadius: BorderRadius.circular(10)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.dashboard_outlined, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text('Your workspace',
                              style: TextStyle(fontSize: 12))),
                      Text('ILLUSTRATIVE DEMO',
                          style: TextStyle(
                              fontSize: 8, letterSpacing: 1, color: _muted))
                    ]),
                    const Divider(height: 30, color: _line),
                    Text('A clear view of the day.', style: _serif(30)),
                    const SizedBox(height: 22),
                    LayoutBuilder(
                        builder: (context, c) =>
                            Wrap(spacing: 14, runSpacing: 14, children: [
                              for (final item in [
                                ('Total beds', '48'),
                                ('Occupied', '42'),
                                ('Available', '6')
                              ])
                                Container(
                                    width: c.maxWidth > 500
                                        ? (c.maxWidth - 28) / 3
                                        : c.maxWidth,
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                        color: const Color(0xffeff3ef),
                                        borderRadius: BorderRadius.circular(7)),
                                    child: Row(children: [
                                      Expanded(
                                          child: Text(item.$1,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: _muted))),
                                      Text(item.$2, style: _serif(28))
                                    ]))
                            ])),
                    const SizedBox(height: 22),
                    const Text('Room availability',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    for (final room in [
                      ('Room 101', 1.0),
                      ('Room 102', .5),
                      ('Room 103', .75)
                    ])
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(children: [
                            SizedBox(
                                width: 80,
                                child: Text(room.$1,
                                    style: const TextStyle(
                                        fontSize: 11, color: _muted))),
                            Expanded(
                                child: LinearProgressIndicator(
                                    value: room.$2,
                                    minHeight: 5,
                                    color: const Color(0xff718f80),
                                    backgroundColor: const Color(0xffe4eae6),
                                    borderRadius: BorderRadius.circular(3)))
                          ])),
                  ]))));
}
