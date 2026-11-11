import 'package:flutter_test/flutter_test.dart';
import 'package:bed_space/data/services/saas_service.dart';

void main() {
  test('App callbacks stay inside the Flutter app and strip old callback data',
      () {
    expect(
        SaasService.callbackFor(Uri.parse(
                'https://example.com/app/rooms?code=private#access_token=private'))
            .toString(),
        'https://example.com/app/');
    expect(
        SaasService.callbackFor(
                Uri.parse('https://example.com/app?view=signup'))
            .path,
        '/app/');
  });
  test('Legacy Flutter root deployments keep their root callback', () {
    expect(
        SaasService.callbackFor(Uri.parse('http://localhost:3000/?view=login'))
            .toString(),
        'http://localhost:3000/');
  });
}
