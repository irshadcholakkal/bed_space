import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class GoogleDriveService {
  final http.Client client;
  GoogleDriveService(this.client);

  /// Upload a private PDF into the connected customer's folder.
  /// No permissions are created; the folder's existing sharing applies.
  Future<String> uploadPdf(
      {required String token,
      required String folderId,
      required String filename,
      required Uint8List bytes}) async {
    final boundary = 'bedspace_${DateTime.now().microsecondsSinceEpoch}';
    final metadata = jsonEncode({
      'name': filename,
      'parents': [folderId],
      'mimeType': 'application/pdf'
    });
    final body = BytesBuilder()
      ..add(utf8.encode(
          '--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$metadata\r\n--$boundary\r\nContent-Type: application/pdf\r\n\r\n'))
      ..add(bytes)
      ..add(utf8.encode('\r\n--$boundary--\r\n'));
    final response = await client
        .post(
            Uri.https('www.googleapis.com', '/upload/drive/v3/files',
                {'uploadType': 'multipart', 'fields': 'id'}),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'multipart/related; boundary=$boundary'
            },
            body: body.takeBytes())
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw StateError(response.statusCode == 401
          ? 'Google session expired. Reconnect Google and try again.'
          : 'Drive could not save the document. Check folder access and try again.');
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['id'] as String;
  }
}
