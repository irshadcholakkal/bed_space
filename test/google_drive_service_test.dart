import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bed_space/data/services/google_drive_service.dart';

void main() {
  test('PDF goes to selected customer folder without granting permissions',
      () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/upload/drive/v3/files');
      expect(request.url.queryParameters['uploadType'], 'multipart');
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(request.headers['Content-Type'],
          startsWith('multipart/related; boundary='));
      expect(request.body, contains('"parents":["customer-folder"]'));
      expect(request.body, contains('%PDF-test'));
      expect(request.body, isNot(contains('permissions')));
      return http.Response('{"id":"saved-file"}', 200);
    });
    final id = await GoogleDriveService(client).uploadPdf(
        token: 'test-token',
        folderId: 'customer-folder',
        filename: 'invoice.pdf',
        bytes: Uint8List.fromList('%PDF-test'.codeUnits));
    expect(id, 'saved-file');
    client.close();
  });
  test('Expired Google authorization is reported as a failed upload', () async {
    final client = MockClient((_) async => http.Response('{}', 401));
    await expectLater(
        GoogleDriveService(client).uploadPdf(
            token: 'expired',
            folderId: 'folder',
            filename: 'invoice.pdf',
            bytes: Uint8List(0)),
        throwsA(isA<StateError>()
            .having((e) => e.message, 'message', contains('expired'))));
    client.close();
  });
}
