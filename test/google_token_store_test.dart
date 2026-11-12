import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bed_space/data/services/google_token_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Google connection survives storage reload and stays account scoped',
      () async {
    await GoogleTokenStore.save('account-one', 'token-one');
    await GoogleTokenStore.saveRefreshToken('account-one', 'refresh-one');
    await GoogleTokenStore.save('account-two', 'token-two');
    final persisted = await SharedPreferences.getInstance();
    final snapshot = {
      for (final key in persisted.getKeys()) key: persisted.get(key)!
    };
    SharedPreferences.setMockInitialValues(snapshot);
    expect(await GoogleTokenStore.read('account-one'), 'token-one');
    expect(
        await GoogleTokenStore.readRefreshToken('account-one'), 'refresh-one');
    expect(await GoogleTokenStore.read('account-two'), 'token-two');
    expect(await GoogleTokenStore.read('another-account'), isNull);
  });
  test('Logout clears only the signed-out account connection', () async {
    await GoogleTokenStore.save('account-one', 'token-one');
    await GoogleTokenStore.saveRefreshToken('account-one', 'refresh-one');
    await GoogleTokenStore.save('account-two', 'token-two');
    await GoogleTokenStore.clear('account-one');
    expect(await GoogleTokenStore.read('account-one'), isNull);
    expect(await GoogleTokenStore.readRefreshToken('account-one'), isNull);
    expect(await GoogleTokenStore.read('account-two'), 'token-two');
  });
}
