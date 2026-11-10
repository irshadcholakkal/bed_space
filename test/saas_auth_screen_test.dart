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
      expect(find.text('Sign up with email'), findsOneWidget);
      expect(
          find.widgetWithText(TextFormField, 'Email address'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Bedspace password'),
          findsOneWidget);
      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to Bedspace'), findsOneWidget);
      expect(find.text('Sign in with email'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Create an account'));
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      expect(find.text('Create your account'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Email signup validates input and hides its password',
      (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: SaasAuthScreen(register: true)));
    await tester.pumpAndSettle();
    final form = tester.state<FormState>(find.byType(Form));
    expect(form.validate(), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Enter your Bedspace password'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'owner@gmail.com');
    await tester.enterText(find.byType(TextFormField).last, 'short');
    expect(form.validate(), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Use at least 8 characters'), findsOneWidget);
    await tester.enterText(
        find.byType(TextFormField).last, 'bedspace-password');
    expect(form.validate(), isTrue);
    await tester.pumpAndSettle();
    expect(
        tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
        isTrue);
    await tester.ensureVisible(find.byTooltip('Show password'));
    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
        isFalse);
    expect(tester.takeException(), isNull);
  });
}
