import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:bed_space/presentation/screens/landing_screen.dart';
import 'package:bed_space/presentation/screens/saas_auth_screen.dart';
import 'package:bed_space/presentation/widgets/landing_motion.dart';

Widget app() => MaterialApp(
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!),
    home: const LandingScreen());
Future<void> show(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('TestFont')
      ..addFont(Future.value(ByteData.sublistView(
          await File('assets/fonts/NotoSans-Regular.ttf').readAsBytes())));
    await loader.load();
    for (final font in [
      ('Inter', 'Inter.ttf'),
      ('HedvigLetters', 'HedvigLettersSerif.ttf'),
      ('GeistMono', 'GeistMono.ttf')
    ]) {
      final family = FontLoader(font.$1)
        ..addFont(Future.value(ByteData.sublistView(
            await File('assets/fonts/${font.$2}').readAsBytes())));
      await family.load();
    }
  });
  for (final size in [
    const Size(1440, 1000),
    const Size(390, 844),
    const Size(320, 700)
  ]) {
    testWidgets('Landing and registration fit ${size.width}px', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<LandingWordEntrance>(find.byType(LandingWordEntrance))
              .text,
          'Shared space management for modern teams');
      expect(find.byKey(const Key('landing-logo')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Try free'));
      await tester.pumpAndSettle();
      expect(find.text('Business name'), findsOneWidget);
      expect(
          find.text(
              'Registration is not available yet. The account service needs to be configured.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'Annual pricing shows discount and carries selection into registration',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('AED 50'), findsWidgets);
    await show(tester, find.text('Annual \u00b7 save 10%'));
    await tester.tap(find.text('Annual \u00b7 save 10%'));
    await tester.pumpAndSettle();
    expect(find.text('AED 540'), findsWidgets);
    expect(find.text('AED 45/month equivalent. Save AED 60/year.'),
        findsOneWidget);
    await show(tester, find.text('Choose annual'));
    await tester.tap(find.text('Choose annual'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<SaasAuthScreen>(find.byType(SaasAuthScreen)).billingCycle,
        'annual');
    expect(tester.takeException(), isNull);
  });
  testWidgets('Workflow carousel, role tabs and guide cards respond to input',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final next = find.byTooltip('Next workflow');
    await show(tester, next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('A receipt, ready when you are.'), findsOneWidget);
    final documents = find.byKey(const ValueKey('role-3'));
    await show(tester, documents);
    await tester.tap(documents);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('role-visual-3')), findsOneWidget);
    final guide = find.text('A guide to your membership');
    await show(tester, guide);
    await tester.tap(guide);
    await tester.pumpAndSettle();
    expect(find.text('Membership and renewal'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Membership and renewal'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
