import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bed_space/data/services/billing_admin_service.dart';
import 'package:bed_space/presentation/screens/billing_admin_screen.dart';

void main() {
  test(
      'Manual payment amounts preserve fils exactly and reject malformed amounts',
      () {
    expect(BillingAdminService.parseAmount('50'), 5000);
    expect(BillingAdminService.parseAmount('50.25'), 5025);
    expect(BillingAdminService.parseAmount('540.5'), 54050);
    for (final value in ['-50', 'NaN', '1e3', '50.123', '']) {
      expect(
          () => BillingAdminService.parseAmount(value), throwsFormatException);
    }
  });
  testWidgets('Unauthenticated visitor cannot view customer administration',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BillingAdminScreen()));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Administration is unavailable. Use an authorized account and check the billing setup.'),
        findsOneWidget);
    expect(find.text('Record payment'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Admin records a verified payment and applies an access block',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _AdminFixture();
    await tester
        .pumpWidget(MaterialApp(home: BillingAdminScreen(service: service)));
    await tester.pumpAndSettle();
    expect(find.text('customer@example.com'), findsOneWidget);
    await Scrollable.ensureVisible(tester.element(find.text('Record payment')),
        alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record payment'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Unique bank/receipt reference'),
        'BANK-123');
    await tester.tap(find.text('Record payment & activate'));
    await tester.pumpAndSettle();
    expect(service.reference, 'BANK-123');
    expect(service.amount, 5000);
    expect(find.text('paid'), findsWidgets);
    await Scrollable.ensureVisible(tester.element(find.text('Block')),
        alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Reason'), 'Account review');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(service.blocked, true);
    expect(find.text('Remove block'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

class _AdminFixture extends BillingAdminService {
  String? reference;
  int? amount;
  bool blocked = false;
  @override
  Future<bool> isAdmin() async => true;
  @override
  Future<List<Map<String, dynamic>>> accounts(String search) async => [
        {
          'user_id': 'customer-id',
          'email': 'customer@example.com',
          'display_name': 'Customer',
          'business_name': 'Test business',
          'membership_status': blocked
              ? 'blocked'
              : reference == null
                  ? 'unpaid'
                  : 'paid',
          'billing_cycle': 'monthly',
          'trial_ends_at': '2026-11-01T00:00:00Z',
          'paid_until': reference == null ? null : '2026-12-10T00:00:00Z',
          'admin_blocked': blocked,
          'suspended': false,
        }
      ];
  @override
  Future<void> recordPayment(
      {required String userId,
      required String cycle,
      required int amountCents,
      required String reference,
      required String notes}) async {
    this.reference = reference;
    amount = amountCents;
  }

  @override
  Future<void> setBlocked(String userId, bool blocked, String reason) async {
    this.blocked = blocked;
  }
}
