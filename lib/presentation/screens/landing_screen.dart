import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../widgets/landing_motion.dart';
import 'saas_auth_screen.dart';
part '../widgets/landing_components.dart';

const _bg = Color(0xff080a0a),
    _panel = Color(0xff111414),
    _white = Color(0xfff5f5f5),
    _muted = Color(0xff858b8b),
    _border = Color(0x20ffffff);
const _headline = 'Shared space management for modern teams';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _scroll = ScrollController();
  final _features = GlobalKey(), _pricing = GlobalKey(), _guides = GlobalKey();
  bool _annual = false;
  int _workflow = 0, _role = 0;
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _jump(GlobalKey key) => Scrollable.ensureVisible(key.currentContext!,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
      alignment: .10);
  void _open({bool register = true, bool? annual}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => SaasAuthScreen(
              register: register,
              billingCycle: (annual ?? _annual) ? 'annual' : 'monthly')));
  Widget _reveal(Widget child, {int delay = 0}) =>
      LandingReveal(scroll: _scroll, delay: delay, child: child);
  @override
  Widget build(BuildContext context) => Theme(
      data: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: _bg,
          fontFamily: 'Inter',
          colorScheme: const ColorScheme.dark(
              primary: _white,
              onPrimary: Color(0xff262626),
              surface: _panel,
              onSurface: _white,
              outline: _border),
          dividerColor: _border,
          textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: _white)),
          filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                  backgroundColor: _white,
                  foregroundColor: const Color(0xff262626),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  shape: const StadiumBorder())),
          outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                  foregroundColor: _white,
                  side: const BorderSide(color: _border),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 18)))),
      child: Scaffold(
          body: Stack(children: [
        SelectionArea(
            child: SingleChildScrollView(
                key: const Key('landing-scroll'),
                controller: _scroll,
                child: Column(children: [
                  _hero(),
                  _section(
                      key: _features,
                      child: Column(children: [
                        _reveal(_heading('A clearer view of every space',
                            'Bring the daily details together, from available beds to the latest rent payment.')),
                        const SizedBox(height: 64),
                        for (var i = 0; i < _featureData.length; i++)
                          Padding(
                              padding: EdgeInsets.only(bottom: i == 2 ? 0 : 64),
                              child: _reveal(_featureRow(i))),
                      ])),
                  _section(
                      child: _reveal(Column(children: [
                    _heading('Built around your working day',
                        'Explore everyday workflows. These are illustrative examples, ready to make your own.'),
                    const SizedBox(height: 40),
                    _workflowCards(),
                    const SizedBox(height: 24),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      IconButton.outlined(
                          tooltip: 'Previous workflow',
                          onPressed: () =>
                              setState(() => _workflow = (_workflow + 1) % 2),
                          icon: const Icon(Icons.arrow_back, size: 17)),
                      const SizedBox(width: 18),
                      for (var i = 0; i < 2; i++)
                        AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: _workflow == i ? 26 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                                color: _workflow == i
                                    ? _white
                                    : const Color(0xff414747),
                                borderRadius: BorderRadius.circular(8))),
                      const SizedBox(width: 18),
                      IconButton.outlined(
                          tooltip: 'Next workflow',
                          onPressed: () =>
                              setState(() => _workflow = (_workflow + 1) % 2),
                          icon: const Icon(Icons.arrow_forward, size: 17)),
                    ]),
                  ]))),
                  _section(
                      key: _pricing,
                      child: Stack(children: [
                        Positioned.fill(
                            child: IgnorePointer(
                                child: AnimatedBuilder(
                                    animation: _scroll,
                                    builder: (context, _) => CustomPaint(
                                        painter: _GlowPainter(
                                            MediaQuery.disableAnimationsOf(
                                                    context)
                                                ? 0
                                                : (_scroll.hasClients
                                                    ? _scroll.offset / 500
                                                    : 0)))))),
                        _reveal(Column(children: [
                          _heading('A simple plan for your spaces',
                              'One month to get comfortable. Then choose monthly or annual membership.'),
                          const SizedBox(height: 28),
                          SegmentedButton<bool>(
                              showSelectedIcon: false,
                              style: SegmentedButton.styleFrom(
                                  selectedBackgroundColor:
                                      const Color(0xff292f30),
                                  selectedForegroundColor: _white,
                                  side: const BorderSide(color: _border)),
                              segments: const [
                                ButtonSegment(
                                    value: false, label: Text('Monthly')),
                                ButtonSegment(
                                    value: true,
                                    label: Text('Annual \u00b7 save 10%'))
                              ],
                              selected: {_annual},
                              onSelectionChanged: (s) =>
                                  setState(() => _annual = s.first)),
                          const SizedBox(height: 36),
                          _pricingCards(),
                          const SizedBox(height: 58),
                          _comparison(),
                        ])),
                      ])),
                  _section(
                      child: Column(children: [
                    _reveal(LandingScrollWords(
                        scroll: _scroll,
                        text:
                            'From your first building to your next rent collection, bring your accommodation work into one place. Less switching between tools. More room to focus on the people who live there.')),
                    const SizedBox(height: 14),
                    Image.asset('assets/landing/hills.png',
                        width: double.infinity,
                        fit: BoxFit.fitWidth,
                        excludeFromSemantics: true),
                    const SizedBox(height: 48),
                    _reveal(_roleTabs()),
                  ])),
                  _section(
                      key: _guides,
                      child: _reveal(Column(children: [
                        _heading('Make yourself at home',
                            'A few useful guides to help you get started with your new workspace.'),
                        const SizedBox(height: 40),
                        _guideCards()
                      ]))),
                  _section(
                      border: false,
                      child: _reveal(Column(children: [
                        _heading('Make room for a simpler day',
                            'A thoughtful workspace for buildings, tenants and rent, with business records that stay in your Google account.'),
                        const SizedBox(height: 28),
                        Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _button('Try Bedspace free', () => _open()),
                              OutlinedButton(
                                  onPressed: () => _jump(_pricing),
                                  child: const Text('View membership'))
                            ]),
                        const SizedBox(height: 36),
                        Image.asset('assets/landing/hills.png',
                            width: double.infinity,
                            fit: BoxFit.fitWidth,
                            excludeFromSemantics: true),
                      ]))),
                  _footer(),
                ]))),
        Positioned(top: 0, left: 0, right: 0, child: _navigation()),
      ])));

  Widget _hero() => LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth > 750;
        return ConstrainedBox(
            constraints: BoxConstraints(
                minHeight: wide
                    ? math.max(760, MediaQuery.sizeOf(context).height)
                    : 790),
            child: Stack(children: [
              Positioned.fill(
                  child: ClipRect(
                      child: AnimatedBuilder(
                          animation: _scroll,
                          builder: (context, _) => Transform.translate(
                              offset: Offset(
                                  0,
                                  MediaQuery.disableAnimationsOf(context)
                                      ? 0
                                      : ((_scroll.hasClients
                                                  ? _scroll.offset
                                                  : 0) *
                                              .16)
                                          .clamp(0, 160)),
                              child: Transform.scale(
                                  scale: 1.2,
                                  child: Image.asset(
                                      'assets/landing/landscape.jpg',
                                      fit: BoxFit.cover,
                                      excludeFromSemantics: true)))))),
              const Positioned.fill(
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                    Color(0x22000000),
                    Colors.transparent,
                    _bg
                  ])))),
              _width(
                  child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          0, wide ? 240 : 185, 0, wide ? 180 : 120),
                      child: Column(children: [
                        ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 960),
                            child: LandingWordEntrance(
                                text: _headline,
                                style: _serif(wide ? 76 : 43))),
                        const SizedBox(height: 24),
                        _reveal(const SizedBox(
                            width: 620,
                            child: Text(
                                'Organize buildings, manage rent and keep your accommodation records together, in a workspace connected to your own Google account.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Color(0xffe5e7e6),
                                    fontSize: 17,
                                    height: 1.7)))),
                        const SizedBox(height: 30),
                        _reveal(
                            _button(
                                'Start your 1-month free trial', () => _open()),
                            delay: 250),
                        const SizedBox(height: 16),
                        _reveal(const Text('Then AED 50/month + other charges.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Color(0xffb5bdbb), fontSize: 12))),
                      ]))),
              if (wide) ...[
                const Positioned(
                    left: 70,
                    top: 235,
                    child: _FloatingGlyph(Icons.folder_outlined, angle: -.15)),
                const Positioned(
                    right: 90,
                    top: 210,
                    child: _FloatingGlyph(Icons.receipt_long_outlined,
                        angle: .12)),
                const Positioned(
                    left: 190,
                    bottom: 95,
                    child: _FloatingGlyph(Icons.grid_view_outlined, angle: .1)),
                const Positioned(
                    right: 180,
                    bottom: 100,
                    child:
                        _FloatingGlyph(Icons.table_chart_outlined, angle: -.12))
              ],
            ]));
      });

  Widget _navigation() => AnimatedBuilder(
      animation: _scroll,
      builder: (context, _) {
        final scrolled = _scroll.hasClients && _scroll.offset > 45;
        return ClipRect(
            child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                    sigmaX: scrolled ? 16 : 0, sigmaY: scrolled ? 16 : 0),
                child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    decoration: BoxDecoration(
                        color: scrolled
                            ? const Color(0xe6080a0a)
                            : Colors.transparent,
                        border: Border(
                            bottom: BorderSide(
                                color:
                                    scrolled ? _border : Colors.transparent))),
                    child: SafeArea(
                        bottom: false,
                        child: _width(
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: LayoutBuilder(
                                    builder: (context, c) => Row(children: [
                                          Image.asset('assets/logo.png',
                                              key: const Key('landing-logo'),
                                              width: 37,
                                              height: 40,
                                              semanticLabel: 'Bedspace logo'),
                                          const SizedBox(width: 10),
                                          if (c.maxWidth > 400)
                                            const Text('Bedspace',
                                                style: TextStyle(
                                                    fontFamily: 'HedvigLetters',
                                                    fontSize: 27,
                                                    color: _white)),
                                          const Spacer(),
                                          if (c.maxWidth > 720) ...[
                                            TextButton(
                                                onPressed: () =>
                                                    _jump(_pricing),
                                                child: const Text('Pricing')),
                                            TextButton(
                                                onPressed: () =>
                                                    _jump(_features),
                                                child: const Text('Features')),
                                            TextButton(
                                                onPressed: () => _jump(_guides),
                                                child: const Text('Guides')),
                                            const SizedBox(width: 12)
                                          ],
                                          TextButton(
                                              onPressed: () =>
                                                  _open(register: false),
                                              child: const Text('Sign in')),
                                          const SizedBox(width: 8),
                                          FilledButton(
                                              onPressed: () => _open(),
                                              child: const Text('Try free')),
                                        ]))))))));
      });

  Widget _featureRow(int index) => LayoutBuilder(builder: (context, c) {
        final data = _featureData[index];
        final visual = _ProductGraphic(kind: index);
        final text =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _tag(data.$1),
          const SizedBox(height: 20),
          Text(data.$2, style: _serif(38)),
          const SizedBox(height: 18),
          Text(data.$3,
              style: const TextStyle(color: _muted, fontSize: 15, height: 1.9)),
          const SizedBox(height: 26),
          OutlinedButton(
              onPressed: () => _jump(_pricing),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Explore membership'),
                SizedBox(width: 12),
                Icon(Icons.arrow_outward, size: 16)
              ]))
        ]);
        if (c.maxWidth < 760) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [visual, const SizedBox(height: 28), text]);
        }
        return Row(
            children: index.isEven
                ? [
                    Expanded(child: visual),
                    const SizedBox(width: 72),
                    Expanded(child: text)
                  ]
                : [
                    Expanded(child: text),
                    const SizedBox(width: 72),
                    Expanded(child: visual)
                  ]);
      });

  Widget _workflowCards() => LayoutBuilder(builder: (context, c) {
        final scenarios = _workflow == 0
            ? [
                (
                  'At the start of the day',
                  'See where there is room to grow.',
                  'Review buildings and vacancies before placing your next tenant.',
                  Icons.bed_outlined
                ),
                (
                  'When rent comes around',
                  'Keep every payment in perspective.',
                  'Bring rent, recorded payments and outstanding balances into one view.',
                  Icons.payments_outlined
                )
              ]
            : [
                (
                  'When it is time to share',
                  'A receipt, ready when you are.',
                  'Prepare an invoice or receipt and save a PDF copy to your own Drive folder.',
                  Icons.receipt_long_outlined
                ),
                (
                  'At the end of the month',
                  'Your records, still your records.',
                  'Open your accommodation spreadsheet in the Google account you connected.',
                  Icons.table_chart_outlined
                )
              ];
        return GestureDetector(
            onHorizontalDragEnd: (d) {
              if (d.primaryVelocity != 0) {
                setState(() => _workflow = (_workflow + 1) % 2);
              }
            },
            child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 400),
                child: Wrap(
                    key: ValueKey(_workflow),
                    spacing: 20,
                    runSpacing: 20,
                    children: [
                      for (var i = 0; i < scenarios.length; i++)
                        SizedBox(
                            width: c.maxWidth > 700
                                ? (c.maxWidth - 20) / 2
                                : c.maxWidth,
                            child: LandingHover(
                                child: Container(
                                    padding: const EdgeInsets.all(30),
                                    constraints:
                                        const BoxConstraints(minHeight: 300),
                                    decoration: BoxDecoration(
                                        color: _panel,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(color: _border),
                                        image: i == 0
                                            ? const DecorationImage(
                                                image: AssetImage(
                                                    'assets/landing/landscape.jpg'),
                                                fit: BoxFit.cover,
                                                colorFilter: ColorFilter.mode(
                                                    Color(0xaa080a0a),
                                                    BlendMode.darken))
                                            : null),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(scenarios[i].$4,
                                              size: 30,
                                              color: const Color(0xffb5c5c6)),
                                          const SizedBox(height: 28),
                                          Text(scenarios[i].$2,
                                              style: _serif(30)),
                                          const SizedBox(height: 16),
                                          Text(scenarios[i].$3,
                                              style: const TextStyle(
                                                  color: Color(0xffb8bebe),
                                                  height: 1.8,
                                                  fontSize: 14)),
                                          const SizedBox(height: 28),
                                          _tag(
                                              'EXAMPLE WORKFLOW / ${scenarios[i].$1}')
                                        ]))))
                    ])));
      });

  Widget _pricingCards() => LayoutBuilder(builder: (context, c) {
        final width = c.maxWidth > 900 ? (c.maxWidth - 32) / 3 : c.maxWidth;
        return Wrap(spacing: 16, runSpacing: 20, children: [
          _PlanCard(
              width: width,
              title: 'Settle in',
              price: 'AED 0',
              period: 'for your first month',
              description: 'Get to know your new workspace.',
              features: const [
                'One calendar month free',
                'Buildings, rooms, beds and tenants',
                'Rent and expense tracking',
                'Connect your Google account',
                'Invoice and receipt PDFs'
              ],
              button: 'Start free trial',
              onPressed: () => _open()),
          _PlanCard(
              width: width,
              title: 'Monthly',
              price: 'AED 50',
              period: '/month + other charges',
              description: 'A little flexibility for your business.',
              features: const [
                'Full workspace after your trial',
                'Customer-owned Google Sheets',
                'Private Google Drive folder',
                'Invoices and receipts',
                'Renew with a confirmed payment'
              ],
              button: 'Choose monthly',
              highlighted: !_annual,
              onPressed: () => _open(annual: false)),
          _PlanCard(
              width: width,
              title: 'Annual',
              price: 'AED 540',
              period: '/year + other charges',
              description: 'AED 45/month equivalent. Save AED 60/year.',
              features: const [
                'Everything in monthly',
                '10% off the annual base price',
                'One calendar year of paid access',
                'Your existing Google storage',
                'The same complete workspace'
              ],
              button: 'Choose annual',
              highlighted: _annual,
              onPressed: () => _open(annual: true)),
        ]);
      });

  Widget _comparison() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your membership at a glance', style: _serif(28)),
        const SizedBox(height: 24),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
                width: math.max(
                    780, math.min(MediaQuery.sizeOf(context).width, 1200) - 56),
                child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1.7),
                      1: FlexColumnWidth(),
                      2: FlexColumnWidth(),
                      3: FlexColumnWidth()
                    },
                    border: const TableBorder(
                        horizontalInside: BorderSide(color: _border)),
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      _tableRow(['Features', 'Trial', 'Monthly', 'Annual'],
                          header: true),
                      _tableRow(
                          ['Access period', '1 month', '1 month', '1 year']),
                      for (final text in [
                        'Buildings and rooms',
                        'Beds and tenants',
                        'Rent and expenses',
                        'Google Sheets and Drive',
                        'Invoice and receipt PDFs'
                      ])
                        _tableRow([text, 'check', 'check', 'check']),
                      _tableRow(['Base price', 'Free', 'AED 50', 'AED 540']),
                    ]))),
        const SizedBox(height: 20),
        const Text(
            'Other charges are additional and shown before payment. Workspace access pauses when the trial or paid period ends without renewal. Your Google files remain yours.',
            style: TextStyle(color: _muted, fontSize: 12, height: 1.9))
      ]);
  TableRow _tableRow(List<String> values, {bool header = false}) =>
      TableRow(children: [
        for (final value in values)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
              child: value == 'check'
                  ? const Icon(Icons.check, size: 17, color: Color(0xffb6c6bf))
                  : Text(value,
                      style: TextStyle(
                          color: header ? _white : _muted,
                          fontSize: 13,
                          fontWeight:
                              header ? FontWeight.w600 : FontWeight.w400)))
      ]);

  Widget _roleTabs() => Column(children: [
        Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < 4; i++)
                OutlinedButton(
                    key: ValueKey('role-$i'),
                    style: OutlinedButton.styleFrom(
                        backgroundColor: _role == i
                            ? const Color(0xff222828)
                            : Colors.transparent,
                        side: BorderSide(
                            color: _role == i
                                ? const Color(0xff586464)
                                : _border)),
                    onPressed: () => setState(() => _role = i),
                    child: Text([
                      'Owners',
                      'Managers',
                      'Rent collection',
                      'Documents'
                    ][i]))
            ]),
        const SizedBox(height: 36),
        AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 350),
            child: _ProductGraphic(
                key: ValueKey('role-visual-$_role'),
                kind: _role % 3,
                expanded: true)),
        const SizedBox(height: 30),
        AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
                [
                  'A clear overview of the buildings, rooms and beds in your business.',
                  'Keep tenant details and available spaces together while you manage the day.',
                  'See recorded rent, payments and balances in the same workspace.',
                  'Create invoices and receipts, with copies saved in your Google Drive.'
                ][_role],
                key: ValueKey(_role),
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, height: 1.9)))
      ]);

  Widget _guideCards() => LayoutBuilder(
      builder: (context, c) => Wrap(spacing: 20, runSpacing: 24, children: [
            for (var i = 0; i < 3; i++)
              SizedBox(
                  width: c.maxWidth > 850 ? (c.maxWidth - 40) / 3 : c.maxWidth,
                  child: LandingHover(
                      child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _guide(i),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                    height: 190,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: _border),
                                        gradient: LinearGradient(colors: [
                                          const Color(0xff233239),
                                          [
                                            const Color(0xff201f18),
                                            const Color(0xff162c25),
                                            const Color(0xff28202f)
                                          ][i]
                                        ])),
                                    child: Center(
                                        child: Icon(
                                            [
                                              Icons.rocket_launch_outlined,
                                              Icons.table_chart_outlined,
                                              Icons.credit_card_outlined
                                            ][i],
                                            size: 56,
                                            color: const Color(0xffc2cdca)))),
                                const SizedBox(height: 22),
                                Text(
                                    [
                                      'Your first building, room and bed',
                                      'Where your business records live',
                                      'A guide to your membership'
                                    ][i],
                                    style: _serif(25)),
                                const SizedBox(height: 12),
                                _tag('BEDSPACE GUIDE / ${[
                                  'GETTING STARTED',
                                  'DATA OWNERSHIP',
                                  'PLANS & PAYMENTS'
                                ][i]}')
                              ]))))
          ]));
  void _guide(int index) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
              backgroundColor: _panel,
              title: Text(
                  [
                    'Getting started',
                    'Your data, your Google',
                    'Membership and renewal'
                  ][index],
                  style: _serif(30)),
              content: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: SingleChildScrollView(
                      child: Text(_guideText[index],
                          style: const TextStyle(
                              color: Color(0xffc3c9c8), height: 1.9)))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'))
              ]));

  Widget _footer() => DecoratedBox(
      decoration:
          const BoxDecoration(border: Border(top: BorderSide(color: _border))),
      child: _width(
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 46),
              child: Column(children: [
                Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runSpacing: 32,
                    spacing: 70,
                    children: [
                      SizedBox(
                          width: 320,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Image.asset('assets/logo.png',
                                    height: 50,
                                    width: 50,
                                    semanticLabel: 'Bedspace logo'),
                                const SizedBox(height: 18),
                                const Text(
                                    'A calmer workspace for shared accommodation.',
                                    style:
                                        TextStyle(color: _muted, height: 1.9))
                              ])),
                      _footerLinks('Product', [
                        ('Features', () => _jump(_features)),
                        ('Pricing', () => _jump(_pricing)),
                        ('Guides', () => _jump(_guides))
                      ]),
                      _footerLinks('Your account', [
                        ('Sign in', () => _open(register: false)),
                        ('Start free trial', () => _open()),
                        ('Data ownership', () => _guide(1))
                      ])
                    ]),
                const SizedBox(height: 44),
                LayoutBuilder(
                    builder: (context, c) => FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Bedspace',
                            style: _serif(c.maxWidth > 700 ? 220 : 100)
                                .copyWith(height: 1)))),
                const SizedBox(height: 35),
                const Divider(color: _border),
                const SizedBox(height: 22),
                const Text(
                    'The Percentage Company / Shared spaces, thoughtfully managed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 11, height: 1.7))
              ]))));
  Widget _footerLinks(String title, List<(String, VoidCallback)> links) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: _white, fontSize: 13)),
        const SizedBox(height: 16),
        for (final link in links)
          TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: _muted,
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft),
              onPressed: link.$2,
              child: Text(link.$1))
      ]);
  Widget _button(String text, VoidCallback onPressed) => LandingHover(
      borderRadius: BorderRadius.circular(32),
      child: FilledButton(onPressed: onPressed, child: Text(text)));
  Widget _heading(String title, String body) => Column(children: [
        Text(title,
            textAlign: TextAlign.center,
            style: _serif(MediaQuery.sizeOf(context).width > 750 ? 43 : 33)),
        const SizedBox(height: 16),
        SizedBox(
            width: 650,
            child: Text(body,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: _muted, fontSize: 15, height: 1.85)))
      ]);
  Widget _section({Key? key, required Widget child, bool border = true}) =>
      DecoratedBox(
          key: key,
          decoration: BoxDecoration(
              border: border
                  ? const Border(bottom: BorderSide(color: _border))
                  : null),
          child: _width(
              child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 80),
                  child: child)));
}

const _featureData = [
  (
    'CONNECTED SPACES',
    'Every room, in perspective',
    'See your buildings, rooms and beds as one connected workspace. Bring vacancy and tenant details together, ready for the next person who walks through the door.'
  ),
  (
    'PAYMENT CLARITY',
    'Rent records that make sense',
    'Track recorded payments, balances and expenses without losing the context. Create rent invoices and receipts when you need them, then keep a copy in Drive.'
  ),
  (
    'CUSTOMER-OWNED STORAGE',
    'A workspace with your name on it',
    'Connect your Google account for your accommodation spreadsheet and private document folder. Manage your account and membership in Bedspace.'
  ),
];
const _guideText = [
  'Create your Bedspace account and confirm your email. Your one-calendar-month trial begins at account creation. Connect the Google account that will own your accommodation spreadsheet and document folder. Then add your buildings, rooms, beds and tenants.\n\nYour workspace is an installable PWA: use Install app in Chrome or Add to Home Screen in Safari.',
  'Bedspace manages your customer profile and membership. Accommodation records live in your connected Google Sheet. Invoice and receipt copies can be saved to your private Google Drive folder.\n\nNew files are not automatically shared with the developer. Pausing your subscription does not delete your Google files. Temporary workspace copies are cached on your device.',
  'Start with one calendar month free. Then renew at AED 50/month plus other charges, or AED 540/year plus other charges. The annual base price saves 10% compared with twelve monthly payments.\n\nOther charges are shown before payment. Your workspace pauses after trial or paid access expires. A verified Paymob payment reopens it. Renewals are customer-initiated; automatic card debits are not enabled.',
];
TextStyle _serif(double size) => TextStyle(
    fontFamily: 'HedvigLetters',
    fontWeight: FontWeight.w400,
    fontSize: size,
    color: _white,
    height: 1.15,
    letterSpacing: -.9);
Widget _tag(String text) => Text(text.toUpperCase(),
    style: const TextStyle(
        fontFamily: 'GeistMono',
        color: _muted,
        fontSize: 10,
        height: 1.8,
        letterSpacing: .6));
Widget _width({required Widget child}) => Center(
    child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: SizedBox(width: double.infinity, child: child))));
