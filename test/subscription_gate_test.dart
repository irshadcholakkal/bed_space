import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bed_space/data/services/subscription_service.dart';
import 'package:bed_space/presentation/screens/subscription_gate.dart';

AccountAccess access(bool allowed, {int remainingSeconds = 20}) =>
    AccountAccess.fromJson({
      'allowed': allowed,
      'suspended': false,
      'server_now': '2026-11-10T12:00:00Z',
      'access_until':
          DateTime.utc(2026, 11, 10, 12, 0, remainingSeconds).toIso8601String(),
      'trial_ends_at': '2026-11-10T12:00:20Z',
      'paid_until': null,
    });

void main() {
  testWidgets('Trial expiry hides workspace; confirmed renewal reopens it',
      (tester) async {
    var status = access(true);
    await tester.pumpWidget(MaterialApp(
        home: SubscriptionGate(
            loadAccess: () async => status,
            child: const Scaffold(body: Text('Protected workspace')))));
    await tester.pumpAndSettle();
    expect(find.text('Protected workspace'), findsOneWidget);
    status = access(false, remainingSeconds: -1);
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();
    expect(find.text('Protected workspace'), findsNothing);
    expect(find.text('Your workspace is paused.'), findsOneWidget);
    status = access(true, remainingSeconds: 100);
    await tester.ensureVisible(find.text('Already paid? Check payment status'));
    await tester.tap(find.text('Already paid? Check payment status'));
    await tester.pumpAndSettle();
    expect(find.text('Protected workspace'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Unavailable server membership fails closed with retry',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: SubscriptionGate(
            loadAccess: () async => throw StateError('Unavailable'),
            child: const Text('Protected workspace'))));
    await tester.pumpAndSettle();
    expect(find.text('Protected workspace'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'Missing migration shows a setup reference without opening workspace',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: SubscriptionGate(
            loadAccess: () async => throw MembershipCheckFailure.setup,
            child: const Text('Protected workspace'))));
    await tester.pumpAndSettle();
    expect(find.text('Reference: MEMBERSHIP_SETUP'), findsOneWidget);
    expect(
        find.text(
            'Membership verification is not configured yet. Please contact support.'),
        findsOneWidget);
    expect(find.text('Protected workspace'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
