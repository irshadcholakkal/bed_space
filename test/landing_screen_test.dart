import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:bed_space/presentation/screens/landing_screen.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('TestFont')
      ..addFont(Future.value(ByteData.sublistView(
          await File('assets/fonts/NotoSans-Regular.ttf').readAsBytes())));
    await loader.load();
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
      expect(find.text('Every bed.\nEvery payment.\nOne clear view.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      expect(find.text('Business name'), findsOneWidget);
      expect(
          find.text(
              'Registration is not available yet. The account service needs to be configured.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
