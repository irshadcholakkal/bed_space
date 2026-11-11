import 'package:flutter_test/flutter_test.dart';
import 'package:bed_space/data/services/auth_callback_error.dart';

void main() {
  test('Successful callback is left to the SDK', () {
    expect(authCallbackError(Uri.parse('https://example.com/?code=private')),
        isNull);
  });
  test('Server callback error is recognized without reflecting raw description',
      () {
    final message = authCallbackError(Uri.parse(
        'https://example.com/?error=server_error&error_code=unexpected_failure&error_description=private-database-details'));
    expect(message, contains('unexpected_failure'));
    expect(message, isNot(contains('private-database-details')));
  });
  test('Implicit flow error fragment is recognized', () {
    expect(
        authCallbackError(
            Uri.parse('https://example.com/#error=access_denied')),
        contains('not completed'));
  });
  test('Unrelated route fragments are ignored', () {
    expect(authCallbackError(Uri.parse('https://example.com/#/rooms')), isNull);
  });
  test('Code exchange failure is actionable without exposing the code', () {
    final message = authCallbackError(Uri.parse(
        'https://example.com/?error=server_error&error_description=Unable+to+exchange+external+code%3A+private-code'));
    expect(message, contains('google_code_exchange'));
    expect(message, isNot(contains('private-code')));
  });
}
