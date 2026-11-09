import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:bed_space/presentation/screens/landing_screen.dart';
import 'package:bed_space/presentation/screens/saas_auth_screen.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('TestFont')
      ..addFont(Future.value(ByteData.sublistView(
          await File('assets/fonts/NotoSans-Regular.ttf').readAsBytes())));
    await loader.load();
    for (final font in [
      ('Inter', 'Inter.ttf'),
      ('HedvigLetters', 'HedvigLettersSerif.ttf')
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
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(fontFamily: 'TestFont'),
          home: const LandingScreen()));
      await tester.pumpAndSettle();
      expect(find.text('A calmer way to manage\nyour shared spaces.'),
          findsOneWidget);
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
    await tester.pumpWidget(const MaterialApp(home: LandingScreen()));
    await tester.pumpAndSettle();
    expect(find.text('AED 50'), findsOneWidget);
    await tester.ensureVisible(find.text('Annual · save 10%'));
    await tester.tap(find.text('Annual · save 10%'));
    await tester.pumpAndSettle();
    expect(find.text('AED 540'), findsOneWidget);
    expect(find.text('AED 45/month equivalent. Save AED 60/year.'),
        findsOneWidget);
    await tester.ensureVisible(find.text('Get started'));
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<SaasAuthScreen>(find.byType(SaasAuthScreen)).billingCycle,
        'annual');
    expect(tester.takeException(), isNull);
  });
}
