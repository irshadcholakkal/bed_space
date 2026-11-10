import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bed_space/data/services/subscription_service.dart';

void main() {
  test('Missing migration and permissions report setup instead of connectivity',
      () {
    for (final code in ['PGRST202', 'PGRST205', '42P01', '42883', '42501']) {
      expect(
          MembershipCheckFailure.fromError(PostgrestException(
              message: 'private backend details', code: code)),
          same(MembershipCheckFailure.setup));
    }
  });
  test('Expired session reports sign-in recovery; timeout reports connectivity',
      () {
    expect(
        MembershipCheckFailure.fromError(
            const PostgrestException(message: 'expired', code: 'PGRST301')),
        same(MembershipCheckFailure.session));
    expect(MembershipCheckFailure.fromError(TimeoutException('timeout')),
        same(MembershipCheckFailure.connection));
    expect(MembershipCheckFailure.fromError(MembershipCheckFailure.missing),
        same(MembershipCheckFailure.missing));
  });
}
