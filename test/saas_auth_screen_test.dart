import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bed_space/presentation/screens/saas_auth_screen.dart';

void main() {
  for (final size in [
    const Size(360, 800),
    const Size(768, 1024),
    const Size(1440, 900)
  ]) {
    testWidgets('Auth layout fits ${size.width} and switches account mode',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester
          .pumpWidget(const MaterialApp(home: SaasAuthScreen(register: true)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to Bedspace'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Create an account'));
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      expect(find.text('Create your account'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
