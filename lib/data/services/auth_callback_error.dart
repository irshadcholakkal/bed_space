/// Reads only OAuth error fields; never displays callback tokens or raw URLs.
String? authCallbackError(Uri uri) {
  final parameters = <String, String>{...uri.queryParameters};
  if (uri.fragment.contains('=')) {
    try {
      parameters.addAll(Uri.splitQueryString(uri.fragment));
    } on FormatException {
      // An unrelated Flutter route fragment is not an OAuth response.
    }
  }
  if (!parameters.containsKey('error')) return null;
  if ((parameters['error_description'] ?? '')
      .startsWith('Unable to exchange external code')) {
    return 'Google sign-in could not be completed because the account service '
        'could not exchange the Google authorization code. Please start a fresh '
        'sign-in. If it continues, contact support. Reference: google_code_exchange.';
  }
  final code = parameters['error_code'];
  if (code == 'unexpected_failure' || parameters['error'] == 'server_error') {
    return 'Google sign-in could not be completed by the account service. '
        'Please try again or contact support. Reference: unexpected_failure.';
  }
  if (parameters['error'] == 'access_denied') {
    return 'Google sign-in was not completed. Please try again and allow the requested access.';
  }
  return 'Sign-in could not be completed. Please try again.';
}
