import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bed_space/presentation/routing/app_routes.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSessionRoute.restore(null);
  });
  test('Refresh restores last screen and allowed room filters for the account',
      () async {
    await AppSessionRoute.save(
        'owner', '/rooms?building=b1&room=r1&period=all&code=private#secret');
    await AppSessionRoute.restore(null);
    await AppSessionRoute.restore('owner');
    expect(AppSessionRoute.lastRoute, '/rooms?building=b1&room=r1&period=all');
    expect(
        (await SharedPreferences.getInstance())
            .getString('bedspace_session_user'),
        'owner');
  });
  test('Account switch does not restore another customer screen', () async {
    await AppSessionRoute.save('owner', '/financials');
    await AppSessionRoute.restore('other');
    expect(AppSessionRoute.lastRoute, isNull);
    await AppSessionRoute.restore(null);
    expect(
        (await SharedPreferences.getInstance())
            .getString('bedspace_session_user'),
        isNull);
  });
  test('Login and external URLs are never stored as workspace destinations',
      () async {
    await AppSessionRoute.save('owner', '/dashboard');
    await AppSessionRoute.save('owner', '/login');
    await AppSessionRoute.save('owner', 'https://external.example/rooms');
    expect(AppSessionRoute.lastRoute, '/dashboard');
  });
}
